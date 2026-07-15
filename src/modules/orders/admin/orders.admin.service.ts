import { logger } from "@/config/logger";
import { bus } from "@/events/bus";
import type FeatureApi from "@/lib/featureApi";
import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { Prisma } from "@prisma/client";
import type {
  AdminCancelOrderInput,
  AdminUpdateOrderInput,
  AdminUpdateProposalInput,
} from "./orders.admin.schema";
import { restoreStockIfCatalog } from "../order.utils";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { executeCardRefund } from "@/lib/cardRefund";

export async function adminListOrdersService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  const [totalOrders, orders] = await prisma.$transaction([
    prisma.order.count({ where: data.where }),
    prisma.order.findMany(data as any),
  ]);

  return {
    totalOrders,
    totalPages: Math.ceil(totalOrders / take),
    orders,
  };
}

export async function adminGetOrderByIdService(data: FeatureApi["data"]) {
  const order = await prisma.order.findUnique(data as any);

  if (!order) throw new HttpError(404, "orders:errors.order_not_found");
  return order;
}

export async function adminUpdateOrderService(
  orderId: number,
  input: AdminUpdateOrderInput,
) {
  const exists = await prisma.order.findUnique({
    where: { id: orderId },
    select: { id: true, status: true },
  });
  if (!exists) throw new HttpError(404, "orders:errors.order_not_found");

  return prisma.order.update({
    where: { id: orderId },
    data: {
      ...input,
      delivered_at: input.status === "DELIVERED" ? new Date() : undefined,
      canceled_at:
        input.status === "CANCELLED"
          ? new Date()
          : (input.cancelled_at ?? undefined),
    },
  });
}

export async function adminCancelOrderService(
  orderId: number,
  input: AdminCancelOrderInput,
  adminUserId: number,
) {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    select: { id: true, status: true },
  });
  if (!order) throw new HttpError(404, "orders:errors.order_not_found");
  if (order.status === "CANCELLED")
    throw new HttpError(409, "orders:errors.already_cancelled");

  return prisma.order.update({
    where: { id: orderId },
    data: {
      status: "CANCELLED",
      cancelled_reason: input.cancelled_reason,
      cancellation_fee: input.cancellation_fee ?? null,
      cancelled_by: input.cancelled_by ?? adminUserId,
      canceled_at: new Date(),
    },
  });
}

export async function adminListProposalsService(orderId: number) {
  // Ensure order exists
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    select: { id: true },
  });
  if (!order) throw new HttpError(404, "orders:errors.order_not_found");

  return prisma.orderProposal.findMany({
    where: { order_id: orderId },
    orderBy: { created_at: "desc" },
    include: {
      courier: { select: { id: true } as any },
      order: { select: { id: true, order_number: true, status: true } },
    },
  });
}

