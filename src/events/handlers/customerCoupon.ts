import { logger } from "@/config/logger";
import { prisma } from "@/config/prisma";
import { notifyUsers } from "@/services/notification.service";
import { AppEvents } from "@/types/events";

type CustomerCouponCreatedEvent = AppEvents["customer-coupon.created"];
type CustomerCouponUpdatedEvent = AppEvents["customer-coupon.updated"];

async function getCustomerUsers(skipUserId: number) {
  return prisma.user.findMany({
    where: {
      id: { not: skipUserId },
      deleted_at: null,
      is_active: true,
      role: {
        name: "Customer",
      },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });
}

export async function onCustomerCouponCreated(
  event: CustomerCouponCreatedEvent,
) {
  const users = await getCustomerUsers(event.createdByUserId);
  logger.debug(users, "users:");
  if (!users.length) return;

  await notifyUsers({
    users,
    content: {
      titleKey: "customer-coupons:notifications.created.title",
      bodyKey: "customer-coupons:notifications.created.body",
      bodyParams: {
        title: event.title,
        code: event.code,
      },
    },
    data: {
      page: `/customer-coupons/${event.couponId}`,
      navigate: "coupons",
      couponId: event.couponId,
      code: event.code,
      type: "customer_coupon_created",
    },
  });
}

export async function onCustomerCouponUpdated(
  event: CustomerCouponUpdatedEvent,
) {
  const users = await getCustomerUsers(event.updatedByUserId);

  if (!users.length) return;

  await notifyUsers({
    users,
    content: {
      titleKey: "customer-coupons:notifications.updated.title",
      bodyKey: "customer-coupons:notifications.updated.body",
      bodyParams: {
        title: event.title,
        code: event.code,
      },
    },
    data: {
      page: `/customer-coupons/${event.couponId}`,
      navigate: "coupons",
      couponId: event.couponId,
      code: event.code,
      type: "customer_coupon_updated",
    },
  });
}
