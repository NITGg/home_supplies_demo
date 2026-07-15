import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { logger } from "@/config/logger";
import {
  refundPaymobTransaction,
  voidPaymobTransaction,
} from "@/services/paymob.service";
import {
  refundKashierTransaction,
  voidKashierTransaction,
} from "@/services/kashier.service";

// ─── Shared card-refund helper ────────────────────────────────────────────────
// Called from both:
//   - refunds.service.ts  (admin approves a customer refund)
//   - orders.admin.service.ts  (expired / cancelled order auto-refund)
//
// amountCents: integer piastres to refund.
// reason:      optional human-readable reason stored on the provider side.
//
// Returns provider name + their refund transaction ID for audit.
// Throws HttpError on failure so callers can catch and mark FAILED.
// ─────────────────────────────────────────────────────────────────────────────

export interface CardRefundResult {
  provider: string;
  refundId: string;
  raw: unknown;
}

export async function executeCardRefund(
  orderId: number,
  amountCents: number,
  reason?: string,
): Promise<CardRefundResult> {
  const paymentTx = await prisma.transaction.findFirst({
    where: { order_id: orderId, type: "ORDER_PAYMENT", status: "COMPLETED" },
    include: { paymentMethod: { select: { provider: true } } },
    orderBy: { created_at: "desc" },
  });

  if (!paymentTx) {
    throw new HttpError(
      404,
      "refunds:errors.card_payment_transaction_not_found",
    );
  }

  const provider = paymentTx.paymentMethod?.provider;

  // ── Paymob ──────────────────────────────────────────────────────────────────
  if (provider === "PAYMOB") {
    if (!paymentTx.paymob_transaction_id) {
      throw new HttpError(422, "refunds:errors.paymob_transaction_id_missing");
    }
    const result = await refundPaymobTransaction(
      Number(paymentTx.paymob_transaction_id),
      amountCents,
    );
    return {
      provider: "PAYMOB",
      refundId: String(result.id ?? result.transaction_id ?? ""),
      raw: result,
    };
  }

  // ── Kashier ─────────────────────────────────────────────────────────────────
  if (provider === "KASHIER") {
    if (!paymentTx.kashier_order_id) {
      throw new HttpError(422, "refunds:errors.kashier_order_id_missing");
    }
    const result = await refundKashierTransaction(
      paymentTx.kashier_order_id,
      amountCents / 100,
      reason,
    );
    return {
      provider: "KASHIER",
      refundId: result.response.transactionId,
      raw: result,
    };
  }

  // ── EasyKash — no refund API ─────────────────────────────────────────────────
  if (provider === "EASYKASH") {
    logger.warn(
      { orderId, amountCents },
      "[CardRefund] EasyKash has no refund API — manual processing required",
    );
    throw new HttpError(422, "refunds:errors.easykash_no_refund_api");
  }

  throw new HttpError(422, "refunds:errors.unsupported_card_provider");
}

// ─── Find the completed card payment for an order ────────────────────────────
// Used to decide whether a cancellation falls within the gateway's void window
// (Paymob/Kashier void only reverses the transaction before settlement).
export async function getCardPaymentTransaction(orderId: number) {
  return prisma.transaction.findFirst({
    where: { order_id: orderId, type: "ORDER_PAYMENT", status: "COMPLETED" },
    include: { paymentMethod: { select: { provider: true } } },
    orderBy: { created_at: "desc" },
  });
}

// ─── Shared card-void helper ──────────────────────────────────────────────────
// Reverses a card payment in full via the gateway's VOID API. Unlike
// executeCardRefund, this does not support partial amounts — use it only when
// the full payable amount should be returned (no cancellation fee applies).
//
// Returns provider name + their void transaction ID for audit.
// Throws HttpError on failure so callers can catch and mark FAILED.
// ─────────────────────────────────────────────────────────────────────────────

export interface CardVoidResult {
  provider: string;
  voidId: string;
  raw: unknown;
}

export async function executeCardVoid(
  orderId: number,
  reason?: string,
): Promise<CardVoidResult> {
  const paymentTx = await getCardPaymentTransaction(orderId);

  if (!paymentTx) {
    throw new HttpError(
      404,
      "refunds:errors.card_payment_transaction_not_found",
    );
  }

  const provider = paymentTx.paymentMethod?.provider;

  // ── Paymob ──────────────────────────────────────────────────────────────────
  if (provider === "PAYMOB") {
    if (!paymentTx.paymob_transaction_id) {
      throw new HttpError(422, "refunds:errors.paymob_transaction_id_missing");
    }
    const result = await voidPaymobTransaction(
      Number(paymentTx.paymob_transaction_id),
    );
    return {
      provider: "PAYMOB",
      voidId: String(result.id ?? result.transaction_id ?? ""),
      raw: result,
    };
  }

  // ── Kashier ─────────────────────────────────────────────────────────────────
  if (provider === "KASHIER") {
    if (!paymentTx.kashier_order_id) {
      throw new HttpError(422, "refunds:errors.kashier_order_id_missing");
    }
    const result = await voidKashierTransaction(
      paymentTx.kashier_order_id,
      reason,
    );
    return {
      provider: "KASHIER",
      voidId: result.response.transactionId,
      raw: result,
    };
  }

  // ── EasyKash — no void API ────────────────────────────────────────────────────
  if (provider === "EASYKASH") {
    logger.warn(
      { orderId },
      "[CardVoid] EasyKash has no void API — manual processing required",
    );
    throw new HttpError(422, "refunds:errors.easykash_no_refund_api");
  }

  throw new HttpError(422, "refunds:errors.unsupported_card_provider");
}
