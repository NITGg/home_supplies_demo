/**
 * Simple Paymob payment integration service.
 * Just import and use
 *
 * USAGE:
 * ------
 * import { PaymobService } from "../../utils/paymob/paymob.service";
 * paymobService = new PaymobService();
 *
 * 1. Create intention
 * const { client_secret, payment_key } = await paymobService.createIntention({
 *   amount: 100,      // (cents)
 *   customerName: 'John Doe',
 *   customerEmail: 'john@example.com',
 *   customerPhone: '01234567890',
 *   orderId: 'ORDER-123'
 * });
 *
 * 2. Get checkout URL
 * const url = paymobService.getCheckoutUrl(client_secret);
 *
 * 3. Verify webhook
 * const isValid = paymobService.verifyCallback(req.body, req.query.hmac);
 * ------
 */

import crypto from "crypto";
import {
  BillingData,
  CreateIntentionRequest,
  IntentionResponse,
  CreateQuickLinkRequest,
  QuickLinkResponse,
  TransactionCallback,
  PaymobConfig,
} from "./paymob.types";
import logger from "../../config/logger.config";
import { prisma } from "../../DB/lib/prisma";
import { env } from "../../config/env";

// ---------- Dynamic CONFIG ----------

export async function getConfig(): Promise<PaymobConfig> {
  const settings = await prisma.applicationSetting.findFirst();
  const isLive = settings?.live_payment ?? false;

  return isLive
    ? {
        API_KEY: env.PRODUCTION_PAYMOB_API_KEY || "",
        SECRET_KEY: env.PRODUCTION_PAYMOB_SECRET_KEY || "",
        PUBLIC_KEY: env.PRODUCTION_PAYMOB_PUBLIC_KEY || "",
        INTEGRATION_ID: env.PRODUCTION_PAYMOB_INTEGRATION_ID || "",
        HMAC_SECRET: env.PRODUCTION_PAYMOB_HMAC_SECRET || "",
        BASE_URL:
          env.PRODUCTION_PAYMOB_BASE_URL || "https://accept.paymob.com",
        NOTIFICATION_URL: env.PRODUCTION_PAYMOB_NOTIFICATION_URL || "",
        REDIRECTION_URL: env.PRODUCTION_PAYMOB_REDIRECTION_URL || "",
        REDIRECTION_URL_SUCCESS_URL:
          env.PRODUCTION_PAYMOB_REDIRECTION_URL_SUCCESS_URL || "",
        REDIRECTION_URL_FAILED_URL:
          env.PRODUCTION_PAYMOB_REDIRECTION_URL_FAILED_URL || "",
      }
    : {
        API_KEY: env.PAYMOB_API_KEY || "",
        SECRET_KEY: env.PAYMOB_SECRET_KEY || "",
        PUBLIC_KEY: env.PAYMOB_PUBLIC_KEY || "",
        INTEGRATION_ID: env.PAYMOB_INTEGRATION_ID || "",
        HMAC_SECRET: env.PAYMOB_HMAC_SECRET || "",
        BASE_URL: env.PAYMOB_BASE_URL || "https://accept.paymob.com",
        NOTIFICATION_URL: env.PAYMOB_NOTIFICATION_URL || "",
        REDIRECTION_URL: env.PAYMOB_REDIRECTION_URL || "",
        REDIRECTION_URL_SUCCESS_URL:
          env.PAYMOB_REDIRECTION_URL_SUCCESS_URL || "",
        REDIRECTION_URL_FAILED_URL:
          env.PAYMOB_REDIRECTION_URL_FAILED_URL || "",
      };
}

// ============ HELPER ============

// Convert EGP to cents
export const toCents = (amount: number) => Math.round(amount * 100);

// Convert cents to EGP
export const fromCents = (cents: number) => cents / 100;

// ============ SERVICE ============

export class PaymobService {
  private authToken: string | null = null;

