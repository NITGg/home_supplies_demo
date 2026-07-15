import crypto from "node:crypto";
import env from "@/config/env";
import { logger } from "@/config/logger";
import type {
  CreateIntentionRequest,
  IntentionResponse,
  CreateQuickLinkRequest,
  QuickLinkResponse,
  TransactionCallback,
  CreateQuickLinkOptions,
} from "../types/paymob.types";
import { HttpError } from "@/lib/httpError";

const CONFIG = {
  API_KEY: env.PAYMOB_API_KEY,
  SECRET_KEY: env.PAYMOB_SECRET_KEY,
  PUBLIC_KEY: env.PAYMOB_PUBLIC_KEY,
  PAYMENT_METHOD_ID: env.PAYMOB_PAYMENT_METHODS,
  HMAC_SECRET: env.PAYMOB_HMAC_SECRET,
  BASE_URL: env.PAYMOB_BASE_URL || "https://accept.paymob.com",
};

let cachedAuthToken: string | null = null;

export const toCents = (amount: number) => Math.round(amount * 100);
export const fromCents = (cents: number) => cents / 100;

async function parseJsonSafe<T>(
  res: Response,
): Promise<T | Record<string, never>> {
  try {
    return (await res.json()) as T;
  } catch {
    return {};
  }
}

export async function getPaymobAuthToken(): Promise<string> {
  if (cachedAuthToken) return cachedAuthToken;

  const res = await fetch(`${CONFIG.BASE_URL}/api/auth/tokens`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ api_key: CONFIG.API_KEY }),
  });

  if (!res.ok) {
    logger.error({ status: res.status }, "[Paymob] Auth token fetch failed");
    throw new Error("Failed to authenticate with Paymob");
  }

  const data = (await res.json()) as { token: string };
  cachedAuthToken = data.token;
  return data.token;
}

export function clearPaymobAuthTokenCache() {
  cachedAuthToken = null;
}

export async function createPaymobIntention(
  request: CreateIntentionRequest,
): Promise<IntentionResponse> {
  const res = await fetch(`${CONFIG.BASE_URL}/v1/intention/`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Token ${CONFIG.SECRET_KEY}`,
    },
    body: JSON.stringify(request),
  });

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { status: res.status, error },
      "[Paymob] Create intention failed",
    );
    throw new HttpError(res.status, `Paymob Error: ${JSON.stringify(error)}`);
  }

  const data = (await res.json()) as IntentionResponse;
  logger.info(
    { intentionOrderId: data.intention_order_id },
    "[Paymob] Payment intention created",
  );
  return data;
}

export function getPaymobCheckoutUrl(clientSecret: string): string {
  return `${CONFIG.BASE_URL}/unifiedcheckout/?publicKey=${CONFIG.PUBLIC_KEY}&clientSecret=${clientSecret}`;
}

export function verifyPaymobCallback(
  body: TransactionCallback,
  hmac: string,
): boolean {
  const obj = body.obj;
  const data = [
    obj.amount_cents,
    obj.created_at,
    obj.currency,
    obj.error_occured,
    obj.has_parent_transaction,
    obj.id,
    obj.integration_id,
    obj.is_3d_secure,
    obj.is_auth,
    obj.is_capture,
    obj.is_refunded,
    obj.is_standalone_payment,
    obj.is_voided,
    obj.order?.id,
    obj.owner,
    obj.pending,
    obj.source_data?.pan,
    obj.source_data?.sub_type,
    obj.source_data?.type,
    obj.success,
  ].join("");

  const calculated = crypto
    .createHmac("sha512", CONFIG.HMAC_SECRET)
    .update(data)
    .digest("hex");

  return calculated === hmac;
}

export async function refundPaymobTransaction(
  transactionId: number,
  amountCents: number,
) {
  const token = await getPaymobAuthToken();

  const res = await fetch(
    `${CONFIG.BASE_URL}/api/acceptance/void_refund/refund`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        auth_token: token,
        transaction_id: transactionId,
        amount_cents: amountCents,
      }),
    },
  );

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { transactionId, amountCents, status: res.status, error },
      "[Paymob] Refund failed",
    );
    throw new Error("Refund failed");
  }

  logger.info({ transactionId, amountCents }, "[Paymob] Refund successful");
  return res.json();
}

export async function voidPaymobTransaction(transactionId: number) {
  const token = await getPaymobAuthToken();

  const res = await fetch(
    `${CONFIG.BASE_URL}/api/acceptance/void_refund/void`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        auth_token: token,
        transaction_id: transactionId,
      }),
    },
  );

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { transactionId, status: res.status, error },
      "[Paymob] Void failed",
    );
    throw new Error("Void failed");
  }

  logger.info({ transactionId }, "[Paymob] Transaction voided");
  return res.json();
}

export async function getPaymobTransaction(transactionId: number) {
  const token = await getPaymobAuthToken();

  const res = await fetch(
    `${CONFIG.BASE_URL}/api/acceptance/transactions/${transactionId}`,
    {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
    },
  );

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { transactionId, status: res.status, error },
      "[Paymob] Get transaction failed",
    );
    throw new Error("Failed to get transaction");
  }

  return res.json();
}

export async function createPaymobQuickLink(
  options: CreateQuickLinkOptions,
): Promise<QuickLinkResponse> {
  const token = await getPaymobAuthToken();

  const request: CreateQuickLinkRequest = {
    amount_cents: options.amount,
    reference_id: options.referenceId,
    integration_id: [CONFIG.PAYMENT_METHOD_ID],
    client_email: options.customerEmail,
    client_name: options.customerName,
    client_mobile: options.customerPhone,
    ...(options.description && { description: options.description }),
    ...(options.expiresAt && { expires_at: options.expiresAt }),
    is_live: options.isLive ?? false,
  };

  const res = await fetch(`${CONFIG.BASE_URL}/api/ecommerce/payment-links`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(request),
  });

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { referenceId: options.referenceId, status: res.status, error },
      "[Paymob] Failed to create QuickLink",
    );
    throw new Error("Failed to create QuickLink");
  }

  const data = (await res.json()) as QuickLinkResponse;
  logger.info(
    { referenceId: options.referenceId },
    "[Paymob] QuickLink created",
  );
  return data;
}
