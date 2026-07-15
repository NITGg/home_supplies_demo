import { prisma } from "@/config/prisma";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { HttpError } from "@/lib/httpError";
import { Prisma } from "@prisma/client";
import env from "@/config/env";
import {
  createPaymobIntention,
  getPaymobCheckoutUrl,
  verifyPaymobCallback,
} from "@/services/paymob.service";
import type {
  CreateIntentionRequest,
  IntentionResponse,
  TransactionCallback,
} from "@/types/paymob.types";
import {
  createKashierSession,
  verifyKashierWebhook,
} from "@/services/kashier.service";
import {
  createEasykashPayment,
  inquireEasykashPayment,
} from "@/services/easykash.service";
import type { EasykashCallbackPayload } from "@/types/easykash.types";
import type { KashierWebhookPayload } from "@/types/kashier.types";
import type {
  WalletRechargeConfirmCallbackInput,
  WalletRechargeInitInput,
  KashierWebhookBodyInput,
} from "../schemas/wallet.schema";
import { Tx } from "@/types/prisma.types";
import FeatureApi from "@/lib/featureApi";
import { logger } from "@/config/logger";
import { Lang } from "@/types/express";
import { roles } from "@/middlewares/auth/requireRole";
import { sendWebhookEvent } from "@/queues/webhook/webhook.service";
import type { WebhookWalletRechargedPayload } from "@/queues/webhook/webhook.types";

export async function getMyWalletService(userId: number) {
  type RawUserRow = {
    id: number;
    role_id: number;
    badge_id: number | null;
    courier_id: number | null;
    wallet_id: number | null;
    balance: number | null;
    points: number | null;
    status: string | null;
    owner_type: string | null;
    freeze_reason: string | null;
    frozen_at: Date | null;
  };

  const rows = await prisma.$queryRaw<RawUserRow[]>`
  SELECT
    u.id,
    u.role_id,
    u.badge_id,
    c.id AS courier_id,
    w.id AS wallet_id,
    w.balance,
    w.points,
    w.status,
    w.owner_type,
    w.freeze_reason,
    w.frozen_at
  FROM \`user\` AS u
  LEFT JOIN \`courier\` AS c ON c.user_id = u.id
  LEFT JOIN \`wallet\`  AS w ON w.user_id = u.id
  WHERE u.id = ${userId}
  LIMIT 1
`;

  const row = rows[0];
  if (!row) throw new HttpError(404, "users:errors.not_found");

  const user = {
    id: row.id,
    role_id: row.role_id,
    badge_id: row.badge_id,
    courier: row.courier_id ? { id: row.courier_id } : null,
    wallet: row.wallet_id
      ? {
          id: row.wallet_id,
          balance: row.balance ?? 0,
          points: row.points,
          status: row.status,
          owner_type: row.owner_type,
          freeze_reason: row.freeze_reason,
          frozen_at: row.frozen_at,
        }
      : null,
  };

  if (!user) {
    throw new HttpError(404, "users:errors.not_found");
  }

  const wallet =
    user.wallet ??
    (await prisma.wallet.create({
      data: { user_id: userId, owner_type: "CUSTOMER" },
      select: {
        id: true,
        balance: true,
        points: true,
        status: true,
        owner_type: true,
        freeze_reason: true,
        frozen_at: true,
      },
    }));
  const [completedCount, badges] = await Promise.all([
    prisma.order.count({
      where: user.courier?.id
        ? { courier_id: user.courier.id, status: "DELIVERED" }
        : { customer_id: userId, status: "DELIVERED" },
    }),
    prisma.userBadge.findMany({
      where: { role_id: user.role_id },
      orderBy: { min_count: "asc" },
    }),
  ]);

  if (badges.length === 0) {
    throw new HttpError(500, "badges:errors.no_badges_for_role");
  }

  // ✅ Current badge: from badge_id if exists, else fallback to base badge
  let badge = user.badge_id
    ? (badges.find((b) => b.id === user.badge_id) ?? null)
    : null;

  // ✅ Fallback: assign base badge if missing
  if (!badge) {
    const baseBadge = badges[0];

    await prisma.user.update({
      where: { id: userId },
      data: { badge_id: baseBadge.id },
      select: { id: true },
    });

    badge = baseBadge;
  }

  // ✅ Next badge computed in-memory (no DB query)
  const nextBadge =
    badges.find((b) => Number(b.min_count) > completedCount) ?? null;
  const remainingToNext = nextBadge
    ? Math.max(0, Math.ceil(Number(nextBadge.min_count) - completedCount))
    : 0;

  return {
    wallet,
    badge,
    completedCount,
    nextBadge,
    remainingToNext,
  };
}

