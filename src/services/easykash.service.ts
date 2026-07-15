import crypto from "node:crypto";
import env from "@/config/env";
import { logger } from "@/config/logger";
import { HttpError } from "@/lib/httpError";
import type {
  EasykashPayRequest,
  EasykashPayResponse,
  EasykashCallbackPayload,
  EasykashInquiryResponse,
} from "@/types/easykash.types";

// ─── Config ───────────────────────────────────────────────────────────────────

const CONFIG = {
  API_KEY: env.EASYKASH_API_KEY,
  HMAC_SECRET: env.EASYKASH_HMAC_SECRET,
  BASE_URL: env.EASYKASH_BASE_URL ?? "https://back.easykash.net",
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function parseJsonSafe<T>(
  res: Response,
): Promise<T | Record<string, never>> {
  try {
    return (await res.json()) as T;
  } catch {
    return {};
  }
}

// ─── Create Direct Pay Link ───────────────────────────────────────────────────
// POST /api/directpayv1/pay
// Returns a redirectUrl the client opens to complete payment.
// ─────────────────────────────────────────────────────────────────────────────

export async function createEasykashPayment(
  request: EasykashPayRequest,
): Promise<EasykashPayResponse> {
  const res = await fetch(`${CONFIG.BASE_URL}/api/directpayv1/pay`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      authorization: CONFIG.API_KEY,
    },
    body: JSON.stringify(request),
  });

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { status: res.status, error, ref: request.customerReference },
      "[EasyKash] Create payment failed",
    );
    throw new HttpError(res.status, `EasyKash Error: ${JSON.stringify(error)}`);
  }

  const data = (await res.json()) as EasykashPayResponse;
  logger.info(
    { ref: request.customerReference, checkoutUrl: data.redirectUrl, data },
    "[EasyKash] Payment created",
  );
  return data;
}

// ─── Payment Inquiry ─────────────────────────────────────────────────────────
// POST /api/cash-api/inquire
// Poll payment status by customerReference.
// ─────────────────────────────────────────────────────────────────────────────

export async function inquireEasykashPayment(
  customerReference: string,
): Promise<EasykashInquiryResponse> {
  const res = await fetch(`${CONFIG.BASE_URL}/api/cash-api/inquire`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      authorization: CONFIG.API_KEY,
    },
    body: JSON.stringify({ customerReference }),
  });

  if (!res.ok) {
    const error = await parseJsonSafe<Record<string, unknown>>(res);
    logger.error(
      { status: res.status, error, customerReference },
      "[EasyKash] Inquiry failed",
    );
    throw new HttpError(
      res.status,
      `EasyKash Inquiry Error: ${JSON.stringify(error)}`,
    );
  }

  return (await res.json()) as EasykashInquiryResponse;
}

// ─── Verify Callback Signature ────────────────────────────────────────────────
// Algorithm: HMAC-SHA512 over concatenated fields (no delimiter), hex key.
//
// Field order: ProductCode + Amount + ProductType + PaymentMethod +
//              status + easykashRef + customerReference
// ─────────────────────────────────────────────────────────────────────────────

export function verifyEasykashCallback(
  payload: EasykashCallbackPayload,
): boolean {
  try {
    const data = [
      payload.ProductCode,
      payload.Amount,
      payload.ProductType,
      payload.PaymentMethod,
      payload.status,
      payload.easykashRef,
      payload.customerReference,
    ].join("");

    // The HMAC_SECRET is provided as a hex string — decode to raw bytes
    // const key = Buffer.from(CONFIG.HMAC_SECRET, "hex");

    const calculated = crypto
      .createHmac("sha512", CONFIG.HMAC_SECRET)
      .update(data)
      .digest("hex");

    logger.debug(
      { calculated, received: payload.signatureHash },
      "[EasyKash] Signature check",
    );

    return calculated === payload.signatureHash;
  } catch (err) {
    logger.error({ err }, "[EasyKash] Signature verification error");
    return false;
  }
}
