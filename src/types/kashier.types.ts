// ─────────────────────────────────────────────────────────────────────────────
// Kashier API Types
// POST https://api.kashier.io/v3/payment/sessions
// ─────────────────────────────────────────────────────────────────────────────

import { Lang } from "./express";

export interface KashierCustomer {
  /** Unique reference for the customer in your system */
  reference: string;
  email?: string;
}

export interface KashierCreateSessionRequest {
  /** Amount in smallest currency unit (cents/piastres) */
  amount: string;
  /** Merchant ID provided by Kashier */
  merchantId: string;
  /** ISO currency code, e.g. "EGP" */
  currency: string;
  /** Language to display in the checkout ("ar" or "en") */
  display: Lang;
  /** Your internal order reference */
  order: string;
  /** "one-time" | "recurring" */
  type: "one-time" | "recurring";
  /** "credit" | "debit" | etc. */
  paymentType?: string;
  /** Comma-separated: "card,wallet" */
  allowedMethods?: string;
  customer?: KashierCustomer;
  enable3DS?: boolean;
  /** URL Kashier will POST the webhook to */
  serverWebhook?: string;
  /** ISO timestamp — when the session expires */
  expireAt?: string;
  maxFailureAttempts?: number;
  /** Redirect here on success */
  merchantRedirect?: string;
  /** Redirect here on failure */
  failureRedirect?: string;
  /** Arbitrary metadata passed back in the webhook */
  metaData?: Record<string, unknown>;
}

export interface KashierCreateSessionResponse {
  _id: string;
  /** Ready-to-use payment URL to redirect the user to */
  sessionUrl: string;
  status: "CREATED" | string;
  paymentParams: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Webhook callback (sent via POST, verified via x-kashier-signature header)
// ─────────────────────────────────────────────────────────────────────────────

export type KashierWebhookEvent =
  | "pay"
  | "refund"
  | "authorize"
  | "void"
  | "capture";

export type KashierTransactionStatus = "SUCCESS" | "FAILED" | "PENDING";

export interface KashierWebhookData {
  merchantOrderId: string;
  kashierOrderId: string;
  orderReference: string;
  transactionId: string;
  status: KashierTransactionStatus;
  method: string;
  creationDate: string;
  amount: number;
  currency: string;
  card?: Record<string, unknown>;
  merchant?: Record<string, unknown>;
  metaData?: Record<string, unknown>;
  sourceOfFunds?: Record<string, unknown>;
  transactionResponseCode?: string;
  transactionResponseMessage?: Record<string, unknown>;
  channel?: string;
  merchantDetails?: Record<string, unknown>;
  /** Keys in this array are the fields used for signature */
  signatureKeys: string[];
  platform?: Record<string, unknown>;
}

export interface KashierWebhookPayload {
  event: KashierWebhookEvent;
  data: KashierWebhookData;
}
