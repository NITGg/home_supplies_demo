import { prisma } from "@/config/prisma";
import { logger } from "@/config/logger";
import { broadcastToCouriers } from "@/events/handlers/orderCreated";
import type { AppEvents } from "@/types/events";
import { bus } from "@/events/bus";

export async function handleScheduledOrders() {
  const now = new Date();

  // Find all orders whose scheduled time has arrived
  const orders = await prisma.order.findMany({
    where: {
      status: "SCHEDULED",
      is_order_scheduled: true,
      order_schedule_at: { lte: now },
    },
    select: {
      id: true,
      customer_id: true,
      external_app_id: true,
      pickup_area_id: true,
      delivery_area_id: true,
      budget: true,
      distance_m: true,
      type: true,
      supplier_id: true,
      is_fixed_fee: true,
      pickup_lat: true,
      pickup_long: true,
      proposals_deadline_at: true,
      expires_at: true,
    },
  });

  if (orders.length === 0) return;

  for (const order of orders) {
    try {
      // 1. Change status SCHEDULED → PENDING
      await prisma.order.update({
        where: { id: order.id },
        data: { status: "PENDING" },
      });

      // 2. Broadcast to couriers directly
      const e: AppEvents["order.created"] = {
        orderId: order.id,
        deliveryAreaId: order.delivery_area_id!,
        createdAt: now.toISOString(),
        customerId: order.customer_id ?? undefined,
        budget: Number(order.budget ?? 0),
        pickupAreaId: order.pickup_area_id!,
        vehicleIds: [],
        distanceM: Number(order.distance_m ?? 0),
        proposalsDeadline: order.proposals_deadline_at!.toISOString(),
        expiresAt: order.expires_at!.toISOString(),
        type: order.type,
        supplierId: order.supplier_id ?? undefined,
        isFixedFee: order.is_fixed_fee,
        pickupLat: Number(order.pickup_lat ?? 0),
        pickupLng: Number(order.pickup_long ?? 0),
        externalAppId: order.external_app_id ?? undefined,
      };

      const { vehicleIds, distanceM, targetCourierId, ...courierPayload } = e;
      await broadcastToCouriers(e, courierPayload);

      // 3. Emit scheduled_activated event
      bus.emit("order.scheduled_activated", {
        orderId: order.id,
        activatedAt: now,
      });

      logger.info(
        { orderId: order.id },
        "Scheduled order activated → PENDING",
      );
    } catch (error) {
      logger.error(
        { error, orderId: order.id },
        "Failed to activate scheduled order",
      );
    }
  }

  logger.info(`Activated ${orders.length} scheduled order(s).`);
}
