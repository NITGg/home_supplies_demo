import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import env from "@/config/env";
import {
  createPaymobIntention,
  getPaymobCheckoutUrl,
} from "@/services/paymob.service";
import { createKashierSession } from "@/services/kashier.service";
import { createEasykashPayment } from "@/services/easykash.service";
import type {
  CreateIntentionRequest,
  IntentionResponse,
} from "@/types/paymob.types";
import type { Lang } from "@/types/express";
import { logger } from "@/config/logger";

// ─── Types ────────────────────────────────────────────────────────────────────

type GatewayProvider = "paymob" | "kashier" | "easykash";

export interface InitiateOrderPaymentInput {
  userId?: number;
  externalAppId?: number;
  orderId: number;
  amountCents: number;
  orderNumber: string;
  user: { full_name: string; email?: string | null; phone?: string | null };
  provider: GatewayProvider;
  lang: Lang;
  redirectionUrl?: string;
  paymobWebhookUrl: string;
  kashierWebhookUrl: string;
  easykashWebhookUrl: string;
}

export interface OrderPaymentResult {
  provider: GatewayProvider;
  transactionId: number;
  checkoutUrl: string;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function getActiveGateways() {
  const settings = await prisma.applicationSetting.findUnique({
    where: { id: 1 },
    select: {
      paymob_enabled: true,
      kashier_enabled: true,
      easykash_enabled: true,
    },
  });
  return {
    paymob: settings?.paymob_enabled ?? true,
    kashier: settings?.kashier_enabled ?? false,
    easykash: settings?.easykash_enabled ?? false,
  };
}

async function ensurePaymentMethod(
  owner: { userId?: number; externalAppId?: number },
  provider: "PAYMOB" | "KASHIER" | "EASYKASH",
) {
  const providerName = (() => {
    if (provider === "PAYMOB") return "Paymob";
    if (provider === "EASYKASH") return "EasyKash";
    return "Kashier";
  })();

  if (owner.externalAppId) {
    const providerCustomerId = `external_app:${owner.externalAppId}`;
    const existing = await prisma.paymentMethod.findFirst({
      where: {
        provider,
        provider_customer_id: providerCustomerId,
        deleted_at: null,
      },
      select: { id: true },
    });
    if (existing) return existing;
    return prisma.paymentMethod.create({
      data: {
        user_id: null,
        provider,
        provider_customer_id: providerCustomerId,
        method_type: "BANK_ACCOUNT",
        display_name: `${providerName} (Partner #${owner.externalAppId})`,
      },
      select: { id: true },
    });
  }

  const existing = await prisma.paymentMethod.findFirst({
    where: { user_id: owner.userId, provider, deleted_at: null },
    select: { id: true },
  });
  if (existing) return existing;
  return prisma.paymentMethod.create({
    data: {
      user_id: owner.userId,
      provider,
      method_type: "BANK_ACCOUNT",
      display_name: providerName,
    },
    select: { id: true },
  });
}

function splitName(fullName: string | null | undefined) {
  const safe = (fullName ?? "").trim();
  if (!safe) return { first_name: "NA", last_name: "NA" };
  const [first, ...rest] = safe.split(/\s+/);
  return {
    first_name: first || "NA",
    last_name: rest.join(" ") || first || "NA",
  };
}

// ─── Main: initiate card payment for an order ─────────────────────────────────

export async function initiateOrderPayment(
  input: InitiateOrderPaymentInput,
): Promise<OrderPaymentResult> {
  const gateways = await getActiveGateways();

  if (input.provider === "paymob" && !gateways.paymob)
    throw new HttpError(400, "profile:errors.paymob_disabled");
  if (input.provider === "kashier" && !gateways.kashier)
    throw new HttpError(400, "profile:errors.kashier_disabled");
  if (input.provider === "easykash" && !gateways.easykash)
    throw new HttpError(400, "profile:errors.easykash_disabled");

  const amount = input.amountCents;

  if (input.provider === "kashier") {
    const paymentMethod = await ensurePaymentMethod(
      { userId: input.userId, externalAppId: input.externalAppId },
      "KASHIER",
    );

    const transaction = await prisma.transaction.create({
      data: {
        order_id: input.orderId,
        payment_method_id: paymentMethod.id,
        type: "ORDER_PAYMENT",
        status: "PENDING",
        amount,
        description: `Card payment for order ${input.orderNumber}`,
      },
      select: { id: true },
    });

    try {
      const session = await createKashierSession({
        amount: (input.amountCents / 100).toString(),
        currency: "EGP",
        display: input.lang,
        merchantId: env.KASHIER_MERCHANT_ID,
        order: `ORDER-TX-${transaction.id}`,
        type: "one-time",
        allowedMethods: "card,wallet",
        customer: {
          reference: input.userId
            ? String(input.userId)
            : `external_app:${input.externalAppId}`,
          email: input.user.email ?? undefined,
        },
        enable3DS: true,
        serverWebhook: input.kashierWebhookUrl,
        ...(input.redirectionUrl
          ? { merchantRedirect: input.redirectionUrl }
          : {}),
        metaData: { transactionId: transaction.id, orderId: input.orderId },
      });

      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          kashier_order_id: session._id,
          checkout_url: session.sessionUrl,
        },
      });

