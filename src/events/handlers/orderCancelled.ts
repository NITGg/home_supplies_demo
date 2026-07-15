import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";
import type { AppEvents } from "@/types/events";
import { prisma } from "@/config/prisma";
import { notifyUser } from "@/services/notification.service";
import { notifySupplierOrder } from "./notifySupplier";
import { deleteOrderChatOnCompletion } from "@/modules/orders/services/orders.chat.service";

type Payload = AppEvents["order.cancelled"];

export async function onOrderCancelled(e: Payload) {
  // Broadcast to the pickup area room (other couriers stop seeing the order)
  getIo().to(rooms.area(e.pickupAreaId)).emit("order:cancelled", {
    orderId: e.orderId,
  });
  if (e.customerId) {
    getIo().to(rooms.customer(e.customerId)).emit("order:tracking_ended", {
      orderId: e.orderId,
      reason: "CANCELLED",
    });
  }

  // Notify assigned courier if any
  if (e.courierId) {
    getIo().to(rooms.courier(e.courierId)).emit("order:cancelled", {
      orderId: e.orderId,
    });
    await notifyCourierOrderCancelled(e.courierId, e.orderId);
  }

  // Notify supplier (CATALOG_PURCHASE only)
  if (e.type === "CATALOG_PURCHASE" && e.supplierId) {
    await notifySupplierOrder(e.supplierId, e.orderId, "ORDER_CANCELLED");
  }

  // step: delete the order's chat (messages + participants) and its
  // stored "new message" notifications now that the order is cancelled
  await deleteOrderChatOnCompletion(e.orderId).catch((err) => {
    console.error(`[order.cancelled] failed to clean up order chat: ${err}`);
  });
}

// ─── Courier ─────────────────────────────────────────────────────────────────

async function notifyCourierOrderCancelled(courierId: number, orderId: number) {
  const courier = await prisma.user.findFirst({
    where: { courier: { id: courierId } },
    select: { id: true, lang: true, fcm_token: true },
  });

  if (!courier) return;

  try {
    await notifyUser({
      user: courier,
      content: {
        title: { en: "Order cancelled", ar: "تم إلغاء الطلب" },
        body: {
          en: `Order #${orderId} has been cancelled.`,
          ar: `تم إلغاء الطلب رقم #${orderId}.`,
        },
      },
      data: {
        page: `/orders/${orderId}`,
        navigate: "order_details",
        orderId,
        type: "ORDER_CANCELLED",
      },
    });
  } catch (error) {
    console.error("Failed to notify courier about cancelled order", {
      courierId,
      orderId,
      error,
    });
  }
}
