import { prisma } from "@/config/prisma";
import {
  ensureWallet,
  addToWallet,
  calcRewardPointsFromBadge,
  getPlatformWalletOrThrow,
} from "@/lib/walletHelper";
import { updateBadgeFromDeliveredCount } from "@/lib/badgeHelper";
import {
  notifyUser,
  notifyAdminsExcept,
} from "@/services/notification.service";
import type { AppEvents } from "@/types/events";
import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";
import { Prisma } from "@prisma/client";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { HttpError } from "@/lib/httpError";
import { notifySupplierOrder } from "./notifySupplier";
import { releasePartnerEscrow } from "@/modules/orders/services/orders.partner.service";
import { sendWebhookEvent } from "@/queues/webhook/webhook.service";
import { WebhookOrderDeliveredPayload } from "@/queues/webhook/webhook.types";
import { deleteOrderChatOnCompletion } from "@/modules/orders/services/orders.chat.service";

type Payload = AppEvents["order.delivered"];
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

type AmountDueNotice = {
  unpaidCommissionCount: number;
  unpaidPenaltyCount: number;
  totalAmount: Prisma.Decimal;
  maxAmount: Prisma.Decimal;
  percent: number;
  isExceeded: boolean;
};

// ─── Shared helpers ───────────────────────────────────────────────────────────

async function recordPlatformSubsidy(
  tx: Tx,
  orderId: number,
  courierUserId: number,
  subsidyAmount: number,
) {
  await tx.unpaidCommission.upsert({
    where: { order_id: orderId },
    create: {
      order_id: orderId,
      user_id: courierUserId,
      amount: new Prisma.Decimal(subsidyAmount),
      is_paid: false,
    },
    update: { amount: new Prisma.Decimal(subsidyAmount), is_paid: false },
  });
}

async function creditPlatformWallet(tx: Tx, orderId: number, amount: number) {
  const platformWallet = await getPlatformWalletOrThrow(tx);
  await adjustWalletBalance(tx, platformWallet.id, amount, {
    order_id: orderId,
  });
  await tx.transaction.create({
    data: {
      wallet_id: platformWallet.id,
      order_id: orderId,
      type: "PLATFORM_COD_COMMISSION",
      amount,
      status: "COMPLETED",
      description: `Platform commission received for order #${orderId}`,
    },
  });
}

/**
 * Builds an unpaid-dues notice for the courier.
 *
 * Point 6: `maxUnpaidAmount` now comes from the order's vehicle (`vehicle.total_fines`)
 * instead of `applicationSetting.total_fines`. If the order has no vehicle attached,
 * or the vehicle's `total_fines` is zero, the notice is skipped entirely.
 */
async function buildAmountDueNotice(
  tx: Tx,
  courierUserId: number,
  vehicleTotalFines: Prisma.Decimal,
): Promise<AmountDueNotice | null> {
  const maxUnpaidAmount = vehicleTotalFines.greaterThan(0)
    ? vehicleTotalFines
    : null;

  if (!maxUnpaidAmount) return null;

  const [commissionStats, penaltyStats] = await Promise.all([
    tx.unpaidCommission.aggregate({
      where: { user_id: courierUserId, is_paid: false },
      _count: { _all: true },
      _sum: { amount: true },
    }),
    tx.penalty.aggregate({
      where: { user_id: courierUserId, is_paid: false, is_waived: false },
      _count: { _all: true },
      _sum: { amount: true },
    }),
  ]);

  const totalDue = (
    commissionStats._sum.amount
      ? new Prisma.Decimal(commissionStats._sum.amount)
      : new Prisma.Decimal(0)
  ).add(
    penaltyStats._sum.amount
      ? new Prisma.Decimal(penaltyStats._sum.amount)
      : new Prisma.Decimal(0),
  );

  if (!totalDue.greaterThan(0)) return null;

  const percent = totalDue.div(maxUnpaidAmount).mul(100).toNumber();
  if (percent < 80) return null;

  return {
    unpaidCommissionCount: commissionStats._count._all ?? 0,
    unpaidPenaltyCount: penaltyStats._count._all ?? 0,
    totalAmount: totalDue.div(100),
    maxAmount: maxUnpaidAmount.div(100),
    percent,
    isExceeded: percent > 100,
  };
}

