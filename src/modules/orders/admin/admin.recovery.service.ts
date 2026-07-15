import { logger } from "@/config/logger";
import { bus } from "@/events/bus";
import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { Prisma } from "@prisma/client";
import type {
  AdminManualAssignInput,
  AdminRetryOrderInput,
  AdminSoftCancelInput,
} from "./orders.admin.schema";
import { selectVehiclesForDistance } from "@/lib/vehicle-selector";
import { notifyUser } from "@/services/notification.service";
import { adjustOrderEscrowToAmount } from "../order.utils";
import { getIo } from "@/socket";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// PENDING and SEARCHING_FAILED: normal stuck states.
// EXPIRED: order lifetime ran out but no courier accepted — same recovery path.
// Assign / Retry / Soft-Cancel all work for these three.
// CANCELLED, IN_PROGRESS, DELIVERED are terminal — no recovery.
const RECOVERABLE_STATUSES = ["PENDING", "SEARCHING_FAILED", "EXPIRED"] as const;

async function requireRecoverableOrder(orderId: number) {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    select: {
      id: true,
      status: true,
      order_number: true,
      customer_id: true,
      courier_id: true,
      pickup_area_id: true,
      delivery_area_id: true,
      payment_method: true,
      budget: true,
      total_fee: true,
      actual_price: true,
      estemated_delivery_fee: true,
      distance_m: true,
      vehicle_id: true,
      proposals_deadline_at: true,
      expires_at: true,
      pickup_lat: true,
      pickup_long: true,
    },
  });

  if (!order) throw new HttpError(404, "orders:errors.order_not_found");

  if (!(RECOVERABLE_STATUSES as readonly string[]).includes(order.status)) {
    throw new HttpError(409, "orders:errors.order_not_recoverable");
  }

  return order;
}

// ─────────────────────────────────────────────────────────────────────────────
// Playbook A — Manual Assignment
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Force-assigns a specific courier to a stuck order.
 * Mirrors acceptProposalService: update proposal + order in one transaction,
 * then adjustOrderEscrowToAmount for WALLET orders, then emit offer.accepted.
 */
export async function adminManualAssignService(
  orderId: number,
  input: AdminManualAssignInput,
  adminUserId: number,
) {
  const order = await requireRecoverableOrder(orderId);

  // step: get courier
  const courier = await prisma.courier.findUnique({
    where: { id: input.courier_id },
    select: { id: true, user_id: true, is_approved: true, vehicle_id: true },
  });
  if (!courier) throw new HttpError(404, "orders:errors.courier_not_found");
  if (!courier.is_approved)
    throw new HttpError(409, "orders:errors.courier_not_approved");

  // step: check if courier has active orders
  // const activeOrderCount = await prisma.order.count({
  //   where: {
  //     courier_id: courier.id,
  //     status: { in: ["PENDING", "IN_PROGRESS"] },
  //   },
  // });
  // if (activeOrderCount > 0) {
  //   throw new HttpError(
  //     409,
  //     "orders:errors.courier_has_active_orders",
  //     "COURIER_BUSY",
  //   );
  // }

  // step: get agreedTotalFee
  const agreedTotalFee = input.agreed_total_fee
    ? new Prisma.Decimal(input.agreed_total_fee)
    : (order.total_fee ?? order.budget);

  const { proposal, updatedOrder } = await prisma.$transaction(async (tx) => {
    // step: reject all lingering proposals — same as acceptProposalService
    await tx.orderProposal.updateMany({
      where: { order_id: orderId, status: "PENDING" },
      data: { status: "REJECTED" },
    });

    // step: create accepted proposal
    const proposal = await tx.orderProposal.create({
      data: {
        order_id: order.id,
        // order: { connect: { id: orderId } },
        courier_id: courier.id ?? null,
        vehicle_id: courier.vehicle_id ?? null,
        total_fee: agreedTotalFee!,
        status: "ACCEPTED",
        confirmed_at: new Date(),
      },
    });

    // step: update order
    const updatedOrder = await tx.order.update({
      where: { id: orderId },
      data: {
        status: "IN_PROGRESS",
        courier_id: courier.id,
        total_fee: agreedTotalFee,
        courier_fee: agreedTotalFee,
        offer_accepted_at: new Date(),
        assigned_by_admin_id: adminUserId,
        admin_notes: input.admin_notes,
      },
      select: {
        id: true,
        customer_id: true,
        courier_id: true,
        pickup_area_id: true,
        payment_method: true,
        total_fee: true,
        payable_amount: true,
      },
    });

    // Mirror acceptProposalService: adjust escrow to match the agreed fee
    // for WALLET orders so the held amount stays in sync
    if (updatedOrder.payment_method === "WALLET") {
      await adjustOrderEscrowToAmount(tx, {
        orderId: updatedOrder.id,
        customerId: updatedOrder.customer_id!,
        requiredAmount: agreedTotalFee!,
        reason: "manual admin assignment",
      });
    }

    return { proposal, updatedOrder };
  });

  bus.emit("offer.accepted", {
    orderId,
    offerId: proposal.id,
    courierId: courier.id,
    customerId: order.customer_id!,
    pickupAreaId: order.pickup_area_id!,
    acceptedAt: new Date().toISOString(),
  });

  logger.info(
    `[Playbook A] Order #${orderId} manually assigned to courier #${courier.id} by admin #${adminUserId}.`,
  );

  return { proposal, order: updatedOrder };
}

