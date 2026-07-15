import getAdminUsers from "@/lib/getAdminUsers";
import { prisma } from "@/config/prisma";
import { notifyUsers, notifyUser } from "@/services/notification.service";
import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";
import { AppEvents } from "@/types/events";
import { sendWebhookEvent } from "@/queues/webhook";
import type { WebhookOrderExpiredPayload } from "@/queues/webhook/webhook.types";

type OrderExpiredEvent = AppEvents["order.expired"];

const onOrderExpired = async (payload: OrderExpiredEvent) => {
  const { orderId, customerId, externalAppId, pickupAreaId } = payload;

  if (pickupAreaId) {
    getIo().to(rooms.area(pickupAreaId)).emit("order:taken", { orderId });
  }

  // ── External app order: send webhook, skip customer notifications ──
  if (externalAppId) {
    const externalApp = await prisma.externalApp.findUnique({
      where: { id: externalAppId },
      select: { id: true, webhook_url: true, webhook_secret: true },
    });

    if (externalApp?.webhook_url && externalApp?.webhook_secret) {
      await sendWebhookEvent<WebhookOrderExpiredPayload>(externalApp.id, {
        eventType: "ORDER_EXPIRED",
        webhookUrl: externalApp.webhook_url,
        webhookSecret: externalApp.webhook_secret,
        payload: {
          id: orderId,
          expired_at: payload.expiredAt,
        },
      });
    }

    // Still notify admins for external app orders
    const adminUsers = await getAdminUsers();
    if (adminUsers.length > 0) {
      await notifyUsers({
        users: adminUsers,
        content: {
          titleKey: "orders:messages.order_expired_admin.title",
          bodyKey: "orders:messages.order_expired_admin.body",
          bodyParams: { orderId: orderId.toString() },
        },
        data: {
          orderId: orderId.toString(),
          page: `/admin/orders/${orderId}`,
          type: "ORDER_EXPIRED_ADMIN",
        },
      });
    }

    return;
  }

  // ── Customer order: existing notification logic ────────────────────
  const [adminUsers, customer] = await Promise.all([
    getAdminUsers(),
    customerId
      ? prisma.user.findUnique({
          where: { id: customerId },
          select: { id: true, lang: true, fcm_token: true },
        })
      : null,
  ]);

  await Promise.all([
    adminUsers.length > 0 &&
      notifyUsers({
        users: adminUsers,
        content: {
          titleKey: "orders:messages.order_expired_admin.title",
          bodyKey: "orders:messages.order_expired_admin.body",
          bodyParams: { orderId: orderId.toString() },
        },
        data: {
          orderId: orderId.toString(),
          page: `/admin/orders/${orderId}`,
          type: "ORDER_EXPIRED_ADMIN",
        },
      }),

    customer &&
      notifyUser({
        user: customer,
        content: {
          titleKey: "orders:messages.order_expired_customer.title",
          bodyKey: "orders:messages.order_expired_customer.body",
          bodyParams: { orderId: orderId.toString() },
        },
        data: {
          orderId: orderId.toString(),
          page: `/orders/${orderId}`,
          type: "ORDER_EXPIRED",
        },
      }),

    // // Notify supplier if catalog order
    // payload.orderType === "CATALOG_PURCHASE" &&
    //   payload.supplierId &&
    //   notifySupplierOrder(payload.supplierId, orderId, "ORDER_EXPIRED"),
  ]);
};

export default onOrderExpired;