// ─── Customer payment handlers (unchanged logic) ──────────────────────────────

async function handleCustomerWalletPayment(
  tx: Tx,
  e: Payload & { courierUserId: number },
  orderId: number,
  customerWalletId: number,
  platformFeeNumber: number,
) {
  const platformWallet = await getPlatformWalletOrThrow(tx);
  const escrow = await tx.escrow.findFirst({
    where: { order_id: e.orderId, wallet_id: customerWalletId },
    orderBy: { created_at: "desc" },
  });
  console.log("customerWalletId", customerWalletId);
  console.log(escrow);

  if (!escrow?.held_amount) throw new HttpError(404, "error in escrow record");

  const heldAmount = new Prisma.Decimal(escrow.held_amount);
  const courierFeeCents = new Prisma.Decimal(e.courierFeeCents);
  const actualPrice = new Prisma.Decimal(e.actualPriceCents);
  const platformFee = new Prisma.Decimal(platformFeeNumber);

  const order = await tx.order.findUnique({
    where: { id: orderId },
    include: { orderItems: { include: { supplierProduct: true } } },
  });
  if (!order) {
    throw new HttpError(404, "[handleCustomerWalletPayment] Order not found");
  }

  if (order.supplier_id) {
    const supplier = await tx.supplier.findUnique({
      where: { id: order.supplier_id },
    });
    if (!supplier) {
      throw new HttpError(
        404,
        "[handleCustomerWalletPayment] Supplier not found",
      );
    }
    // Send total_cost_price to supplier wallet
    await addToWallet(tx, supplier.user_id, {
      target: "BALANCE",
      amount: +(order.total_cost_price ?? 0),
      orderId,
      escrowId: escrow.id,
      type: "ESCROW_RELEASE",
      description:
        "[handleCustomerWalletPayment] Send total_cost_price to supplier wallet",
    });
  } else {
    // Add each item cost_price to platform wallet
    let totalItemsCost = 0;
    for (const item of order.orderItems) {
      totalItemsCost += (item.cost_price || 0) * item.quantity;
    }
    if (totalItemsCost > 0) {
      await adjustWalletBalance(tx, platformWallet.id, totalItemsCost, {
        order_id: order.id,
      });
      await tx.transaction.create({
        data: {
          wallet_id: platformWallet.id,
          order_id: orderId,
          type: "ESCROW_RELEASE",
          amount: totalItemsCost,
          status: "COMPLETED",
          description: `[handleCustomerWalletPayment] Platform product cost price for order #${orderId}`,
        },
      });
    }

    // ✅ FIX 1: Pay courier the actual product price (was wrongly commented out)
    await addToWallet(tx, e.courierUserId, {
      target: "BALANCE",
      amount: +actualPrice,
      orderId,
      escrowId: escrow.id,
      type: "ESCROW_RELEASE",
      description:
        "[handleCustomerWalletPayment] Courier payment: product price",
    });
  }

  // Pay courier: delivery fee cut
  await addToWallet(tx, e.courierUserId, {
    target: "BALANCE",
    amount: +courierFeeCents,
    orderId,
    escrowId: escrow.id,
    type: "ESCROW_RELEASE",
    description:
      "[handleCustomerWalletPayment] Courier payment: delivery fee cut",
  });

  // Pay platform: delivery fee cut
  if (platformFeeNumber >= 0) {
    await adjustWalletBalance(tx, platformWallet.id, platformFeeNumber, {
      order_id: order.id,
    });
    await tx.transaction.create({
      data: {
        wallet_id: platformWallet.id,
        order_id: orderId,
        type: "PLATFORM_COD_COMMISSION",
        amount: platformFeeNumber,
        status: "COMPLETED",
        description: `[handleCustomerWalletPayment] Platform commission for order #${orderId}`,
      },
    });
  } else {
    const priceDiscrepancy =
      +e.actualPriceCents + +e.courierFeeCents - +e.paymentAmountCents;
    console.log("priceDiscrepancy", priceDiscrepancy);

    await adjustWalletBalance(tx, platformWallet.id, platformFeeNumber, {
      order_id: e.orderId,
      notes: `Total Due: ${+e.actualPriceCents + +e.courierFeeCents}, Collected: ${e.paymentAmountCents}. Gap: ${priceDiscrepancy}.`,
    });
    await tx.transaction.create({
      data: {
        wallet_id: platformWallet.id,
        order_id: orderId,
        type: "MANUAL_DECREASE",
        amount: platformFeeNumber,
        status: "COMPLETED",
        description:
          priceDiscrepancy > 0
            ? `Subsidy for price gap on order #${orderId} (Covered by Platform)`
            : `Marketing subsidy/discount payout for order #${orderId}`,
      },
    });
  }

  if (!order.supplier_id) {
    // --- DEBUG LOG START ---
    console.log(`[EscrowRelease:${e.orderId}] Starting calculation:`, {
      heldAmount: heldAmount.toString(),
      actualPrice: actualPrice.toString(),
      courierFee: courierFeeCents.toString(),
      platformFee: platformFee.toString(),
    });

    const disbursed = actualPrice
      .add(courierFeeCents)
      .add(platformFee.gt(0) ? platformFee : new Prisma.Decimal(0));

    const refund = heldAmount.sub(disbursed);

    console.log(`[EscrowRelease:${e.orderId}] Result:`, {
      totalDisbursed: disbursed.toString(),
      calculatedRefund: refund.toString(),
      hasRefund: refund.gt(0),
    });
    // --- DEBUG LOG END ---

    if (refund.gt(0)) {
      console.log(
        `[EscrowRelease:${e.orderId}] Triggering refund of ${refund.toString()} to customer ${e.customerId}`,
      );
      await addToWallet(tx, e.customerId!, {
        target: "BALANCE",
        amount: +refund,
        orderId: e.orderId,
        escrowId: escrow.id,
        type: "ESCROW_RELEASE",
        description:
          "[handleCustomerWalletPayment] Refund: overpayment (actual price < budget)",
      });
    }

    // 5. Clear escrow
    console.log(
      `[EscrowRelease:${e.orderId}] Finalizing: Clearing Escrow ${escrow.id}`,
    );

    await tx.escrow.update({
      where: { id: escrow.id },
      data: { held_amount: new Prisma.Decimal(0) },
    });

    await tx.transaction.create({
      data: {
        order_id: orderId,
        escrow_id: escrow.id,
        type: "ESCROW_REMOVE",
        amount: heldAmount,
        status: "COMPLETED",
        description: `[handleCustomerWalletPayment] Escrow cleared. Disbursed: ${disbursed}, Refunded: ${refund.gt(0) ? refund : 0}`,
      },
    });
  }

  // 5. Clear escrow
  await tx.escrow.update({
    where: { id: escrow.id },
    data: { held_amount: new Prisma.Decimal(0) },
  });
  await tx.transaction.create({
    data: {
      order_id: orderId,
      escrow_id: escrow.id,
      type: "ESCROW_REMOVE",
      amount: heldAmount,
      status: "COMPLETED",
      description: "[handleCustomerWalletPayment] Escrow cleared on delivery",
    },
  });
}