export async function adminUpdateProposalService(
  proposalId: number,
  input: AdminUpdateProposalInput,
) {
  const exists = await prisma.orderProposal.findUnique({
    where: { id: proposalId },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "orders:errors.proposal_not_found");

  return prisma.orderProposal.update({
    where: { id: proposalId },
    data: { status: input.status },
  });
}

export async function handleNoProposalOrders() {
  const now = new Date();

  // 1. Find orders that are still PENDING but past deadline
  const orders = await prisma.order.findMany({
    where: {
      status: "PENDING",
      proposals_deadline_at: { lt: now },
      search_failed_at: null,
      escalated_to_admin_at: null,
      failure_reason: null,
      proposals: { none: {} },
    },
    select: { id: true, customer_id: true, external_app_id: true },
  });

  if (orders.length === 0) return;

  // 2. Bulk update status to prevent the loop
  const orderIds = orders.map((o) => o.id);
  await prisma.order.updateMany({
    where: { id: { in: orderIds } },
    data: {
      search_failed_at: now,
      escalated_to_admin_at: now,
      failure_reason: "NO_PROPOSALS",
    },
  });

  // 3. Emit events ONLY after DB is updated
  for (const order of orders) {
    logger.info({ order }, "Order marked as no proposals");
    bus.emit("order.no_proposals", {
      orderId: order.id,
      detectedAt: now.toISOString(),
      customerId: order.customer_id ?? null,
      externalAppId: order.external_app_id ?? null,
    });
  }

  logger.info(`Handled ${orders.length} orders with no proposals.`);
}

// step: claude: CARD orders left unpaid for too long shouldn't lock stock forever —
// cancel them and restore stock so the customer can check out again
const PENDING_PAYMENT_TTL_MINUTES = 30;

export async function handleStalePendingPaymentOrders() {
  const cutoff = new Date(Date.now() - PENDING_PAYMENT_TTL_MINUTES * 60 * 1000);

  const orders = await prisma.order.findMany({
    where: {
      status: "PENDING_PAYMENT",
      payment_method: "CARD",
      created_at: { lt: cutoff },
    },
    select: { id: true },
  });

  if (!orders.length) return;

  for (const order of orders) {
    const pendingTx = await prisma.transaction.findFirst({
      where: { order_id: order.id, type: "ORDER_PAYMENT", status: "PENDING" },
      select: { id: true },
    });

    await prisma.$transaction(async (tx) => {
      if (pendingTx) {
        await tx.transaction.update({
          where: { id: pendingTx.id },
          data: { status: "FAILED", reject_reason: "Payment session expired" },
        });
      }
      await tx.order.update({
        where: { id: order.id },
        data: { status: "EXPIRED" },
      });
      await restoreStockIfCatalog(tx, {
        id: order.id,
        type: "CATALOG_PURCHASE",
      });
    });

    logger.info(
      { orderId: order.id },
      "[OrderCleanup] Stale PENDING_PAYMENT order cancelled, stock restored",
    );
  }

  logger.info(`Cancelled ${orders.length} stale PENDING_PAYMENT orders.`);
}

export async function handleExpiredOrders() {
  const now = new Date();

  const orders = await prisma.order.findMany({
    where: {
      status: { in: ["PENDING", "SEARCHING_FAILED"] },
      expires_at: { lt: now },
    },
    select: {
      id: true,
      customer_id: true,
      external_app_id: true,
      payment_method: true,
      pickup_area_id: true,
      coupon_id: true,
      type: true,
    },
  });

  for (const order of orders) {
    await prisma.$transaction(async (tx) => {
      if (order.payment_method === "WALLET") {
        // Resolve wallet by whichever owner is set
        const wallet = order.customer_id
          ? await tx.wallet.findUnique({
              where: { user_id: order.customer_id },
            })
          : order.external_app_id
            ? await tx.wallet.findUnique({
                where: { external_app_id: order.external_app_id },
              })
            : null;

        if (wallet) {
          const escrow = await tx.escrow.findFirst({
            where: { order_id: order.id, wallet_id: wallet.id },
          });

          if (escrow) {
            await adjustWalletBalance(tx, wallet.id, +escrow.held_amount, {
              order_id: order.id,
            });

            await tx.transaction.create({
              data: {
                wallet_id: wallet.id,
                order_id: order.id,
                escrow_id: escrow.id,
                type: "ESCROW_REMOVE",
                amount: escrow.held_amount,
                status: "COMPLETED",
                description: "Refund expired order",
              },
            });

            await tx.escrow.update({
              where: { id: escrow.id },
              data: { held_amount: new Prisma.Decimal(0) },
            });
          }
        }
      }

      await restoreStockIfCatalog(tx, order);

      await tx.order.update({
        where: { id: order.id },
        data: { status: "EXPIRED", expires_at: now },
      });

      // CARD: payable amount is stored on the order — we'll refund after the tx
      // (external API call must happen outside the DB transaction)

      if (order.coupon_id) {
        await tx.customerCouponUsage.deleteMany({
          where: {
            order_id: order.id,
            coupon_id: order.coupon_id,
            context: "ORDER",
          },
        });
      }
    });

    // ── CARD: auto-refund via provider API after expiry ───────────────────────
    if (order.payment_method === "CARD") {
      try {
        const fullOrder = await prisma.order.findUnique({
          where: { id: order.id },
          select: { payable_amount: true, order_number: true },
        });
        const amountCents = Math.round(Number(fullOrder?.payable_amount ?? 0));

        if (amountCents > 0) {
          const refundResult = await executeCardRefund(
            order.id,
            amountCents,
            `Auto-refund: no courier accepted order #${fullOrder?.order_number}`,
          );

          logger.info(
            {
              orderId: order.id,
              provider: refundResult.provider,
              refundId: refundResult.refundId,
            },
            "[ExpiredOrder] Card auto-refund succeeded",
          );
        }
      } catch (err: any) {
        // Log but don't block — order is already EXPIRED; admin can handle manually
        logger.error(
          { orderId: order.id, err: err?.message },
          "[ExpiredOrder] Card auto-refund failed — requires manual processing",
        );
      }
    }

    bus.emit("order.expired", {
      orderId: order.id,
      expiredAt: now.toISOString(),
      customerId: order.customer_id ?? null,
      externalAppId: order.external_app_id ?? null,
      pickupAreaId: +order.pickup_area_id!,
    });
  }

  if (orders.length > 0) {
    logger.info(
      `Handled ${orders.length} expired orders and processed associated refunds.`,
    );
  }
}