// ─────────────────────────────────────────────────────────────────────────────
// Playbook A — Manual Assignment (v2)
// ─────────────────────────────────────────────────────────────────────────────
export async function adminManualAssignServiceV2(
  orderId: number,
  input: AdminManualAssignInput,
  adminUserId: number,
) {
  // step: get courier
  const courier = await prisma.courier.findUnique({
    where: { id: input.courier_id },
    select: { id: true, user_id: true, is_approved: true, vehicle_id: true },
  });
  if (!courier) throw new HttpError(404, "orders:errors.courier_not_found");
  if (!courier.is_approved)
    throw new HttpError(409, "orders:errors.courier_not_approved");

  // step: get user
  const user = await prisma.user.findUnique({
    where: { id: courier.user_id },
    select: { id: true, fcm_token: true, lang: true },
  });
  if (!user) throw new HttpError(404, "auth:errors.user_not_found");

  // step: notify courier
  await notifyUser({
    user: {
      id: courier.user_id,
      lang: user.lang,
      fcm_token: user.fcm_token,
    },
    content: {
      title: {
        en: "New assignment.",
        ar: "تكليف جديد",
      },
      body: {
        en: `You have been assigned to deliver this order.`,
        ar: `تم تكليفك بتسليم هذا الطلب`,
      },
    },
    data: {
      page: `/orders/${orderId}`,
      navigate: "order_details",
      orderId,
      type: "ORDER_MANUAL_ASSIGN",
      adminUserId,
    },
  });

  // step: emit socket to courier
  getIo().emit("order:manual.assign", { orderId, courierId: courier.id });

  return { courier };
}

// ─────────────────────────────────────────────────────────────────────────────
// Playbook B — Market Re-entry (Retry)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Restarts the bidding clock, optionally with a higher fee.
 * Re-emits order.created so the existing broadcasting job picks it up —
 * no new infrastructure needed.
 */