export async function getMyTransactionsServices(
  userId: number,
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;
  const skip = data.skip ?? 0;

  const wallet = await prisma.wallet.findUnique({
    where: { user_id: userId },
    select: { id: true },
  });

  if (!wallet) throw new HttpError(404, "wallet:errors.not_found");

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
        orderBy: data.orderBy,
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

export async function getMyPenaltiesService(
  userId: number,
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;
  const skip = data.skip ?? 0;

  const where: Prisma.PenaltyWhereInput = {
    user_id: userId,
    ...data.where,
  };

  const [totalPenalties, penalties, aggregate] = await prisma.$transaction([
    prisma.penalty.count({ where }),
    prisma.penalty.findMany({
      where,
      take,
      skip,
      select: data.select,
      orderBy: data.orderBy,
    }),
    prisma.penalty.aggregate({
      where: {
        user_id: userId,
        is_paid: false,
        is_waived: false,
      },
      _sum: { amount: true },
    }),
  ]);

  const totalPenaltiesAmount = Number(aggregate._sum.amount ?? 0);

  return {
    totalPenalties,
    totalPages: Math.ceil(totalPenalties / take),
    totalPenaltiesAmount,
    penalties,
  };
}
export async function getMyUnpaidCommissionService(
  userId: number,
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;
  const skip = data.skip ?? 0;

  const where: Prisma.UnpaidCommissionWhereInput = {
    user_id: userId,
    ...data.where,
  };
  const [totalUnpaidCommissions, UnpaidCommissions, aggregate] =
    await prisma.$transaction([
      prisma.unpaidCommission.count({ where }),
      prisma.unpaidCommission.findMany({
        where,
        take,
        skip,
        select: data.select,
        orderBy: data.orderBy,
      }),
      prisma.unpaidCommission.aggregate({
        where: {
          user_id: userId,
          is_paid: false,
        },
        _sum: { amount: true },
      }),
    ]);

  const totalUnpaidCommissionsAmount = Number(aggregate._sum.amount ?? 0);

  return {
    totalUnpaidCommissions,
    totalPages: Math.ceil(totalUnpaidCommissions / take),
    totalUnpaidCommissionsAmount,
    UnpaidCommissions,
  };
}

function assertWalletCouponType(coupon: { type: string }) {
  if (coupon.type !== "WALLET_CREDIT") {
    throw new HttpError(400, "customer-coupons:errors.not_wallet_coupon");
  }
}

export function assertCouponDates(
  coupon: { start_at: Date | null; end_at: Date | null },
  now: Date,
) {
  if (coupon.start_at && now < coupon.start_at) {
    throw new HttpError(400, "customer-coupons:errors.not_started");
  }
  if (coupon.end_at && now > coupon.end_at) {
    throw new HttpError(400, "customer-coupons:errors.expired");
  }
}

export async function assertOrderCouponMinOrdersCount(
  tx: Tx,
  input: { userId: number },
  coupon: { min_orders_count: number },
) {
  if ((coupon.min_orders_count ?? 0) <= 0) return;

  const completed = await tx.order.count({
    where: { customer_id: input.userId, status: "DELIVERED" },
  });

  if (completed < coupon.min_orders_count) {
    throw new HttpError(
      400,
      "customer-coupons:errors.not_eligible_orders_count",
    );
  }
}

export async function assertOrderCouponUsageLimits(
  tx: Tx,
  input: { userId: number },
  coupon: {
    id: number;
    max_total_uses: number | null;
    max_user_uses: number | null;
  },
) {
  if (coupon.max_total_uses != null) {
    const totalUsed = await tx.customerCouponUsage.count({
      where: { coupon_id: coupon.id },
    });
    if (totalUsed >= coupon.max_total_uses) {
      throw new HttpError(
        400,
        "customer-coupons:errors.max_total_uses_reached",
      );
    }
  }

  if (coupon.max_user_uses != null) {
    const userUsed = await tx.customerCouponUsage.count({
      where: { coupon_id: coupon.id, user_id: input.userId },
    });
    console.log("userUsed", userUsed);

    if (userUsed >= coupon.max_user_uses) {
      throw new HttpError(400, "customer-coupons:errors.max_user_uses_reached");
    }
  }
}

function assertCreditsSomething(coupon: {
  wallet_amount_cents: number;
  wallet_points: number;
}) {
  if (
    (coupon.wallet_amount_cents ?? 0) <= 0 &&
    (coupon.wallet_points ?? 0) <= 0
  ) {
    throw new HttpError(400, "customer-coupons:errors.invalid_wallet_reward");
  }
}

async function createWalletCouponUsage(
  tx: Tx,
  input: { userId: number },
  coupon: { id: number },
) {
  return tx.customerCouponUsage.create({
    data: {
      user_id: input.userId,
      coupon_id: coupon.id,
      context: "WALLET",
      order_id: null,
      discount_cents: 0,
    },
    select: { id: true },
  });
}

async function upsertWalletAndApplyCredits(
  tx: Tx,
  input: { userId: number },
  coupon: { wallet_amount_cents: number; wallet_points: number },
) {
  return tx.wallet.upsert({
    where: { user_id: input.userId },
    create: {
      user_id: input.userId,
      owner_type: "CUSTOMER",
      balance: coupon.wallet_amount_cents,
      points: coupon.wallet_points,
      status: "ACTIVE",
    },
    update: {
      balance: { increment: coupon.wallet_amount_cents },
      points: { increment: coupon.wallet_points },
    },
    select: { id: true },
  });
}

async function createPointsLedgerIfNeeded(
  tx: Tx,
  walletId: number,
  coupon: { wallet_points: number; code: string },
  usageId: number,
) {
  if ((coupon.wallet_points ?? 0) <= 0) return;

  // await tx.pointsTransaction.create({
  //   data: {
  //     wallet_id: walletId,
  //     type: "REDEEM_COUPON",
  //     amount: coupon.wallet_points,
  //     description: `Coupon credit: ${coupon.code}`,
  //     coupon_usage_id: usageId,
  //   },
  //   select: { id: true },
  // });
}

async function createMoneyLedgerIfNeeded(
  tx: Tx,
  walletId: number,
  coupon: { wallet_amount_cents: number; code: string },
) {
  if ((coupon.wallet_amount_cents ?? 0) <= 0) return;

  await tx.transaction.create({
    data: {
      wallet_id: walletId,
      // Prefer adding TransactionType.REDEEM_COUPON; keeping your current enum value here:
      type: "COUPON_PURCHASE",
      status: "COMPLETED",
      amount: new Prisma.Decimal(coupon.wallet_amount_cents).div(100),
      description: `Coupon credit: ${coupon.code}`,
    },
    select: { id: true },
  });
}

async function assertWalletCouponEligible(
  tx: Tx,
  input: { userId: number; code: string },
  coupon: {
    id: number;
    code: string;
    type: string;
    start_at: Date | null;
    end_at: Date | null;
    min_orders_count: number;
    max_total_uses: number | null;
    max_user_uses: number | null;
    wallet_amount_cents: number;
    wallet_points: number;
  },
  now: Date,
) {
  assertWalletCouponType(coupon);
  assertCouponDates(coupon, now);
  await assertOrderCouponMinOrdersCount(tx, input, coupon);
  await assertOrderCouponUsageLimits(tx, input, coupon);
  assertCreditsSomething(coupon);
}

export async function redeemWalletCouponService(input: {
  userId: number;
  code: string;
}) {
  const now = new Date();
  const code = input.code.trim();

  return prisma.$transaction(async (tx) => {
    const coupon = await tx.customerCoupon.findFirst({
      where: { code, is_active: true, deleted_at: null },
      select: {
        id: true,
        code: true,
        type: true,
        start_at: true,
        end_at: true,
        min_orders_count: true,
        max_total_uses: true,
        max_user_uses: true,
        wallet_amount_cents: true,
        wallet_points: true,
      },
    });

    if (!coupon) throw new HttpError(404, "customer-coupons:errors.not_found");

    await assertWalletCouponEligible(tx, input, coupon, now);

    const usage = await createWalletCouponUsage(tx, input, coupon);
    const wallet = await upsertWalletAndApplyCredits(tx, input, coupon);

    await createPointsLedgerIfNeeded(tx, wallet.id, coupon, usage.id);
    await createMoneyLedgerIfNeeded(tx, wallet.id, coupon);

    return {
      ok: true as const,
      coupon: { id: coupon.id, code: coupon.code },
      credited: {
        amount_cents: coupon.wallet_amount_cents,
        points: coupon.wallet_points,
      },
      usage_id: usage.id,
    };
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

async function ensurePaymobPaymentMethod(userId: number) {
  const existing = await prisma.paymentMethod.findFirst({
    where: { user_id: userId, provider: "PAYMOB", deleted_at: null },
    select: { id: true },
  });
  if (existing) return existing;
  return prisma.paymentMethod.create({
    data: {
      user_id: userId,
      provider: "PAYMOB",
      method_type: "BANK_ACCOUNT",
      display_name: "Paymob",
    },
    select: { id: true },
  });
}

async function ensureKashierPaymentMethod(userId: number) {
  const existing = await prisma.paymentMethod.findFirst({
    where: { user_id: userId, provider: "KASHIER", deleted_at: null },
    select: { id: true },
  });
  if (existing) return existing;
  return prisma.paymentMethod.create({
    data: {
      user_id: userId,
      provider: "KASHIER",
      method_type: "BANK_ACCOUNT",
      display_name: "Kashier",
    },
    select: { id: true },
  });
}

async function ensureEasykashPaymentMethod(userId: number) {
  const existing = await prisma.paymentMethod.findFirst({
    where: { user_id: userId, provider: "EASYKASH", deleted_at: null },
    select: { id: true },
  });
  if (existing) return existing;
  return prisma.paymentMethod.create({
    data: {
      user_id: userId,
      provider: "EASYKASH",
      method_type: "BANK_ACCOUNT",
      display_name: "EasyKash",
    },
    select: { id: true },
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// step: claude: auto-settle outstanding penalties / unpaid commissions right after
// a successful wallet recharge — mirrors the courier wallet recharge flow
// (courier/src/modules/7. Wallet Management/wallet.service.ts confirmWalletRecharge),
// which auto-deducts unpaid commissions first (oldest first), then pending penalties
// (oldest first), skipping any debt the remaining balance can't fully cover, and
// crediting the platform wallet for each settled amount.
// Called from inside the same prisma.$transaction as the balance credit so the
// whole recharge + settlement is atomic.
// ─────────────────────────────────────────────────────────────────────────────
async function autoSettleDebtsAfterRecharge(
  tx: Tx,
  walletId: number,
  paymentMethodId?: number | null,
) {
  const wallet = await tx.wallet.findUnique({
    where: { id: walletId },
    select: { user_id: true, balance: true },
  });
  if (!wallet?.user_id) return;

  const platformWallet = await tx.wallet.findFirst({
    where: { owner_type: "PLATFORM" },
  });

  let remainingBalance = Number(wallet.balance) || 0;

  // ── Unpaid commissions (oldest first) ───────────────────────────────────────
  const unpaidCommissions = await tx.unpaidCommission.findMany({
    where: { user_id: wallet.user_id, is_paid: false },
    orderBy: { created_at: "asc" },
  });

  for (const commission of unpaidCommissions) {
    if (remainingBalance <= 0) break;

    const commissionAmount = Number(commission.amount);
    if (remainingBalance < commissionAmount) continue; // skip if can't fully cover

    await tx.unpaidCommission.update({
      where: { id: commission.id },
      data: { is_paid: true, paid_at: new Date() },
    });

    await tx.transaction.create({
      data: {
        wallet_id: walletId,
        order_id: commission.order_id,
        payment_method_id: paymentMethodId ?? undefined,
        type: "PLATFORM_COD_COMMISSION",
        status: "COMPLETED",
        amount: -commissionAmount,
        description: `Commission deduction for order #${commission.order_id}`,
      },
    });

    await adjustWalletBalance(tx, walletId, -commissionAmount, {
      unpaid_commission_id: commission.id,
      notes:
        "[autoSettleDebtsAfterRecharge] commission deduction after recharge",
    });

    if (platformWallet) {
      await adjustWalletBalance(tx, platformWallet.id, commissionAmount, {
        notes: `[autoSettleDebtsAfterRecharge] commission settled by user ${wallet.user_id}`,
      });
    }

    remainingBalance -= commissionAmount;
  }

  // ── Pending (non-waived) penalties (oldest first) ───────────────────────────
  const pendingPenalties = await tx.penalty.findMany({
    where: { user_id: wallet.user_id, is_paid: false, is_waived: false },
    orderBy: { created_at: "asc" },
  });

  for (const penalty of pendingPenalties) {
    if (remainingBalance <= 0) break;

    const penaltyAmount = Number(penalty.amount);
    if (remainingBalance < penaltyAmount) continue; // skip if can't fully cover

    await tx.penalty.update({
      where: { id: penalty.id },
      data: { is_paid: true, paid_at: new Date() },
    });

    await tx.transaction.create({
      data: {
        wallet_id: walletId,
        payment_method_id: paymentMethodId ?? undefined,
        type: "PENALTY",
        status: "COMPLETED",
        amount: -penaltyAmount,
        description: `Penalty payment: ${penalty.reason || "Penalty"}`,
      },
    });

    await adjustWalletBalance(tx, walletId, -penaltyAmount, {
      penalty_id: penalty.id,
      notes: "[autoSettleDebtsAfterRecharge] penalty deduction after recharge",
    });

    if (platformWallet) {
      await adjustWalletBalance(tx, platformWallet.id, penaltyAmount, {
        notes: `[autoSettleDebtsAfterRecharge] penalty settled by user ${wallet.user_id}`,
      });
    }

    remainingBalance -= penaltyAmount;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notify external app (partner) of a successful wallet recharge via webhook.
// No-op if the wallet doesn't belong to an external app, or the app has no
// webhook configured. Reused by all confirm* recharge services below.
// ─────────────────────────────────────────────────────────────────────────────

export async function notifyExternalAppWalletRecharged(
  walletId: number,
  transaction: { id: number; amount: Prisma.Decimal | number },
  balance: Prisma.Decimal | number,
) {
  const wallet = await prisma.wallet.findUnique({
    where: { id: walletId },
    select: {
      external_app_id: true,
      externalApp: {
        select: { id: true, webhook_url: true, webhook_secret: true },
      },
    },
  });

  const externalApp = wallet?.externalApp;
  if (!externalApp?.webhook_url || !externalApp?.webhook_secret) return;

  await sendWebhookEvent<WebhookWalletRechargedPayload>(externalApp.id, {
    eventType: "WALLET_RECHARGED",
    webhookUrl: externalApp.webhook_url,
    webhookSecret: externalApp.webhook_secret,
    payload: {
      wallet_id: walletId,
      transaction_id: transaction.id,
      amount: Number(transaction.amount),
      balance: Number(balance),
      recharged_at: new Date().toISOString(),
    },
  });
}

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

export async function initiateWalletRechargeService(input: {
  userId: number;
  user: {
    full_name: string;
    email?: string | null;
    phone?: string | null;
    role: roles;
  };
  notificationUrl: string;
  kashierWebhookUrl: string;
  easykashWebhookUrl: string;
  lang: Lang;
  data: WalletRechargeInitInput;
}) {
  // ── Ensure wallet exists and is not frozen ──────────────────────────────
  const wallet = await prisma.wallet.upsert({
    where: { user_id: input.userId },
    create: {
      user_id: input.userId,
      owner_type: input.user.role === "Courier" ? "COURIER" : "CUSTOMER",
      status: "ACTIVE",
    },
    update: {},
    select: { id: true, status: true },
  });
  if (wallet.status === "FROZEN") {
    throw new HttpError(403, "admin-wallet.errors.wallet_frozen");
  }

  // ── Validate chosen provider is active ─────────────────────────────────
  const gateways = await getActiveGateways();
  const provider = input.data.provider ?? "paymob";
  if (provider === "paymob" && !gateways.paymob)
    throw new HttpError(400, "profile:errors.paymob_disabled");
  if (provider === "kashier" && !gateways.kashier)
    throw new HttpError(400, "profile:errors.kashier_disabled");
  if (provider === "easykash" && !gateways.easykash)
    throw new HttpError(400, "profile:errors.easykash_disabled");

  const amount = new Prisma.Decimal(input.data.amount_cents);
  // ── Route to correct gateway ────────────────────────────────────────────
  if (provider === "kashier") {
    const paymentMethod = await ensureKashierPaymentMethod(input.userId);
    const transaction = await prisma.transaction.create({
      data: {
        wallet_id: wallet.id,
        payment_method_id: paymentMethod.id,
        type: "TOPUP",
        status: "PENDING",
        amount,
        description: "Wallet recharge via Kashier",
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
        customer: {
          reference: String(input.userId),
          email: input.user.email ?? undefined,
        },
        enable3DS: true,
        serverWebhook: input.kashierWebhookUrl,
        ...(input.data.redirection_url
          ? { merchantRedirect: input.data.redirection_url }
          : {}),
        metaData: { transactionId: transaction.id, userId: input.userId },
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
      throw new HttpError(502, "profile:errors.recharge_init_failed");
    }
  }

  // ── EasyKash ────────────────────────────────────────────────────────────────
  if (provider === "easykash") {
    const paymentMethod = await ensureEasykashPaymentMethod(input.userId);
    const transaction = await prisma.transaction.create({
      data: {
        wallet_id: wallet.id,
        payment_method_id: paymentMethod.id,
        type: "TOPUP",
        status: "PENDING",
        amount,
        description: "Wallet recharge via EasyKash",
      },
      select: { id: true },
    });

    try {
      // Encode the mobile deep-link as ?redirect= on the webhook URL so EasyKash
      // appends its own status params and the controller can build the final redirect.
      const easykashCallbackUrl = input.data.redirection_url
        ? `${input.easykashWebhookUrl}?redirect=${encodeURIComponent(input.data.redirection_url)}`
        : input.easykashWebhookUrl;
      const names = splitName(input.user.full_name);
      const response = await createEasykashPayment({
        amount: input.data.amount_cents / 100, // EGP
        currency: "EGP",
        name: `${names.first_name} ${names.last_name}`.trim(),
        email: input.user.email ?? "na@example.com",
        mobile: input.user.phone ?? "NA",
        redirectUrl: easykashCallbackUrl,
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
      throw new HttpError(502, "profile:errors.recharge_init_failed");
    }
  }

  // ── Default: Paymob ─────────────────────────────────────────────────────
  const paymentMethod = await ensurePaymobPaymentMethod(input.userId);
  const transaction = await prisma.transaction.create({
    data: {
      wallet_id: wallet.id,
      payment_method_id: paymentMethod.id,
      type: "TOPUP",
      status: "PENDING",
      amount,
      description: "Wallet recharge via Paymob",
    },
    select: { id: true },
  });

  try {
    const names = splitName(input.user.full_name);
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
    throw new HttpError(502, "profile:errors.recharge_init_failed");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm Kashier webhook
// ─────────────────────────────────────────────────────────────────────────────

export async function confirmKashierRechargeService(input: {
  body: KashierWebhookBodyInput;
  signature: string;
}) {
  logger.info(
    { body: input.body, headers: input.body },
    "Received Kashier webhook",
  );
  const isValid = verifyKashierWebhook(
    input.body as unknown as KashierWebhookPayload,
    input.signature,
  );
  if (!isValid) {
    throw new HttpError(401, "profile:errors.recharge_invalid_hmac");
  }

  const { data } = input.body;

  // merchantOrderId format: "WALLET-TX-{transactionId}"
  const txIdMatch = data.merchantOrderId.match(/WALLET-TX-(\d+)/);
  if (!txIdMatch)
    throw new HttpError(400, "profile:errors.recharge_verify_failed");
  const transactionId = Number(txIdMatch[1]);

  const existing = await prisma.transaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      status: true,
      amount: true,
      wallet_id: true,
      kashier_order_id: true,
    },
  });

  if (!existing?.wallet_id)
    throw new HttpError(404, "profile:errors.recharge_not_found");

  if (existing.status === "COMPLETED") {
    return {
      alreadyApplied: true as const,
      transactionId: existing.id,
    };
  }

  if (data.status !== "SUCCESS") {
    await prisma.transaction.update({
      where: { id: existing.id },
      data: {
        status: "FAILED",
        reject_reason: `Kashier status: ${data.status}`,
      },
    });
    throw new HttpError(409, "profile:errors.recharge_not_successful");
  }

  // Kashier sends amount in EGP (not piastres). Transaction is stored in EGP too.
  // Compare EGP directly: existing.amount (Decimal EGP) vs data.amount (number EGP).
  const expectedEgp = Number(
    new Prisma.Decimal(existing.amount).div(100).toFixed(2),
  );
  const receivedEgp = Number(Number(data.amount).toFixed(2));
  if (receivedEgp !== expectedEgp) {
    throw new HttpError(409, "profile:errors.recharge_amount_mismatch");
  }

  // adjustWalletBalance expects cents — convert EGP → piastres
  const amountCents = Math.round(receivedEgp * 100);

  const result = await prisma.$transaction(async (tx) => {
    let wallet = await adjustWalletBalance(
      tx,
      existing.wallet_id!,
      amountCents,
      { notes: "[confirmKashierRechargeService]" },
    );
    const transaction = await tx.transaction.update({
      where: { id: existing.id },
      data: { status: "COMPLETED" },
      select: { id: true, status: true, amount: true, kashier_order_id: true },
    });

    // step: claude: auto-settle any outstanding penalties / unpaid commissions
    // with the freshly-recharged balance (mirrors courier wallet recharge flow)
    await autoSettleDebtsAfterRecharge(tx, existing.wallet_id!);
    wallet =
      (await tx.wallet.findUnique({ where: { id: existing.wallet_id! } })) ??
      wallet;

    return { wallet, transaction };
  });

  await notifyExternalAppWalletRecharged(
    existing.wallet_id!,
    result.transaction,
    result.wallet.balance,
  );

  return { alreadyApplied: false as const, ...result };
}

export async function confirmWalletRechargeService(input: {
  body: WalletRechargeConfirmCallbackInput;
  hmac: string;
}) {
  const isValidHmac = verifyPaymobCallback(
    input.body as TransactionCallback,
    input.hmac,
  );
  if (!isValidHmac) {
    throw new HttpError(401, "profile:errors.recharge_invalid_hmac");
  }

  const paymobTx = input.body.obj;
  const paymobOrderId = String(paymobTx.order?.id ?? "");
  if (!paymobOrderId) {
    throw new HttpError(400, "profile:errors.recharge_verify_failed");
  }

  const existing = await prisma.transaction.findFirst({
    where: {
      paymob_order_id: paymobOrderId,
      type: "TOPUP",
    },
    select: {
      id: true,
      status: true,
      amount: true,
      wallet_id: true,
    },
  });

  if (!existing?.wallet_id) {
    throw new HttpError(404, "profile:errors.recharge_not_found");
  }

  if (existing.status === "COMPLETED") {
    const wallet = await prisma.wallet.findUnique({
      where: { id: existing.wallet_id },
      select: { id: true, points: true },
    });

    return {
      alreadyApplied: true as const,
      transactionId: existing.id,
      wallet,
    };
  }

  const successful =
    paymobTx.success === true &&
    paymobTx.pending === false &&
    paymobTx.is_refunded === false &&
    paymobTx.is_voided === false;

  if (!successful) {
    await prisma.transaction.update({
      where: { id: existing.id },
      data: {
        status: "FAILED",
        reject_reason: "Paymob transaction not successful",
      },
    });
    throw new HttpError(409, "profile:errors.recharge_not_successful");
  }

  const paymobAmountCents = Number(paymobTx.amount_cents ?? 0);
  const expectedAmountCents = Number(
    new Prisma.Decimal(existing.amount).mul(100).toFixed(0),
  );
  if (paymobAmountCents !== expectedAmountCents) {
    throw new HttpError(409, "profile:errors.recharge_amount_mismatch");
  }

  // const appSettings = await prisma.applicationSetting.findFirst({
  //   orderBy: { id: "desc" },
  //   select: { points_ratio: true },
  // });
  // const pointsRatio = appSettings?.points_ratio ?? 10;
  // const pointsToCredit = Math.round((paymobAmountCents * pointsRatio) / 100);

  const result = await prisma.$transaction(async (tx) => {
    let wallet = await adjustWalletBalance(
      tx,
      existing.wallet_id!,
      paymobAmountCents,
      { notes: "[confirmWalletRechargeService]" },
    );

    const transaction = await tx.transaction.update({
      where: { id: existing.id },
      data: { status: "COMPLETED" },
      select: { id: true, status: true, amount: true, paymob_order_id: true },
    });

    // step: claude: auto-settle any outstanding penalties / unpaid commissions
    // with the freshly-recharged balance (mirrors courier wallet recharge flow)
    await autoSettleDebtsAfterRecharge(tx, existing.wallet_id!);
    wallet =
      (await tx.wallet.findUnique({ where: { id: existing.wallet_id! } })) ??
      wallet;

    // await tx.pointsTransaction.create({
    //   data: {
    //     wallet_id: wallet.id,
    //     type: "MANUAL_INCREASE",
    //     points: pointsToCredit,
    //     description: `Paymob recharge ${paymobOrderId}`,
    //   },
    // });

    return { wallet, transaction };
    // return { wallet, transaction, creditedPoints: pointsToCredit, pointsRatio };
  });

  await notifyExternalAppWalletRecharged(
    existing.wallet_id!,
    result.transaction,
    result.wallet.balance,
  );

  return {
    alreadyApplied: false as const,
    ...result,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm EasyKash wallet recharge
// Called from the GET callback URL EasyKash redirects to after payment.
// We verify by inquiring the live status from EasyKash rather than trusting
// the query-string params directly.
// ─────────────────────────────────────────────────────────────────────────────

export async function confirmEasykashRechargeService(
  payload: EasykashCallbackPayload,
) {
  const transactionId = Number(payload.customerReference);
  if (!transactionId || Number.isNaN(transactionId)) {
    throw new HttpError(400, "profile:errors.recharge_verify_failed");
  }

  // Authoritative status from EasyKash
  const inquiry = await inquireEasykashPayment(payload.customerReference);
  logger.info(
    { transactionId, status: inquiry.status },
    "[EasyKash] Wallet recharge inquiry",
  );

  const existing = await prisma.transaction.findUnique({
    where: { id: transactionId },
    select: {
      id: true,
      status: true,
      amount: true,
      wallet_id: true,
      type: true,
    },
  });

  if (!existing?.wallet_id || existing.type !== "TOPUP") {
    throw new HttpError(404, "profile:errors.recharge_not_found");
  }

  if (existing.status === "COMPLETED") {
    return { alreadyApplied: true as const, transactionId: existing.id };
  }

  if (inquiry.status !== "PAID") {
    await prisma.transaction.update({
      where: { id: existing.id },
      data: {
        status: "FAILED",
        reject_reason: `EasyKash status: ${inquiry.status}`,
      },
    });
    throw new HttpError(409, "profile:errors.recharge_not_successful");
  }

  // EasyKash returns amount in EGP; transaction.amount is stored in EGP (as cents / 100).
  // const expectedEgp = Number(
  //   new Prisma.Decimal(existing.amount).div(100).toFixed(2),
  // );
  // const receivedEgp = Number(Number(inquiry.Amount).toFixed(2));
  // if (receivedEgp !== expectedEgp) {
  //   throw new HttpError(409, "profile:errors.recharge_amount_mismatch");
  // }

  // const amountCents = Math.round(receivedEgp * 100);

  const result = await prisma.$transaction(async (tx) => {
    let wallet = await adjustWalletBalance(
      tx,
      existing.wallet_id!,
      +existing.amount,
      { notes: "[confirmEasykashRechargeService]" },
    );
    const transaction = await tx.transaction.update({
      where: { id: existing.id },
      data: { status: "COMPLETED" },
      select: { id: true, status: true, amount: true },
    });

    // step: claude: auto-settle any outstanding penalties / unpaid commissions
    // with the freshly-recharged balance (mirrors courier wallet recharge flow)
    await autoSettleDebtsAfterRecharge(tx, existing.wallet_id!);
    wallet =
      (await tx.wallet.findUnique({ where: { id: existing.wallet_id! } })) ??
      wallet;

    return { wallet, transaction };
  });

  await notifyExternalAppWalletRecharged(
    existing.wallet_id!,
    result.transaction,
    result.wallet.balance,
  );

  return { alreadyApplied: false as const, ...result };
}