async function handleCustomerCashPayment(
  tx: Tx,
  e: Payload & { courierUserId: number },
  orderId: number,
  courierWalletBalance: Prisma.Decimal,
  platformFeeNumber: number,
  vehicleTotalFines: Prisma.Decimal,
): Promise<AmountDueNotice | null> {
  if (platformFeeNumber <= 0) {
    if (platformFeeNumber < 0) {
      const subsidyAmount = Math.abs(platformFeeNumber);
      const platformWallet = await getPlatformWalletOrThrow(tx);
      await addToWallet(tx, e.courierUserId, {
        target: "BALANCE",
        amount: subsidyAmount,
        type: "MANUAL_INCREASE",
        description: `Platform coupon subsidy paid to courier for order #${e.orderId}`,
      });
      const priceDiscrepancy =
        +e.actualPriceCents + +e.courierFeeCents - +e.paymentAmountCents;
      console.log("priceDiscrepancy", priceDiscrepancy);

      await adjustWalletBalance(tx, platformWallet.id, platformFeeNumber, {
        order_id: e.orderId,
        notes: `Total Due: ${+e.actualPriceCents + +e.courierFeeCents}, Collected: ${e.paymentAmountCents}. Gap: ${priceDiscrepancy}.`,
      });
      await tx.transaction.create({
        data: {
          wallet_id: platformWallet.id,
          order_id: orderId,
          type: "MANUAL_DECREASE",
          amount: platformFeeNumber,
          status: "COMPLETED",
          description:
            priceDiscrepancy > 0
              ? `Subsidy for price gap on order #${orderId} (Covered by Platform)`
              : `Marketing subsidy/discount payout for order #${orderId}`,
        },
      });
    }
    return null;
  }

  if (courierWalletBalance.greaterThanOrEqualTo(platformFeeNumber)) {
    await addToWallet(tx, e.courierUserId, {
      target: "BALANCE",
      amount: -platformFeeNumber,
      status: "COMPLETED",
      type: "PLATFORM_COD_COMMISSION",
      description: `Platform commission deducted for order #${orderId}`,
    });
    await creditPlatformWallet(tx, orderId, platformFeeNumber);
    return null;
  }

  await tx.unpaidCommission.upsert({
    where: { order_id: e.orderId },
    create: {
      order_id: e.orderId,
      user_id: e.courierUserId,
      amount: e.platformFeeCents,
      is_paid: false,
    },
    update: { amount: e.platformFeeCents, is_paid: false },
  });

  return buildAmountDueNotice(tx, e.courierUserId, vehicleTotalFines);
}