export async function adminRetryOrderService(
  orderId: number,
  input: AdminRetryOrderInput,
  adminUserId: number,
) {
  const order = await requireRecoverableOrder(orderId);
  const settings = await prisma.applicationSetting.findFirst({
    select: {
      proposal_waiting_time_minutes: true,
      order_expiration_time_minutes: true,
    },
  });

  const vehicles = await selectVehiclesForDistance(
    Number(order.distance_m ?? 0),
  );

  const now = new Date();
  const newDeadline = new Date(
    now.getTime() +
      (input.deadline_extension_minutes ||
        settings?.proposal_waiting_time_minutes ||
        5) *
        60_000,
  );

  const newExpiry = new Date(
    now.getTime() +
      (input.expiry_extension_minutes ||
        settings?.order_expiration_time_minutes ||
        15) *
        60_000,
  );

  const newFee = input.new_delivery_fee
    ? new Prisma.Decimal(input.new_delivery_fee)
    : undefined;

  await prisma.$transaction(async (tx) => {
    await tx.orderProposal.updateMany({
      where: { order_id: orderId, status: "PENDING" },
      data: { status: "REJECTED" },
    });

    await tx.order.update({
      where: { id: orderId },
      data: {
        status: "PENDING",
        proposals_deadline_at: newDeadline,
        expires_at: newExpiry,
        search_failed_at: null,
        failure_reason: null,
        escalated_to_admin_at: null,
        assigned_by_admin_id: adminUserId,
        admin_notes: input.admin_notes,
        retry_count: { increment: 1 },
        last_escalated_at: now,

        // Snapshot old fee for audit before overriding
        ...(newFee && {
          original_delivery_fee: order.estemated_delivery_fee ?? order.budget,
          estemated_delivery_fee: newFee,
        }),
      },
    });
  });

  bus.emit("order.created", {
    orderId,
    customerId: order.customer_id!,
    createdAt: now.toISOString(),
    deliveryAreaId: order.delivery_area_id!,
    pickupAreaId: order.pickup_area_id!,
    budget:
      input.new_delivery_fee ??
      Number(order.estemated_delivery_fee ?? order.budget),
    vehicleIds: vehicles.map((v) => v.id),
    distanceM: Number(order.distance_m ?? 0),
    proposalsDeadline: newDeadline.toISOString(),
    expiresAt: newExpiry.toISOString(),
    type: "CUSTOM_PICKUP",
    pickupLat: +order.pickup_lat!,
    pickupLng: +order.pickup_long!,
  });

  logger.info(
    `[Playbook B] Order #${orderId} retried by admin #${adminUserId}. ` +
      `New deadline: ${newDeadline.toISOString()}, fee: ${newFee ?? "unchanged"}.`,
  );

  return { orderId, newDeadline, newExpiry, newFee };
}

// ─────────────────────────────────────────────────────────────────────────────
// Playbook C — Soft Cancellation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Cancels a stuck order with "NO_COURIERS_AVAILABLE" and refunds the customer.
 *
 * Uses adjustOrderEscrowToAmount(requiredAmount = cancellationFee) to handle
 * all wallet/escrow/transaction writes — identical to how cancelOrderService
 * settles escrow on a customer-initiated cancel.
 *
 * The math works out as:
 *   held_amount shrinks to exactly cancellationFee
 *   → surplus (held - fee) is credited back to wallet balance
 *   → an ESCROW_REMOVE transaction row is written automatically
 *
 * If cancellationFee is 0 the escrow drops to 0 → full refund.
 * For CASH orders the helper short-circuits (skipped: true), nothing to refund.
 */