  // ---------- createIntention ----------
  async createIntention(
    request: CreateIntentionRequest,
  ): Promise<IntentionResponse> {
    const CONFIG = await getConfig();
    const res = await fetch(`${CONFIG.BASE_URL}/v1/intention/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Token ${CONFIG.SECRET_KEY}`,
      },
      body: JSON.stringify(request),
    });

    if (!res.ok) {
      const error = await res.json().catch(() => ({}));
      logger.error(
        { status: res.status, error },
        "[Paymob] Create intention failed",
      );
      throw new Error(`Paymob Error: ${JSON.stringify(error)}`);
    }

    const data = await res.json();
    logger.info(
      { intentionOrderId: data.intention_order_id },
      "[Paymob] Payment intention created",
    );
    return data;
  }

  // ---------- getCheckoutUrl ----------
  async getCheckoutUrl(clientSecret: string): Promise<string> {
    const CONFIG = await getConfig();
    return `${CONFIG.BASE_URL}/unifiedcheckout/?publicKey=${CONFIG.PUBLIC_KEY}&clientSecret=${clientSecret}`;
  }

  // ---------- verifyCallback ----------
  /**
   * Verify webhook callback is from Paymob
   * @example
   * app.post('/notification_url', (req, res) => {
   *   if (!paymob.verifyCallback(req.body, req.query.hmac)) {
   *     return res.status(401).send('Invalid');
   *   }
   *   // Process payment...
   * });
   */
  async verifyCallback(
    body: TransactionCallback,
    hmac: string,
  ): Promise<boolean> {
    const CONFIG = await getConfig();
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

  // ---------- getAuthToken ----------
  async getAuthToken(): Promise<string> {
    if (this.authToken) return this.authToken;
    const CONFIG = await getConfig();

    const res = await fetch(`${CONFIG.BASE_URL}/api/auth/tokens`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: CONFIG.API_KEY }),
    });

    if (!res.ok) {
      logger.error({ status: res.status }, "[Paymob] Auth token fetch failed");
      throw new Error("Failed to authenticate with Paymob");
    }

    const data = await res.json();
    this.authToken = data.token;
    return data.token;
  }

  // ---------- refund ----------
  /**
   * Refund a transaction
   * @example
   * await paymob.refund(transactionId, 50); // refund 50 EGP
   */
  async refund(transactionId: number, amount: number): Promise<any> {
    const token = await this.getAuthToken();

    const CONFIG = await getConfig();
    const res = await fetch(
      `${CONFIG.BASE_URL}/api/acceptance/void_refund/refund`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: token,
          transaction_id: transactionId,
          amount_cents: amount,
        }),
      },
    );

    if (!res.ok) {
      logger.error({ transactionId, amount }, "[Paymob] Refund failed");
      throw new Error("Refund failed");
    }
    logger.info({ transactionId, amount }, "[Paymob] Refund successful");
    return res.json();
  }

  // ---------- void ----------
  // Void/cancel a transaction
  async void(transactionId: number): Promise<any> {
    const token = await this.getAuthToken();

    const CONFIG = await getConfig();
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
      logger.error({ transactionId }, "[Paymob] Void failed");
      throw new Error("Void failed");
    }
    logger.info({ transactionId }, "[Paymob] Transaction voided");
    return res.json();
  }

  // ---------- getTransaction ----------
  async getTransaction(transactionId: number): Promise<any> {
    const token = await this.getAuthToken();

    const CONFIG = await getConfig();
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

    if (!res.ok) throw new Error("Failed to get transaction");
    return res.json();
  }

  // ---------- createQuickLink ----------
  /**
   * Create a payment link to share with customer
   * Use when you want to send a link to a customer (via WhatsApp, SMS, Email) so they can pay LATER.
   * Returns a simple URL string (e.g. https://paymob.com/pay/...) hosted by Paymob.
   * VS createIntention: Use createIntention for immediate payment flows inside your app/website.
   *
   * @example
   * const link = await paymob.createQuickLink({
   *   amount: 100,
   *   customerName: 'John',
   *   customerEmail: 'john@example.com',
   *   customerPhone: '+201234567890',
   *   referenceId: 'ORDER-123'
   * });
   */
  async createQuickLink(options: {
    amount: number; // in EGP
    customerName: string;
    customerEmail: string;
    customerPhone: string;
    referenceId: string;
    description?: string;
    expiresAt?: string;
    isLive?: boolean;
  }): Promise<QuickLinkResponse> {
    const token = await this.getAuthToken();

    const CONFIG = await getConfig();
    const request: CreateQuickLinkRequest = {
      amount_cents: options.amount,
      reference_id: options.referenceId,
      integration_id: [parseInt(CONFIG.INTEGRATION_ID)],
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
      logger.error(
        { referenceId: options.referenceId },
        "[Paymob] Failed to create QuickLink",
      );
      throw new Error("Failed to create QuickLink");
    }
    const data = await res.json();
    logger.info(
      { referenceId: options.referenceId },
      "[Paymob] QuickLink created",
    );
    return data;
  }
}
