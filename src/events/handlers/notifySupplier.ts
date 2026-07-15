// lib/supplierNotifier.ts

import { prisma } from "@/config/prisma";
import { notifyUser } from "@/services/notification.service";
import { isUserOnline } from "@/socket/status";
import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";

type SupplierOrderEvent =
  | "NEW_ORDER"
  | "ORDER_CANCELLED"
  | "ORDER_EXPIRED"
  | "ORDER_DELIVERED";

const EVENT_CONFIG: Record<
  SupplierOrderEvent,
  {
    socketEvent: string;
    title: { en: string; ar: string };
    body: (orderId: number) => { en: string; ar: string };
    page: (orderId: number) => string;
  }
> = {
  NEW_ORDER: {
    socketEvent: "order:new",
    title: { en: "New Order", ar: "طلب جديد" },
    body: (orderId) => ({
      en: `Order #${orderId} is waiting for confirmation.`,
      ar: `الطلب رقم #${orderId} في انتظار التأكيد.`,
    }),
    page: () => "/orders",
  },
  ORDER_CANCELLED: {
    socketEvent: "order:cancelled",
    title: { en: "Order Cancelled", ar: "تم إلغاء الطلب" },
    body: (orderId) => ({
      en: `Order #${orderId} has been cancelled by the customer.`,
      ar: `تم إلغاء الطلب رقم #${orderId} من قِبل العميل.`,
    }),
    page: (orderId) => `/orders/${orderId}`,
  },
  ORDER_EXPIRED: {
    socketEvent: "order:expired",
    title: { en: "Order Expired", ar: "انتهت صلاحية الطلب" },
    body: (orderId) => ({
      en: `Order #${orderId} expired before a courier was assigned.`,
      ar: `انتهت صلاحية الطلب رقم #${orderId} قبل تعيين مندوب.`,
    }),
    page: (orderId) => `/orders/${orderId}`,
  },
  ORDER_DELIVERED: {
    socketEvent: "order:delivered",
    title: { en: "Order Delivered", ar: "تم توصيل الطلب" },
    body: (orderId) => ({
      en: `Order #${orderId} has been delivered successfully.`,
      ar: `تم توصيل الطلب رقم #${orderId} بنجاح.`,
    }),
    page: (orderId) => `/orders/${orderId}`,
  },
};

export async function notifySupplierOrder(
  supplierId: number,
  orderId: number,
  type: SupplierOrderEvent,
) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId },
    select: { user: { select: { id: true, fcm_token: true, lang: true } } },
  });

  if (!supplier) return;

  const config = EVENT_CONFIG[type];

  if (isUserOnline(supplier.user.id)) {
    getIo().to(rooms.supplier(supplier.user.id)).emit(config.socketEvent, {
      orderId,
    });
  }

  try {
    await notifyUser({
      user: supplier.user,
      content: {
        title: config.title,
        body: config.body(orderId),
      },
      data: {
        type,
        orderId,
        page: config.page(orderId),
        navigate: "order_details",
      },
    });
  } catch (err) {
    console.error(`Failed to notify supplier [${type}]`, {
      supplierId,
      orderId,
      err,
    });
  }
}