export async function adminSoftCancelService(
  orderId: number,
  input: AdminSoftCancelInput,
  adminUserId: number,
) {
  const order = await requireRecoverableOrder(orderId);

  const now = new Date();
  const cancellationFee = new Prisma.Decimal(input.cancellation_fee ?? 0);

  await prisma.$transaction(async (tx) => {
    await tx.orderProposal.updateMany({
      where: { order_id: orderId, status: "PENDING" },
      data: { status: "REJECTED" },
    });

    if (order.payment_method === "WALLET") {
      const wallet = await tx.wallet.findUnique({
        where: { user_id: order.customer_id! },
        select: { id: true, balance: true, status: true },
      });

      if (!wallet) throw new HttpError(404, "wallet:errors.not_found");
      if (wallet.status !== "ACTIVE")
        throw new HttpError(409, "wallet:errors.wallet_not_active");

      const escrow = await tx.escrow.findFirst({
        where: { order_id: orderId, wallet_id: wallet.id },
        orderBy: { created_at: "desc" },
      });

      if (!escrow) throw new HttpError(500, "orders:errors.escrow_missing");

      const held = new Prisma.Decimal(escrow.held_amount);
      const refund = held.sub(cancellationFee);

      if (refund.gt(0)) {
        // Return surplus to wallet
        await adjustWalletBalance(tx, wallet.id, refund.toNumber(), { order_id: orderId });

        await tx.transaction.create({
          data: {
            wallet_id: wallet.id,
            order_id: orderId,
            escrow_id: escrow.id,
            type: "ESCROW_REMOVE",
            status: "COMPLETED",
            amount: refund,
            description: `Refund for cancelled order #${orderId}`,
          },
        });
      }

      // Zero out escrow — order is done
      await tx.escrow.update({
        where: { id: escrow.id },
        data: { held_amount: new Prisma.Decimal(0) },
      });

      // Record the cancellation fee as a penalty if applicable
      if (cancellationFee.gt(0)) {
        await tx.penalty.create({
          data: {
            user_id: order.customer_id!,
            amount: cancellationFee,
            reason: `Cancellation fee for order #${orderId}`,
            is_paid: true,
            paid_at: now,
          },
        });

        await tx.transaction.create({
          data: {
            wallet_id: wallet.id,
            order_id: orderId,
            escrow_id: escrow.id,
            type: "PENALTY",
            status: "COMPLETED",
            amount: cancellationFee,
            description: `Cancellation fee for order #${orderId}`,
          },
        });
      }
    }

    await tx.order.update({
      where: { id: orderId },
      data: {
        status: "CANCELLED",
        cancelled_reason: "NO_COURIERS_AVAILABLE",
        cancellation_fee: cancellationFee.gt(0) ? cancellationFee : null,
        cancelled_by: adminUserId,
        canceled_at: now,
        assigned_by_admin_id: adminUserId,
        admin_notes: input.admin_notes,
      },
    });
  });

  bus.emit("order.cancelled", {
    orderId,
    customerId: order.customer_id!,
    courierId: order.courier_id ?? null,
    pickupAreaId: order.pickup_area_id!,
    cancelledAt: now.toISOString(),
    type: "CUSTOM_PICKUP",
  });

  // Notify the customer their order was cancelled and (if applicable) refunded
  const customer = await prisma.user.findUnique({
    where: { id: order.customer_id! },
    select: { id: true, lang: true, fcm_token: true },
  });

  if (customer) {
    await notifyUser({
      user: customer,
      content: {
        titleKey: "orders:messages.soft_cancel_customer.title",
        bodyKey: "orders:messages.soft_cancel_customer.body",
        bodyParams: { orderId },
      },
      data: {
        orderId,
        page: `/orders/${orderId}`,
        type: "soft_cancel_customer",
      },
    });
  }

  logger.info(
    `[Playbook C] Order #${orderId} soft-cancelled by admin #${adminUserId}. ` +
      `Cancellation fee: ${cancellationFee}.`,
  );

  return { orderId, cancelledAt: now };
}

export async function resolveOrderIssueService(
  issueId: number,
  adminId: number,
  status: "RESOLVED" | "DISMISSED",
  note?: string,
) {
  const issue = await prisma.orderIssue.findUnique({
    where: { id: issueId },
  });

  if (!issue) {
    throw new HttpError(404, "order_issue.not_found");
  }

  const updated = await prisma.orderIssue.update({
    where: { id: issueId },
    data: {
      status,
      resolved_by: adminId,
      resolved_at: new Date(),
      resolution_note: note,
    },
  });

  bus.emit("order.issue.resolved", {
    orderId: issue.order_id,
    issueId,
    status,
    resolutionNote: note,
    resolvedAt: updated.resolved_at!,
  });

  return updated;
}

async function orderIssue(orderId: number) {
  const issue = await prisma.orderIssue.findFirst({
    where: {
      order_id: orderId,
      status: { in: ["OPEN", "UNDER_REVIEW"] },
    },
    select: { id: true },
  });

  if (!issue) {
    throw new HttpError(404, "orders:errors.issue_not_found");
  }

  return issue;
}

