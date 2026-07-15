import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { Prisma } from "@prisma/client";
import { bus } from "@/events/bus";
import { logger } from "@/config/logger";
import type { TransactionCallback } from "@/types/paymob.types";
import type { KashierWebhookPayload } from "@/types/kashier.types";
import type { EasykashCallbackPayload } from "@/types/easykash.types";
import { sendWebhookEvent } from "@/queues/webhook/webhook.service";
import type { WebhookOrderPaymentConfirmedPayload } from "@/queues/webhook/webhook.types";

// ─── Types ────────────────────────────────────────────────────────────────────

interface ActivateMeta {
  paymobTransactionId?: string;
  kashierOrderId?: string;
  easykashRef?: string;
}

type ExistingTransaction = {
  id: number;
  amount: Prisma.Decimal;
  status: string;
  order_id: number | null;
};

// ─── Shared: load transaction + guard already-applied / idempotency ───────────

async function loadTransaction(
  where: Prisma.TransactionWhereInput,
): Promise<ExistingTransaction> {
  const tx = await prisma.transaction.findFirst({
    where,
    select: { id: true, amount: true, status: true, order_id: true },
  });
  if (!tx) throw new HttpError(404, "orders:errors.payment_not_found");
  return tx;
}

type AlreadyApplied = { alreadyApplied: true; transactionId: number };

function isAlreadyCompleted(tx: ExistingTransaction): AlreadyApplied | null {
  if (tx.status !== "COMPLETED") return null;
  return { alreadyApplied: true, transactionId: tx.id };
}

// ─── Shared: cancel order + restore stock on payment failure ──────────────────

async function cancelOrderAndRestoreStock(
  orderId: number,
  transactionId: number,
  reason: string,
) {
  const items = await prisma.orderItem.findMany({
    where: { order_id: orderId },
    select: { sp_id: true, quantity: true },
  });

  await prisma.$transaction([
    prisma.transaction.update({
      where: { id: transactionId },
      data: { status: "FAILED", reject_reason: reason.slice(0, 255) },
    }),
    prisma.order.update({
      where: { id: orderId },
      data: { status: "CANCELLED" },
    }),
    ...items.map((item) =>
      prisma.supplierProduct.update({
        where: { id: item.sp_id },
        data: { stock: { increment: item.quantity } },
      }),
    ),
  ]);

  logger.info(
    { orderId, transactionId, itemCount: items.length },
    "[OrderPayment] Payment failed — order cancelled, stock restored",
  );
}

async function failTransaction(
  tx: ExistingTransaction,
  reason: string,
): Promise<never> {
  if (tx.order_id) {
    await cancelOrderAndRestoreStock(tx.order_id, tx.id, reason);
  }
  throw new HttpError(409, "orders:errors.payment_not_successful");
}

// ─── Shared: activate order after confirmed payment ───────────────────────────

