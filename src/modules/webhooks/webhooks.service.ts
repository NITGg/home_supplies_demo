import { HttpError } from "@/lib/httpError";
import { logger } from "@/config/logger";
import { verifyPaymobCallback } from "@/services/paymob.service";
import { verifyKashierWebhook } from "@/services/kashier.service";
import {
  confirmWalletRechargeService,
  confirmKashierRechargeService,
} from "@/modules/profile/services/wallet.service";
import {
  handlePaymobOrderPayment,
  handleKashierOrderPayment,
  handleEasykashOrderPayment,
} from "./handlers/order-payment.handler";
import type { TransactionCallback } from "@/types/paymob.types";
import type { KashierWebhookPayload } from "@/types/kashier.types";
import type {
  WalletRechargeConfirmCallbackInput,
  KashierWebhookBodyInput,
} from "@/modules/profile/schemas/wallet.schema";
import {
  inquireEasykashPayment,
  verifyEasykashCallback,
} from "@/services/easykash.service";
import type { EasykashCallbackPayload } from "@/types/easykash.types";
import { prisma } from "@/config/prisma";

// ─── Paymob unified handler ───────────────────────────────────────────────────

export async function handlePaymobWebhook(
  body: WalletRechargeConfirmCallbackInput,
  hmac: string,
) {
  const isValid = verifyPaymobCallback(body as TransactionCallback, hmac);
  if (!isValid) throw new HttpError(401, "webhooks:errors.invalid_hmac");

  // Look up the special_reference to determine context.
  // Paymob stores the reference as paymob_order_id in our Transaction table.
  // We identify the context by the transaction type after lookup.
  // But we don't have it here without a DB call — instead, route by special_reference
  // embedded in the body when available, else fall back to DB lookup by paymob_order_id.

  const paymobOrderId = String(body.obj.order?.id ?? "");
  if (!paymobOrderId)
    throw new HttpError(400, "webhooks:errors.missing_order_id");

  // Look up transaction type to dispatch
  const tx = await prisma.transaction.findFirst({
    where: { paymob_order_id: paymobOrderId },
    select: { type: true },
  });

  if (!tx) throw new HttpError(404, "webhooks:errors.transaction_not_found");

  logger.info({ paymobOrderId, type: tx.type }, "[Webhook/Paymob] dispatching");

  if (tx.type === "TOPUP") {
    return confirmWalletRechargeService({ body, hmac });
  }

  if (tx.type === "ORDER_PAYMENT") {
    return handlePaymobOrderPayment(body as TransactionCallback);
  }

  throw new HttpError(400, "webhooks:errors.unknown_transaction_type");
}

// ─── Kashier unified handler ──────────────────────────────────────────────────

export async function handleKashierWebhook(
  body: KashierWebhookBodyInput,
  signature: string,
) {
  const isValid = verifyKashierWebhook(
    body as unknown as KashierWebhookPayload,
    signature,
  );
  if (!isValid) throw new HttpError(401, "webhooks:errors.invalid_hmac");

  const merchantOrderId = body.data.merchantOrderId;

  logger.info({ merchantOrderId }, "[Webhook/Kashier] dispatching");
  logger.info({ body }, "[Webhook/Kashier] data");

  const walletMatch = merchantOrderId.match(/^WALLET-TX-(\d+)$/);
  if (walletMatch) {
    return confirmKashierRechargeService({ body, signature });
  }

  const orderMatch = merchantOrderId.match(/^ORDER-TX-(\d+)$/);
  if (orderMatch) {
    const transactionId = Number(orderMatch[1]);
    return handleKashierOrderPayment(
      body as unknown as KashierWebhookPayload,
      transactionId,
    );
  }

  throw new HttpError(400, "webhooks:errors.unknown_reference_format");
}

// ─── EasyKash unified handler ─────────────────────────────────────────────────
// EasyKash callback URL is configured statically in the merchant dashboard.
// All callbacks (wallet + order) arrive here; dispatch by transaction type.

export async function handleEasykashWebhook(payload: EasykashCallbackPayload) {
  const transactionId = Number(payload.customerReference);

  if (!transactionId || Number.isNaN(transactionId)) {
    throw new HttpError(400, "webhooks:errors.invalid_customer_reference");
  }
  logger.info(
    { test: verifyEasykashCallback(payload as any) },
    "[Webhook/EasyKash] received callback, verifying...",
  );
  // Verify by fetching authoritative status from EasyKash instead of trusting callback params
  const inquiry = await inquireEasykashPayment(payload.customerReference);
  logger.info(inquiry, "[Webhook/EasyKash] dispatching");

  // Use inquiry status as the source of truth
  // In handleEasykashWebhook, after inquiry:
  const verifiedPayload = {
    ...payload,
    status: inquiry.status,
    Amount: inquiry.Amount, // ← use inquiry amount, not callback (which has none)
    easykashRef: inquiry.easykashRef ?? payload.easykashRef,
  };

  // Look up transaction type to dispatch
  const tx = await prisma.transaction.findUnique({
    where: { id: transactionId },
    select: { type: true },
  });

  if (!tx) throw new HttpError(404, "webhooks:errors.transaction_not_found");

  if (tx.type === "ORDER_PAYMENT") {
    return handleEasykashOrderPayment(verifiedPayload);
  }

  // EasyKash is only used for order payments at this time
  throw new HttpError(400, "webhooks:errors.unknown_transaction_type");
}
