import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import { Prisma } from "@prisma/client";
import env from "@/config/env";
import {
  createPaymobIntention,
  getPaymobCheckoutUrl,
} from "@/services/paymob.service";
import type {
  CreateIntentionRequest,
  IntentionResponse,
} from "@/types/paymob.types";
import { createKashierSession } from "@/services/kashier.service";
import { createEasykashPayment } from "@/services/easykash.service";
import type { Lang } from "@/types/express";
import type { ExternalAppWalletRechargeInitInput } from "../schemas/externalApp.wallet.schema";

export async function getExternalAppWalletService(externalAppId: number) {
  const wallet = await prisma.wallet.findUnique({
    where: { external_app_id: externalAppId },
    select: {
      id: true,
      balance: true,
      points: true,
      status: true,
      owner_type: true,
      freeze_reason: true,
      frozen_at: true,
      created_at: true,
      updated_at: true,
    },
  });

  if (!wallet)
    throw new HttpError(404, "external_apps:errors.wallet_not_found");

  return wallet;
}

export async function getExternalAppWalletTransactionsService(
  externalAppId: number,
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;
  const skip = data.skip ?? 0;

  const wallet = await prisma.wallet.findUnique({
    where: { external_app_id: externalAppId },
    select: { id: true },
  });

  if (!wallet)
    throw new HttpError(404, "external_apps:errors.wallet_not_found");

  const where: Prisma.TransactionWhereInput = {
    wallet_id: wallet.id,
    ...data.where,
  };

  const [totalTransactions, transactions, aggregate] =
    await prisma.$transaction([
      prisma.transaction.count({ where }),
      prisma.transaction.findMany({
        where,
        take,
        skip,
        select: data.select,
        orderBy: data.orderBy ?? { created_at: "desc" },
      }),
      prisma.transaction.aggregate({
        where,
        _sum: { amount: true },
      }),
    ]);

  const totalTransactionsAmount = Number(aggregate._sum.amount ?? 0);

  return {
    totalTransactions,
    totalPages: Math.ceil(totalTransactions / take),
    totalTransactionsAmount,
    transactions,
  };
}

// ─── Wallet recharge (top-up) ─────────────────────────────────────────────────

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

async function ensureExternalAppPaymentMethod(
  externalAppId: number,
  provider: "PAYMOB" | "KASHIER" | "EASYKASH",
) {
  const providerCustomerId = `external_app:${externalAppId}`;
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
      display_name: `${provider} (Partner #${externalAppId})`,
    },
    select: { id: true },
  });
}