async function activateOrder(
  tx: ExistingTransaction,
  amountCents: number,
  meta?: ActivateMeta,
) {
  if (!tx?.order_id) throw new HttpError(404, "orders:errors.not_found");

  if (tx.status === "COMPLETED") {
    return { alreadyApplied: true as const, transactionId: tx.id };
  }

  const order = await prisma.order.findUnique({
    where: { id: tx.order_id },
    select: {
      id: true,
      status: true,
      order_number: true,
      is_order_scheduled: true,
      delivery_area_id: true,
      customer_id: true,
      products_total: true,
      payable_amount: true,
      cart_id: true,
      pickup_area_id: true,
      pickup_lat: true,
      pickup_long: true,
      is_scheduled: true,
      total_fee: true,
      supplier_id: true,
      proposals_deadline_at: true,
      expires_at: true,
      vehicle_id: true,
      distance_m: true,
      budget: true,
      type: true,
      external_app_id: true,
      is_fixed_fee: true,
    },
  });

  if (!order) throw new HttpError(404, "orders:errors.not_found");

  const expectedAmountCents = Math.round(
    new Prisma.Decimal(tx.amount).toNumber(),
  );
  if (amountCents !== expectedAmountCents) {
    throw new HttpError(409, "orders:errors.payment_amount_mismatch");
  }

  const targetStatus = order.is_order_scheduled ? "SCHEDULED" : "PENDING";

  // ── Partner (CUSTOM_PICKUP) order: no customer wallet escrow involved ──────
  if (order.customer_id === null) {
    const [updatedTx, updatedOrder] = await prisma.$transaction([
      prisma.transaction.update({
        where: { id: tx.id },
        data: {
          status: "COMPLETED",
          ...(meta?.paymobTransactionId
            ? { paymob_transaction_id: meta.paymobTransactionId }
            : {}),
          ...(meta?.kashierOrderId
            ? { kashier_order_id: meta.kashierOrderId }
            : {}),
          ...(meta?.easykashRef ? { easykash_ref: meta.easykashRef } : {}),
        },
        select: { id: true, status: true },
      }),
      prisma.order.update({
        where: { id: order.id },
        data: { status: targetStatus },
        select: { id: true, status: true, order_number: true },
      }),
    ]);

    logger.info(
      { orderId: order.id, transactionId: tx.id },
      "[OrderPayment] Partner payment confirmed, order activated",
    );

    if (targetStatus === "PENDING") {
      bus.emit("order.created", {
        orderId: order.id,
        deliveryAreaId: order.delivery_area_id!,
        createdAt: new Date().toISOString(),
        externalAppId: order.external_app_id!,
        budget: +order.budget!,
        pickupAreaId: order.pickup_area_id!,
        vehicleIds: order.vehicle_id ? [order.vehicle_id] : [],
        distanceM: Number(order.distance_m ?? 0),
        proposalsDeadline:
          order.proposals_deadline_at?.toISOString() ??
          new Date().toISOString(),
        expiresAt: order.expires_at?.toISOString() ?? new Date().toISOString(),
        type: "CUSTOM_PICKUP" as const,
        pickupLat: Number(order.pickup_lat ?? 0),
        pickupLng: Number(order.pickup_long ?? 0),
        isFixedFee: order.is_fixed_fee,
      });
    }

    if (order.external_app_id) {
      const externalApp = await prisma.externalApp.findUnique({
        where: { id: order.external_app_id },
        select: { id: true, webhook_url: true, webhook_secret: true },
      });

      if (externalApp?.webhook_url && externalApp?.webhook_secret) {
        const provider = meta?.paymobTransactionId
          ? ("paymob" as const)
          : meta?.kashierOrderId
            ? ("kashier" as const)
            : ("easykash" as const);

        await sendWebhookEvent<WebhookOrderPaymentConfirmedPayload>(
          externalApp.id,
          {
            eventType: "ORDER_PAYMENT_CONFIRMED",
            webhookUrl: externalApp.webhook_url,
            webhookSecret: externalApp.webhook_secret,
            payload: {
              id: order.id,
              order_number: updatedOrder.order_number,
              status: targetStatus,
              payable_amount: Number(order.payable_amount ?? 0),
              provider,
              paid_at: new Date().toISOString(),
            },
          },
        );
      }
    }

    return {
      alreadyApplied: false as const,
      transaction: updatedTx,
      order: updatedOrder,
    };
  }

  const { updatedTx, updatedOrder, escrow } = await prisma.$transaction(
    async (txClient) => {
      const customerWallet = await txClient.wallet.findUnique({
        where: { user_id: order.customer_id! },
        select: { id: true },
      });
      if (!customerWallet)
        throw new HttpError(404, "orders:errors.customer_wallet_not_found");

      const escrow = await txClient.escrow.create({
        data: {
          order_id: tx.order_id!,
          wallet_id: customerWallet.id,
          held_amount: amountCents,
        },
      });

      // Single transaction record for the card payment — linked to the
      // wallet and escrow it funds, instead of a separate CARD_PAYMENT_RECEIVED row.
      const updatedTx = await txClient.transaction.update({
        where: { id: tx.id },
        data: {
          status: "COMPLETED",
          wallet_id: customerWallet.id,
          escrow_id: escrow.id,
          ...(meta?.paymobTransactionId
            ? { paymob_transaction_id: meta.paymobTransactionId }
            : {}),
          ...(meta?.kashierOrderId
            ? { kashier_order_id: meta.kashierOrderId }
            : {}),
          ...(meta?.easykashRef ? { easykash_ref: meta.easykashRef } : {}),
        },
        select: { id: true, status: true },
      });

      const updatedOrder = await txClient.order.update({
        where: { id: order.id },
        data: { status: targetStatus },
        select: { id: true, status: true, order_number: true },
      });

      if (order.cart_id) {
        await txClient.cartItem.deleteMany({
          where: { cart_id: order.cart_id },
        });
        await txClient.cart.update({
          where: { id: order.cart_id },
          data: { total_price: 0 },
        });
      }

      return { updatedTx, updatedOrder, escrow };
    },
  );

  logger.info(
    { orderId: order.id, transactionId: tx.id, escrow },
    "[OrderPayment] Payment confirmed, order activated",
  );

  if (targetStatus === "PENDING") {
    bus.emit("order.created", {
      orderId: order.id,
      deliveryAreaId: order.delivery_area_id!,
      createdAt: new Date().toISOString(),
      customerId: order.customer_id!,
      budget: Number(order.products_total ?? 0),
      pickupAreaId: order.pickup_area_id!,
      vehicleIds: order.vehicle_id ? [order.vehicle_id] : [],
      distanceM: Number(order.distance_m ?? 0),
      proposalsDeadline:
        order.proposals_deadline_at?.toISOString() ?? new Date().toISOString(),
      expiresAt:
        order.proposals_deadline_at?.toISOString() ?? new Date().toISOString(),
      mode: "FIXED_FEE" as const,
      total_fee: Number(order.total_fee ?? 0),
      type: "CATALOG_PURCHASE" as const,
      supplierId: order.supplier_id ?? 0,
      isFixedFee: true,
      pickupLat: Number(order.pickup_lat ?? 0),
      pickupLng: Number(order.pickup_long ?? 0),
      isScheduled: order.is_scheduled,
    });
  }

  return {
    alreadyApplied: false as const,
    transaction: updatedTx,
    order: updatedOrder,
  };
}

