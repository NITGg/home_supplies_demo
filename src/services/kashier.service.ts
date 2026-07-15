import crypto from "node:crypto";
import env from "@/config/env";
import { logger } from "@/config/logger";
import { HttpError } from "@/lib/httpError";
import type {
  KashierCreateSessionRequest,
  KashierCreateSessionResponse,
  KashierWebhookPayload,
} from "@/types/kashier.types";

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

const CONFIG = {
  SECRET_KEY: env.KASHIER_SECRET_KEY,
  API_KEY: env.KASHIER_API_KEY,
  MERCHANT_ID: env.KASHIER_MERCHANT_ID,
  BASE_URL: env.KASHIER_BASE_URL ?? "https://api.kashier.io",
  REFUND_BASE_URL: env.KASHIER_REFUND_BASE_URL ?? "https://fep.kashier.io",
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

async function parseJsonSafe<T>(
  res: Response,
): Promise<T | Record<string, never>> {
  try {
    return (await res.json()) as T;
  } catch {
    return {};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create payment session
// POST /v3/payment/sessions
// Returns a `sessionUrl` the client should be redirected to.
// ─────────────────────────────────────────────────────────────────────────────

export async function createKashierSession(
  request: KashierCreateSessionRequest,
): Promise<KashierCreateSessionResponse> {
  const res = await fetch(`${CONFIG.BASE_URL}/v3/payment/sessions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: CONFIG.SECRET_KEY,
      "api-key": CONFIG.API_KEY,
    },
    body: JSON.stringify(request),
  });

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { status: res.status, error },
      "[Kashier] Create session failed",
    );
    throw new HttpError(res.status, `Kashier Error: ${JSON.stringify(error)}`);
  }

  const data = (await res.json()) as KashierCreateSessionResponse;
  logger.info(
    { sessionId: data._id, order: request.order, data },
    "[Kashier] Session created",
  );
  return data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Get session status
// GET /v3/payment/sessions/:sessionId/payment
// ─────────────────────────────────────────────────────────────────────────────

export async function getKashierSession(sessionId: string) {
  const res = await fetch(
    `${CONFIG.BASE_URL}/v3/payment/sessions/${sessionId}/payment`,
    {
      method: "GET",
      headers: {
        Authorization: CONFIG.SECRET_KEY,
        "api-key": CONFIG.API_KEY,
      },
    },
  );

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { sessionId, status: res.status, error },
      "[Kashier] Get session failed",
    );
    throw new HttpError(res.status, `Kashier Error: ${JSON.stringify(error)}`);
  }

  return res.json();
}

// ─────────────────────────────────────────────────────────────────────────────
// Verify webhook signature
//
// Algorithm:
//   1. Sort `data.signatureKeys` alphabetically.
//   2. Build query string from those keys+values: key1=val1&key2=val2
//   3. HMAC-SHA256 over that string with your Payment API Key.
//   4. Compare hex digest to the `x-kashier-signature` header.
// ─────────────────────────────────────────────────────────────────────────────

export function verifyKashierWebhook(
  payload: KashierWebhookPayload,
  signature: string,
): boolean {
  try {
    const { data } = payload;
    const record = data as unknown as Record<string, unknown>;

    // Replicate Kashier's reference implementation exactly:
    //   data.signatureKeys.sort()
    //   _.pick(data, data.signatureKeys)
    //   queryString.stringify(objectSignaturePayload)   ← URL-encodes values
    //   crypto.createHmac('sha256', PaymentApiKey).update(signaturePayload).digest('hex')
    const sortedKeys = [...data.signatureKeys].sort();

    // queryString.stringify uses encodeURIComponent for values (not + for spaces)
    const message = sortedKeys
      .map((k) => `${k}=${encodeURIComponent(String(record[k] ?? ""))}`)
      .join("&");

    const calculated = crypto
      .createHmac("sha256", CONFIG.API_KEY)
      .update(message)
      .digest("hex");

    logger.debug(
      { message, calculated, expected: signature },
      "[Kashier] Webhook signature check",
    );

    return calculated === signature;
  } catch (err) {
    logger.error({ err }, "[Kashier] Webhook signature verification error");
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Refund
// PUT /orders/:orderId/
// Body: { apiOperation: "REFUND", reason, transaction: { amount } }
// ─────────────────────────────────────────────────────────────────────────────

export interface KashierRefundResponse {
  response: {
    status: string; // "SUCCESS" | "FAILED"
    gatewayCode: string; // "APPROVED" | ...
    transactionId: string;
    amount: number;
    currency: string;
  };
  messages?: unknown;
}

export async function refundKashierTransaction(
  kashierOrderId: string,
  amountEgp: number,
  reason?: string,
): Promise<KashierRefundResponse> {
  const res = await fetch(
    `${CONFIG.REFUND_BASE_URL}/v3/orders/${kashierOrderId}/`,
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: CONFIG.SECRET_KEY,
        "api-key": CONFIG.API_KEY,
      },
      body: JSON.stringify({
        apiOperation: "REFUND",
        reason: reason ?? "Customer refund",
        transaction: { amount: amountEgp },
      }),
    },
  );

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { kashierOrderId, amountEgp, status: res.status, error },
      "[Kashier] Refund failed",
    );
    throw new HttpError(
      res.status,
      `Kashier Refund Error: ${JSON.stringify(error)}`,
    );
  }

  const data = (await res.json()) as KashierRefundResponse;

  if (
    data.response?.status !== "REFUNDED" &&
    data.response?.status !== "PARTIALLY_REFUNDED"
  ) {
    logger.error(
      { kashierOrderId, amountEgp, response: data.response },
      "[Kashier] Refund declined by gateway",
    );
    throw new HttpError(
      422,
      `Kashier refund declined: ${data.response?.gatewayCode}`,
    );
  }

  logger.info(
    { kashierOrderId, amountEgp, refundTxId: data.response.transactionId },
    "[Kashier] Refund successful",
  );
  return data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Void
// PUT /orders/:orderId/
// Body: { apiOperation: "VOID", reason }
// Reverses the full transaction before settlement — no partial amounts.
// ─────────────────────────────────────────────────────────────────────────────

export interface KashierVoidResponse {
  response: {
    result?: string; // "SUCCESS" | "FAILED"
    status: string; // "CANCELLED" | "VOIDED" | "FAILED"
    gatewayCode?: string; // "APPROVED" | ...
    transactionId: string;
    amount: number;
    currency: string;
  };
  messages?: unknown;
}

export async function voidKashierTransaction(
  kashierOrderId: string,
  reason?: string,
): Promise<KashierVoidResponse> {
  const res = await fetch(
    `${CONFIG.REFUND_BASE_URL}/v3/orders/${kashierOrderId}/`,
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: CONFIG.SECRET_KEY,
        "api-key": CONFIG.API_KEY,
      },
      body: JSON.stringify({
        apiOperation: "VOID",
        reason: reason ?? "Order cancelled",
      }),
    },
  );

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { kashierOrderId, status: res.status, error },
      "[Kashier] Void failed",
    );
    throw new HttpError(
      res.status,
      `Kashier Void Error: ${JSON.stringify(error)}`,
    );
  }

  const data = (await res.json()) as KashierVoidResponse;

  const succeeded =
    data.response?.result === "SUCCESS" ||
    data.response?.status === "VOIDED" ||
    data.response?.status === "CANCELLED";

  if (!succeeded) {
    logger.error(
      { kashierOrderId, response: data.response },
      "[Kashier] Void declined by gateway",
    );
    throw new HttpError(
      422,
      `Kashier void declined: ${data.response?.gatewayCode ?? data.response?.status}`,
    );
  }

  logger.info(
    { kashierOrderId, voidTxId: data.response.transactionId },
    "[Kashier] Void successful",
  );
  return data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience: build the checkout URL for the session
// (some flows redirect client to sessionUrl directly; this is a pass-through)
// ─────────────────────────────────────────────────────────────────────────────

export function getKashierCheckoutUrl(sessionUrl: string): string {
  return sessionUrl;
}