// ─── Partner payment handlers ─────────────────────────────────────────────────

async function handlePartnerWalletDelivery(
  tx: Tx,
  e: Payload & { courierUserId: number },
  orderId: number,
) {
  const partnerWallet = await tx.wallet.findFirst({
    where: { external_app_id: e.externalAppId },
    select: { id: true },
  });
  if (!partnerWallet)
    throw new HttpError(404, "external_apps:errors.wallet_not_found");

  const escrow = await tx.escrow.findFirst({
    where: { order_id: e.orderId, wallet_id: partnerWallet.id },
    orderBy: { created_at: "desc" },
  });
  if (!escrow?.held_amount)
    throw new HttpError(404, "error in partner escrow record");

  const courierFeeCents = new Prisma.Decimal(e.courierFeeCents);
  const platformFeeCents = new Prisma.Decimal(e.platformFeeCents);
  const partnerFeeCents = e.partnerFeeCents
    ? new Prisma.Decimal(e.partnerFeeCents)
    : new Prisma.Decimal(0);
  const heldAmount = new Prisma.Decimal(escrow.held_amount);

  // 1. Pay courier their cut
  await addToWallet(tx, e.courierUserId, {
    target: "BALANCE",
    amount: courierFeeCents.toNumber(),
    orderId,
    escrowId: escrow.id,
    type: "ESCROW_RELEASE",
    description: `Courier delivery fee for partner order #${orderId}`,
  });

  // 2. Platform takes its cut (app_fee portion)
  const platformWallet = await getPlatformWalletOrThrow(tx);
  await adjustWalletBalance(
    tx,
    platformWallet.id,
    platformFeeCents.toNumber(),
    { order_id: orderId },
  );
  await tx.transaction.create({
    data: {
      wallet_id: platformWallet.id,
      order_id: orderId,
      escrow_id: escrow.id,
      type: "PLATFORM_COD_COMMISSION",
      amount: platformFeeCents.toNumber(),
      status: "COMPLETED",
      description: `Platform commission for partner order #${orderId}`,
    },
  });

  // 3. Return partner_fee back to partner wallet (their agreed cut)
  if (partnerFeeCents.gt(0)) {
    await adjustWalletBalance(
      tx,
      partnerWallet.id,
      partnerFeeCents.toNumber(),
      { order_id: orderId },
    );
    await tx.transaction.create({
      data: {
        wallet_id: partnerWallet.id,
        order_id: orderId,
        escrow_id: escrow.id,
        type: "ESCROW_RELEASE",
        amount: partnerFeeCents.toNumber(),
        status: "COMPLETED",
        description: `Partner fee returned on delivery for order #${orderId}`,
      },
    });
  }

  // 4. Clear escrow
  await releasePartnerEscrow(tx, {
    orderId: e.orderId,
    externalAppId: e.externalAppId!,
    totalFee: heldAmount,
  });
}

