import { prisma } from "@/config/prisma";
import { notifyUsers } from "@/services/notification.service";
import { AppEvents } from "@/types/events";

type CourierCouponCreatedEvent = AppEvents["courier-coupon.created"];
type CourierCouponUpdatedEvent = AppEvents["courier-coupon.updated"];

async function getCourierUsers(skipUserId: number) {
  return prisma.user.findMany({
    where: {
      id: { not: skipUserId },
      deleted_at: null,
      is_active: true,
      role: {
        name: "Courier",
      },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });
}

export async function onCourierCouponCreated(event: CourierCouponCreatedEvent) {
  const users = await getCourierUsers(event.createdByUserId);

  if (!users.length) return;

  await notifyUsers({
    users,
    content: {
      titleKey: "courier-coupons:notifications.created.title",
      bodyKey: "courier-coupons:notifications.created.body",
      bodyParams: {
        title: event.title,
      },
    },
    data: {
      page: `/courier-coupons/${event.couponId}`,
      navigate: "coupons",
      couponId: event.couponId,
      type: "courier_coupon_created",
    },
  });
}

export async function onCourierCouponUpdated(event: CourierCouponUpdatedEvent) {
  const users = await getCourierUsers(event.updatedByUserId);

  if (!users.length) return;

  await notifyUsers({
    users,
    content: {
      titleKey: "courier-coupons:notifications.updated.title",
      bodyKey: "courier-coupons:notifications.updated.body",
      bodyParams: {
        title: event.title,
      },
    },
    data: {
      page: `/courier-coupons/${event.couponId}`,
      navigate: "coupons",
      couponId: event.couponId,
      type: "courier_coupon_updated",
    },
  });
}