export async function adminManualAssignFixedService(
  orderId: number,
  input: {
    courier_id: number;
    admin_notes?: string;
  },
  adminUserId: number,
) {
  const [order, courier, settings, issue] = await Promise.all([
    requireRecoverableOrder(orderId),
    prisma.courier.findUnique({
      where: { id: input.courier_id },
      select: { id: true, user_id: true, is_approved: true, vehicle_id: true },
    }),
    prisma.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
      },
    }),
    await orderIssue(orderId),
  ]);

  if (!courier) throw new HttpError(404, "orders:errors.courier_not_found");
  if (!courier.is_approved)
    throw new HttpError(409, "orders:errors.courier_not_approved");

  const activeOrderCount = await prisma.order.count({
    where: {
      courier_id: courier.id,
      status: { in: ["PENDING", "IN_PROGRESS"] },
    },
  });

  if (activeOrderCount > 0) {
    throw new HttpError(
      409,
      "orders:errors.courier_has_active_orders",
      "COURIER_BUSY",
    );
  }

  const now = new Date();
  const newDeadline = new Date(
    now.getTime() + (settings?.proposal_waiting_time_minutes || 5) * 60_000,
  );

  const newExpiry = new Date(
    now.getTime() + (settings?.order_expiration_time_minutes || 15) * 60_000,
  );

  await prisma.$transaction([
    prisma.orderIssue.update({
      where: { id: issue.id },
      data: {
        status: "RESOLVED",
        resolved_by: adminUserId,
        resolved_at: new Date(),
        resolution_note: "Manual fixed assignment applied",
      },
    }),
    prisma.order.update({
      where: { id: orderId },
      data: {
        status: "PENDING",
        proposals_deadline_at: newDeadline,
        expires_at: newExpiry,
        // 🔥 KEY
        is_fixed_fee: true,

        assigned_by_admin_id: adminUserId,
        admin_notes: input.admin_notes,
        retry_count: { increment: 1 },
        last_escalated_at: now,
      },
    }),
  ]);

  // 🔥 Send ONLY to selected courier
  bus.emit("order.created", {
    orderId,
    customerId: order.customer_id!,
    createdAt: now.toISOString(),
    budget: +order.budget!,
    expiresAt: newExpiry.toISOString(),
    proposalsDeadline: newDeadline.toISOString(),
    vehicleIds: order.vehicle_id ? [order.vehicle_id] : [],
    pickupAreaId: order.pickup_area_id!,
    deliveryAreaId: order.delivery_area_id!,

    distanceM: Number(order.distance_m ?? 0),

    mode: "FIXED_FEE",
    total_fee: Number(order.total_fee),
    type: "CUSTOM_PICKUP",
    targetCourierId: input.courier_id, // 🔥 important
    pickupLat: +order.pickup_lat!,
    pickupLng: +order.pickup_long!,
  });

  return { success: true };
}

export async function adminBroadcastFixedService(
  orderId: number,
  input: {
    admin_notes?: string;
  },
  adminUserId: number,
) {
  const [order, settings, issue] = await Promise.all([
    requireRecoverableOrder(orderId),
    prisma.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
      },
    }),
    await orderIssue(orderId),
  ]);
  const now = new Date();
  const newDeadline = new Date(
    now.getTime() + (settings?.proposal_waiting_time_minutes || 5) * 60_000,
  );

  const newExpiry = new Date(
    now.getTime() + (settings?.order_expiration_time_minutes || 15) * 60_000,
  );

  const vehicles = await selectVehiclesForDistance(
    Number(order.distance_m ?? 0),
  );

  await prisma.$transaction([
    prisma.orderIssue.update({
      where: { id: issue.id },
      data: {
        status: "RESOLVED",
        resolved_by: adminUserId,
        resolved_at: new Date(),
        resolution_note: "Manual fixed assignment applied",
      },
    }),
    prisma.order.update({
      where: { id: orderId },
      data: {
        status: "PENDING",
        proposals_deadline_at: newDeadline,
        expires_at: newExpiry,
        // 🔥 KEY
        is_fixed_fee: true,

        assigned_by_admin_id: adminUserId,
        admin_notes: input.admin_notes,
        retry_count: { increment: 1 },
        last_escalated_at: now,
      },
    }),
  ]);

  // 🔥 Same as create order
  bus.emit("order.created", {
    orderId,
    customerId: order.customer_id!,
    createdAt: now.toISOString(),
    budget: +order.budget!,
    expiresAt: newExpiry.toISOString(),
    proposalsDeadline: newDeadline.toISOString(),
    vehicleIds: vehicles.map((v) => v.id),
    pickupAreaId: order.pickup_area_id!,
    deliveryAreaId: order.delivery_area_id!,

    distanceM: Number(order.distance_m ?? 0),
    type: "CUSTOM_PICKUP",
    mode: "FIXED_FEE",
    total_fee: Number(order.total_fee),
    pickupLat: +order.pickup_lat!,
    pickupLng: +order.pickup_long!,
  });

  return { orderId, newDeadline, newExpiry };
}