export async function initiateExternalAppWalletRechargeService(input: {
  externalAppId: number;
  notificationUrl: string;
  kashierWebhookUrl: string;
  easykashWebhookUrl: string;
  lang: Lang;
  data: ExternalAppWalletRechargeInitInput;
}) {
  const app = await prisma.externalApp.findUnique({
    where: { id: input.externalAppId },
    select: { id: true, name: true },
  });
  if (!app) throw new HttpError(404, "external_apps:errors.not_found");

  // ── Ensure wallet exists and is not frozen ──────────────────────────────
  const wallet = await prisma.wallet.upsert({
    where: { external_app_id: input.externalAppId },
    create: {
      external_app_id: input.externalAppId,
      owner_type: "EXTERNAL_APP",
      status: "ACTIVE",
    },
    update: {},
    select: { id: true, status: true },
  });
  if (wallet.status === "FROZEN") {
    throw new HttpError(403, "external_apps:errors.wallet_not_active");
  }

  // ── Validate chosen provider is active ─────────────────────────────────
  const gateways = await getActiveGateways();
  const provider = input.data.provider ?? "paymob";
  if (provider === "paymob" && !gateways.paymob)
    throw new HttpError(400, "external_apps:errors.paymob_disabled");
  if (provider === "kashier" && !gateways.kashier)
    throw new HttpError(400, "external_apps:errors.kashier_disabled");
  if (provider === "easykash" && !gateways.easykash)
    throw new HttpError(400, "external_apps:errors.easykash_disabled");

  const amount = new Prisma.Decimal(input.data.amount_cents);
  const names = { first_name: app.name || "Partner", last_name: "NA" };

  // ── Kashier ──────────────────────────────────────────────────────────────
  if (provider === "kashier") {
    const paymentMethod = await ensureExternalAppPaymentMethod(
      input.externalAppId,
      "KASHIER",
    );
    const transaction = await prisma.transaction.create({
      data: {
        wallet_id: wallet.id,
        payment_method_id: paymentMethod.id,
        type: "TOPUP",
        status: "PENDING",
        amount,
        description: `Wallet recharge via Kashier (partner #${input.externalAppId})`,
      },
      select: { id: true },
    });

    try {
      const session = await createKashierSession({
        amount: (input.data.amount_cents / 100).toString(),
        currency: "EGP",
        display: input.lang,
        merchantId: env.KASHIER_MERCHANT_ID,
        order: `WALLET-TX-${transaction.id}`,
        type: "one-time",
        allowedMethods: "card,wallet",
        customer: { reference: `external_app_${input.externalAppId}` },
        enable3DS: true,
        serverWebhook: input.kashierWebhookUrl,
        ...(input.data.redirection_url
          ? { merchantRedirect: input.data.redirection_url }
          : {}),
        metaData: {
          transactionId: transaction.id,
          externalAppId: input.externalAppId,
        },
      });

      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { kashier_order_id: session._id },
      });

      return {
        provider: "kashier" as const,
        transactionId: transaction.id,
        checkoutUrl: session.sessionUrl,
        sessionId: session._id,
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
      throw new HttpError(502, "external_apps:errors.recharge_init_failed");
    }
  }

  // ── EasyKash ────────────────────────────────────────────────────────────────
  if (provider === "easykash") {
    const paymentMethod = await ensureExternalAppPaymentMethod(
      input.externalAppId,
      "EASYKASH",
    );
    const transaction = await prisma.transaction.create({
      data: {
        wallet_id: wallet.id,
        payment_method_id: paymentMethod.id,
        type: "TOPUP",
        status: "PENDING",
        amount,
        description: `Wallet recharge via EasyKash (partner #${input.externalAppId})`,
      },
      select: { id: true },
    });

    try {
      const response = await createEasykashPayment({
        amount: input.data.amount_cents / 100, // EGP
        currency: "EGP",
        name: `${names.first_name} ${names.last_name}`.trim(),
        email: "na@example.com",
        mobile: "NA",
        redirectUrl: input.data.redirection_url ?? input.easykashWebhookUrl,
        customerReference: transaction.id,
      });

      return {
        provider: "easykash" as const,
        transactionId: transaction.id,
        checkoutUrl: response.redirectUrl,
      };
    } catch (err: any) {
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: "FAILED",
          reject_reason:
            err?.message?.slice?.(0, 255) ?? "EasyKash payment creation failed",
        },
      });
      throw new HttpError(502, "external_apps:errors.recharge_init_failed");
    }
  }

  // ── Default: Paymob ─────────────────────────────────────────────────────
  const paymentMethod = await ensureExternalAppPaymentMethod(
    input.externalAppId,
    "PAYMOB",
  );
  const transaction = await prisma.transaction.create({
    data: {
      wallet_id: wallet.id,
      payment_method_id: paymentMethod.id,
      type: "TOPUP",
      status: "PENDING",
      amount,
      description: `Wallet recharge via Paymob (partner #${input.externalAppId})`,
    },
    select: { id: true },
  });

  try {
    const request: CreateIntentionRequest = {
      amount: input.data.amount_cents,
      currency: "EGP",
      payment_methods: [env.PAYMOB_PAYMENT_METHODS],
      items: [
        {
          name: `Wallet Recharge #${transaction.id}`,
          amount: input.data.amount_cents,
          quantity: 1,
        },
      ],
      billing_data: {
        ...names,
        email: "na@example.com",
        phone_number: "NA",
        apartment: "NA",
        floor: "NA",
        street: "NA",
        building: "NA",
        city: "NA",
        country: "EG",
        state: "NA",
      },
      special_reference: `WALLET-TX-${transaction.id}`,
      notification_url: input.notificationUrl,
      ...(input.data.redirection_url
        ? { redirection_url: input.data.redirection_url }
        : {}),
    };

    const intention: IntentionResponse = await createPaymobIntention(request);

    await prisma.transaction.update({
      where: { id: transaction.id },
      data: { paymob_order_id: String(intention.intention_order_id) },
    });

    return {
      provider: "paymob" as const,
      transactionId: transaction.id,
      clientSecret: intention.client_secret,
      checkoutUrl: getPaymobCheckoutUrl(intention.client_secret),
      intentionOrderId: intention.intention_order_id,
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
    throw new HttpError(502, "external_apps:errors.recharge_init_failed");
  }
}