      return {
        provider: "kashier",
        transactionId: transaction.id,
        checkoutUrl: session.sessionUrl,
      };
    } catch (err: any) {
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: "FAILED",
          reject_reason:
            err?.message?.slice?.(0, 255) ?? "Kashier session failed",
        },
      });
      throw new HttpError(502, "orders:errors.payment_init_failed");
    }
  }

  // ── EasyKash ──────────────────────────────────────────────────────────────
  if (input.provider === "easykash") {
    const paymentMethod = await ensurePaymentMethod(
      { userId: input.userId, externalAppId: input.externalAppId },
      "EASYKASH",
    );

    const transaction = await prisma.transaction.create({
      data: {
        order_id: input.orderId,
        payment_method_id: paymentMethod.id,
        type: "ORDER_PAYMENT",
        status: "PENDING",
        amount,
        description: `Card payment for order ${input.orderNumber}`,
      },
      select: { id: true },
    });

    try {
      const names = splitName(input.user.full_name);
      // Encode the mobile deep-link as ?redirect= on the webhook URL so EasyKash
      // appends its own status params and the controller can build the final redirect.
      const easykashCallbackUrl = input.redirectionUrl
        ? `${input.easykashWebhookUrl}?redirect=${encodeURIComponent(input.redirectionUrl)}`
        : input.easykashWebhookUrl;
      const session = await createEasykashPayment({
        amount: 5, // EasyKash expects EGP
        // amount: input.amountCents / 100, // EasyKash expects EGP
        currency: "EGP",
        name: `${names.first_name} ${names.last_name}`.trim() || "Customer",
        email: input.user.email ?? "na@example.com",
        mobile: input.user.phone ?? "NA",
        redirectUrl: easykashCallbackUrl,
        customerReference: transaction.id,
      });

      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          // easykash_ref: session._id,
          checkout_url: session.redirectUrl,
        },
      });

      return {
        provider: "easykash",
        transactionId: transaction.id,
        checkoutUrl: session.redirectUrl,
      };
    } catch (err: any) {
      logger.error(err, "EasyKash payment initiation failed:");
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: "FAILED",
          reject_reason:
            err?.message?.slice?.(0, 255) ?? "EasyKash payment creation failed",
        },
      });
      throw new HttpError(502, "orders:errors.payment_init_failed");
    }
  }

  // ── Paymob (default) ──────────────────────────────────────────────────────
  const paymentMethod = await ensurePaymentMethod(
    { userId: input.userId, externalAppId: input.externalAppId },
    "PAYMOB",
  );

  const transaction = await prisma.transaction.create({
    data: {
      order_id: input.orderId,
      wallet_id: null,
      payment_method_id: paymentMethod.id,
      type: "ORDER_PAYMENT",
      status: "PENDING",
      amount,
      description: `Card payment for order ${input.orderNumber}`,
    },
    select: { id: true },
  });

  try {
    const names = splitName(input.user.full_name);
    const request: CreateIntentionRequest = {
      amount,
      currency: "EGP",
      payment_methods: [env.PAYMOB_PAYMENT_METHODS],
      items: [
        {
          name: `Order ${input.orderNumber}`,
          amount: input.amountCents,
          quantity: 1,
        },
      ],
      billing_data: {
        ...names,
        email: input.user.email ?? "na@example.com",
        phone_number: input.user.phone ?? "NA",
        apartment: "NA",
        floor: "NA",
        street: "NA",
        building: "NA",
        city: "NA",
        country: "EG",
        state: "NA",
      },
      special_reference: `ORDER-TX-${transaction.id}`,
      notification_url: input.paymobWebhookUrl,
      ...(input.redirectionUrl
        ? { redirection_url: input.redirectionUrl }
        : {}),
    };

    const intention: IntentionResponse = await createPaymobIntention(request);

    await prisma.transaction.update({
      where: { id: transaction.id },
      data: {
        paymob_order_id: String(intention.intention_order_id),
        checkout_url: getPaymobCheckoutUrl(intention.client_secret),
      },
    });

    return {
      provider: "paymob",
      transactionId: transaction.id,
      checkoutUrl: getPaymobCheckoutUrl(intention.client_secret),
    };
  } catch (err: any) {
    await prisma.transaction.update({
      where: { id: transaction.id },
      data: {
        status: "FAILED",
        reject_reason:
          err?.message?.slice?.(0, 255) ?? "Paymob intention failed",
      },
    });
    throw new HttpError(502, "orders:errors.payment_init_failed");
  }
}
