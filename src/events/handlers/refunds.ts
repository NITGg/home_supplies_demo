import { prisma } from "@/config/prisma";
import {
  notifyUsers,
  notifyAdminsExcept,
} from "@/services/notification.service";
import { AppEvents } from "@/types/events";

export async function onRefundRequested(event: AppEvents["refund.requested"]) {
  await notifyAdminsExcept(
    [],
    {
      titleKey: "refunds:notifications.requested.admin.title",
      bodyKey: "refunds:notifications.requested.admin.body",
      bodyParams: { orderNumber: event.orderNumber },
    },
    {
      type: "REFUND_REQUESTED",
      orderId: event.orderId.toString(),
      refundId: event.refundId.toString(),
      page: `/admin/refunds/${event.refundId}`,
      navigate: "admin-refund-details",
    },
  );
}

export async function onRefundApproved(event: AppEvents["refund.approved"]) {
  // 1. Notify the Customer their money is back in their wallet
  const customer = await prisma.user.findUnique({
    where: { id: event.customerId, deleted_at: null },
    select: { id: true, lang: true, fcm_token: true },
  });

  if (customer) {
    await notifyUsers({
      users: [customer],
      content: {
        titleKey: "refunds:notifications.approved.customer.title",
        bodyKey: "refunds:notifications.approved.customer.body",
        bodyParams: {
          orderNumber: event.orderNumber,
          amount: event.amountRefunded.toString(),
        },
      },
      data: {
        page: `/orders/${event.orderId}`,
        navigate: "order_details",
        orderId: event.orderId.toString(),
        refundId: event.refundId.toString(),
        type: "refund_approved_customer",
      },
    });
  }

  // 2. Alert the Faulty Actor (Supplier or Courier) regarding their wallet deduction charge
  if (event.faultyUserId) {
    const faultyActor = await prisma.user.findUnique({
      where: { id: event.faultyUserId, deleted_at: null },
      select: { id: true, lang: true, fcm_token: true },
    });

    if (faultyActor) {
      const actorRoleKey = event.faultType.toLowerCase(); // 'supplier' or 'courier'
      await notifyUsers({
        users: [faultyActor],
        content: {
          titleKey: `refunds:notifications.deduction.${actorRoleKey}.title`,
          bodyKey: `refunds:notifications.deduction.${actorRoleKey}.body`,
          bodyParams: { orderNumber: event.orderNumber },
        },
        data: {
          page: "/wallet",
          navigate: "wallet_ledger",
          orderId: event.orderId.toString(),
          type: "refund_actor_debit_penalty",
        },
      });
    }
  }
  // 3. Alert other admins that this refund has been processed and closed
  await notifyAdminsExcept(
    [event.reviewedByAdminId], // Skips the admin who reviewed it
    {
      titleKey: "refunds:notifications.approved.admin.title",
      bodyKey: "refunds:notifications.approved.admin.body",
      bodyParams: {
        orderNumber: event.orderNumber,
        amount: event.amountRefunded.toString(),
      },
    },
    {
      type: "REFUND_APPROVED",
      orderId: event.orderId.toString(),
      refundId: event.refundId.toString(),
      page: `/admin/refunds/${event.refundId}`,
      navigate: "admin-refund-details",
    },
  );
}

export async function onRefundRejected(event: AppEvents["refund.rejected"]) {
  // 1. Notify the Customer
  const customer = await prisma.user.findUnique({
    where: { id: event.customerId, deleted_at: null },
    select: { id: true, lang: true, fcm_token: true },
  });

  if (customer) {
    await notifyUsers({
      users: [customer],
      content: {
        titleKey: "refunds:notifications.rejected.title",
        bodyKey: "refunds:notifications.rejected.body",
        bodyParams: { orderNumber: event.orderNumber },
      },
      data: {
        page: `/orders/${event.orderId}`,
        navigate: "order_details",
        orderId: event.orderId.toString(),
        type: "refund_rejected",
      },
    });
  }

  // 2. Alert remaining admins regarding rejection event
  await notifyAdminsExcept(
    [event.reviewedByAdminId],
    {
      titleKey: "refunds:notifications.rejected.admin.title",
      bodyKey: "refunds:notifications.rejected.admin.body",
      bodyParams: { orderNumber: event.orderNumber },
    },
    {
      type: "REFUND_REJECTED",
      orderId: event.orderId.toString(),
      refundId: event.refundId.toString(),
      page: `/admin/refunds/${event.refundId}`,
      navigate: "admin-refund-details",
    },
  );
}