async function handlePartnerCashDelivery(
  tx: Tx,
  e: Payload & { courierUserId: number },
  orderId: number,
  courierWalletBalance: Prisma.Decimal,
  vehicleTotalFines: Prisma.Decimal,
): Promise<AmountDueNotice | null> {
  const platformFeeCents = +e.platformFeeCents;
  const partnerFeeCents = e.partnerFeeCents ? +e.partnerFeeCents : 0;
  const totalOwed = platformFeeCents + partnerFeeCents;

  if (totalOwed <= 0) return null;

  if (courierWalletBalance.greaterThanOrEqualTo(totalOwed)) {
    await addToWallet(tx, e.courierUserId, {
      target: "BALANCE",
      amount: -totalOwed,
      status: "COMPLETED",
      type: "PLATFORM_COD_COMMISSION",
      description: `Platform + partner commission deducted for order #${orderId}`,
    });

    await creditPlatformWallet(tx, orderId, platformFeeCents);

    if (partnerFeeCents > 0) {
      const partnerWallet = await tx.wallet.findFirst({
        where: { external_app_id: e.externalAppId },
        select: { id: true },
      });

      if (partnerWallet) {
        await adjustWalletBalance(tx, partnerWallet.id, partnerFeeCents, {
          order_id: orderId,
        });
        await tx.transaction.create({
          data: {
            wallet_id: partnerWallet.id,
            order_id: orderId,
            type: "ESCROW_RELEASE",
            amount: partnerFeeCents,
            status: "COMPLETED",
            description: `Partner cash commission received for order #${orderId}`,
          },
        });
      }
    }

    return null;
  }

  // Insufficient courier balance — record full owed as unpaid
  await tx.unpaidCommission.upsert({
    where: { order_id: e.orderId },
    create: {
      order_id: e.orderId,
      user_id: e.courierUserId,
      amount: new Prisma.Decimal(totalOwed),
      is_paid: false,
    },
    update: {
      amount: new Prisma.Decimal(totalOwed),
      is_paid: false,
    },
  });

  return buildAmountDueNotice(tx, e.courierUserId, vehicleTotalFines);
}

// ─── Notifications ────────────────────────────────────────────────────────────

async function notifyBadgeUpgrade(
  user: { id: number; fcm_token: string | null; lang: string | null },
  badgeName: string | undefined,
  badgeNameAr: string | undefined,
  badgeId: number | undefined,
  page: string,
) {
  await notifyUser({
    user,
    content: {
      title: { en: "Your badge has been upgraded", ar: "تم ترقية شارتك" },
      body: {
        en: `Congratulations! Your badge is now ${badgeName ?? "updated"}.`,
        ar: `مبروك! أصبحت شارتك الآن ${badgeNameAr ?? "محدثة"}.`,
      },
    },
    data: { type: "BADGE_UPDATED", badgeId, page, navigate: "profile" },
  });
}