// ─── Paymob ───────────────────────────────────────────────────────────────────

export async function handlePaymobOrderPayment(body: TransactionCallback) {
  const paymobTx = body.obj;
  const paymobOrderId = String(paymobTx.order?.id ?? "");
  if (!paymobOrderId)
    throw new HttpError(400, "orders:errors.payment_verify_failed");

  const existing = await loadTransaction({
    paymob_order_id: paymobOrderId,
    type: "ORDER_PAYMENT",
  });
  const done = isAlreadyCompleted(existing);
  if (done) return done;

  const successful =
    paymobTx.success === true &&
    paymobTx.pending === false &&
    paymobTx.is_refunded === false &&
    paymobTx.is_voided === false;

  if (!successful)
    return failTransaction(existing, "Paymob transaction not successful");

  return activateOrder(existing, Number(paymobTx.amount_cents ?? 0), {
    paymobTransactionId: String(paymobTx.id),
  });
}

// ─── Kashier ──────────────────────────────────────────────────────────────────

export async function handleKashierOrderPayment(
  payload: KashierWebhookPayload,
  transactionId: number,
) {
  const { data } = payload;

  const existing = await loadTransaction({ id: transactionId });
  const done = isAlreadyCompleted(existing);
  if (done) return done;

  if (data.status !== "SUCCESS") {
    return failTransaction(existing, `Kashier status: ${data.status}`);
  }

  return activateOrder(existing, Math.round(Number(data.amount) * 100), {
    kashierOrderId: data.kashierOrderId,
  });
}

// ─── EasyKash ─────────────────────────────────────────────────────────────────

export async function handleEasykashOrderPayment(
  payload: EasykashCallbackPayload & { Amount: string },
) {
  const transactionId = Number(payload.customerReference);
  if (!transactionId || Number.isNaN(transactionId)) {
    throw new HttpError(400, "orders:errors.payment_verify_failed");
  }

  const existing = await loadTransaction({ id: transactionId });
  const done = isAlreadyCompleted(existing);
  if (done) return done;

  if (payload.status !== "PAID") {
    return failTransaction(existing, `EasyKash status: ${payload.status}`);
  }

  return activateOrder(existing, Math.round(Number(payload.Amount) * 100), {
    easykashRef: payload.easykashRef,
  });
}