async function notifyOrderDelivered(
  e: Payload & { courierUserId: number },
  result: {
    customerBadgeUpdate: Awaited<
      ReturnType<typeof updateBadgeFromDeliveredCount>
    > | null;
    courierBadgeUpdate: Awaited<
      ReturnType<typeof updateBadgeFromDeliveredCount>
    >;
    amountDueNotice: AmountDueNotice | null;
  },
) {
  const isPartnerOrder = !!e.externalAppId;

  const [courier, customer] = await Promise.all([
    prisma.user.findUnique({
      where: { id: e.courierUserId },
      select: { id: true, fcm_token: true, lang: true },
    }),
    !isPartnerOrder && e.customerId
      ? prisma.user.findUnique({
          where: { id: e.customerId },
          select: { id: true, fcm_token: true, lang: true },
        })
      : Promise.resolve(null),
  ]);

  if (courier) {
    await notifyUser({
      user: courier,
      content: {
        titleKey: "orders:messages.order_delivered_courier_title",
        bodyKey: "orders:messages.order_delivered_courier_body",
        bodyParams: { orderId: e.orderId },
      },
      data: {
        type: "ORDER_DELIVERED",
        orderId: e.orderId,
        page: `/courier/orders/${e.orderId}`,
        navigate: "order-details",
      },
    });
  }

  if (courier && result.amountDueNotice) {
    const { isExceeded, unpaidCommissionCount, unpaidPenaltyCount } =
      result.amountDueNotice;
    await notifyUser({
      user: courier,
      content: {
        titleKey: isExceeded
          ? "orders:messages.unpaid_dues_exceeded_title"
          : "orders:messages.unpaid_dues_threshold_title",
        bodyKey: isExceeded
          ? "orders:messages.unpaid_dues_exceeded_body"
          : "orders:messages.unpaid_dues_threshold_body",
        bodyParams: {
          unpaidCommissionCount,
          unpaidPenaltyCount,
          amount: result.amountDueNotice.totalAmount.toFixed(2),
          maxAmount: result.amountDueNotice.maxAmount.toFixed(2),
          percent: Math.round(result.amountDueNotice.percent),
        },
      },
      data: {
        type: "UNPAID_COMMISSION_THRESHOLD",
        orderId: e.orderId,
        unpaidCommissionCount,
        unpaidPenaltyCount,
        unpaidAmount: result.amountDueNotice.totalAmount.toFixed(2),
        maxUnpaidAmount: result.amountDueNotice.maxAmount.toFixed(2),
        unpaidPercent: Math.round(result.amountDueNotice.percent),
        page: "/courier/unpaid-commissions",
        navigate: "unpaid-commissions",
      },
    });
  }

  await notifyAdminsExcept(
    [],
    {
      titleKey: "orders:messages.order_delivered_admin_title",
      bodyKey: "orders:messages.order_delivered_admin_body",
      bodyParams: { orderId: e.orderId },
    },
    {
      type: "ORDER_DELIVERED",
      orderId: e.orderId,
      page: `/admin/orders/${e.orderId}`,
      navigate: "admin-order-details",
    },
  );

  if (result.customerBadgeUpdate?.changed && customer) {
    await notifyBadgeUpgrade(
      customer,
      result.customerBadgeUpdate.currentBadge?.name ?? undefined,
      result.customerBadgeUpdate.currentBadge?.name_ar ?? undefined,
      result.customerBadgeUpdate.currentBadge?.id ?? undefined,
      "/profile",
    );
  }

  if (result.courierBadgeUpdate?.changed && courier) {
    await notifyBadgeUpgrade(
      courier,
      result.courierBadgeUpdate.currentBadge?.name ?? undefined,
      result.courierBadgeUpdate.currentBadge?.name_ar ?? undefined,
      result.courierBadgeUpdate.currentBadge?.id ?? undefined,
      "/courier/profile",
    );
  }
}

// ─── Entry point ──────────────────────────────────────────────────────────────
// ============================ onOrderDelivered ============================
export async function onOrderDelivered(e: Payload) {
  const isPartnerOrder = !!e.externalAppId;

  // step: send socket to courier
  getIo()
    .to(rooms.courier(e.courierId))
    .emit("order:delivery_confirmed_customer", {
      orderId: e.orderId,
    });

  if (e.customerId) {
    getIo().to(rooms.customer(e.customerId)).emit("order:tracking_ended", {
      orderId: e.orderId,
      reason: "DELIVERED",
    });
  }

  // step: send notification to supplier
  if (e.type === "CATALOG_PURCHASE" && e.supplierId) {
    await notifySupplierOrder(e.supplierId, e.orderId, "ORDER_DELIVERED");
  }

  // step: prisma block
  const result = await prisma.$transaction(async (tx) => {
    // step: check order existence
    const order = await tx.order.findUnique({
      where: { id: e.orderId },
      select: {
        id: true,
        status: true,
        order_number: true,
        courier: {
          select: {
            user_id: true,
            // Point 6: fetch vehicle.total_fines from the courier's assigned vehicle
            // instead of applicationSetting.total_fines
            vehicle: { select: { total_fines: true } },
          },
        },
        externalApp: {
          select: {
            webhook_url: true,
            webhook_secret: true,
          },
        },
      },
    });
    if (order?.status !== "DELIVERED") return null;

    // step: check courier existence
    const courierUserId = order.courier?.user_id;
    if (!courierUserId)
      throw new HttpError(404, "orders:errors.courier_not_found");

    // Point 6: resolve vehicle total_fines from the courier's vehicle;
    // fall back to 0 if the courier has no vehicle assigned
    const vehicleTotalFines = order.courier?.vehicle?.total_fines
      ? new Prisma.Decimal(order.courier.vehicle.total_fines)
      : new Prisma.Decimal(0);
    // step: get payload
    const payload = { ...e, courierUserId };

    // step1: get courier wallet
    const courierWallet = await ensureWallet(tx, courierUserId, "COURIER");

    let amountDueNotice: AmountDueNotice | null = null;

    if (isPartnerOrder) {
      if (e.paymentMethod === "WALLET") {
        await handlePartnerWalletDelivery(tx, payload, order.id);
      } else {
        amountDueNotice = await handlePartnerCashDelivery(
          tx,
          payload,
          order.id,
          new Prisma.Decimal(courierWallet.balance),
          vehicleTotalFines,
        );
      }
      if (order.externalApp?.webhook_url && order.externalApp?.webhook_secret) {
        await sendWebhookEvent<WebhookOrderDeliveredPayload>(e.externalAppId!, {
          webhookUrl: order.externalApp.webhook_url,
          webhookSecret: order.externalApp.webhook_secret,
          eventType: "ORDER_DELIVERED",
          payload: {
            id: order.id,
            status: "DELIVERED",
            delivered_at: new Date().toISOString(),
            courier_fee: +e.courierFeeCents,
            platform_fee: +e.platformFeeCents,
            partner_fee: e.partnerFeeCents ? +e.partnerFeeCents : 0,
            total_fee: +e.totalFeeCents,
            order_number: order.order_number,
          },
        });
      }
    } else {
      // step: get customer wallet and platform fee
      const customerWallet = await ensureWallet(tx, e.customerId!, "CUSTOMER");
      console.log(customerWallet, "customerWallet in order delivered event");
      console.log("e.customerId!", e.customerId!);
      const grossPlatformFee = +e.platformFeeCents;
      let platformFeeNumber = grossPlatformFee - (e.discountCents ?? 0);
      console.log("grossPlatformFee:", grossPlatformFee);
      console.log("e.discountCents:", e.discountCents);
      console.log("platformFeeNumber:", platformFeeNumber);

      if (e.paymentMethod === "WALLET" || e.paymentMethod === "CARD") {
        await handleCustomerWalletPayment(
          tx,
          payload,
          order.id,
          customerWallet.id,
          platformFeeNumber,
        );
      } else {
        amountDueNotice = await handleCustomerCashPayment(
          tx,
          payload,
          order.id,
          new Prisma.Decimal(courierWallet.balance),
          platformFeeNumber,
          vehicleTotalFines,
        );
      }

      // Customer badge + points
      const customerBadgeUpdate = await updateBadgeFromDeliveredCount(tx, {
        kind: "CUSTOMER",
        userId: e.customerId!,
      });
      await calcRewardPointsFromBadge(tx, e.customerId!, +e.paymentAmountCents);

      const courierBadgeUpdate = await updateBadgeFromDeliveredCount(tx, {
        kind: "COURIER",
        courierId: e.courierId,
      });

      return {
        customerBadgeUpdate,
        courierBadgeUpdate,
        amountDueNotice,
        payload,
      };
    }

    // Partner path — courier badge only, no customer badge/points
    const courierBadgeUpdate = await updateBadgeFromDeliveredCount(tx, {
      kind: "COURIER",
      courierId: e.courierId,
    });

    return {
      customerBadgeUpdate: null,
      courierBadgeUpdate,
      amountDueNotice,
      payload,
    };
  });

  if (!result) return;
  await notifyOrderDelivered(result.payload, result);

  // step: delete the order's chat (messages + participants) and its
  // stored "new message" notifications now that the order is delivered
  await deleteOrderChatOnCompletion(e.orderId).catch((err) => {
    console.error(`[order.delivered] failed to clean up order chat: ${err}`);
  });
}
