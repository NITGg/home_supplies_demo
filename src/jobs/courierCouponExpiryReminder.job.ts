import cron from "node-cron";
import { prisma } from "@/config/prisma";
import { notifyUser } from "@/services/notification.service";
import { logger } from "@/config/logger";

function startOfDay(date: Date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfDay(date: Date) {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

function addDays(date: Date, days: number) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

export function registerCourierCouponExpiryReminderJob() {
  // Every hour
  cron.schedule("0 * * * *", async () => {
    const now = new Date();
    try {
      await sendCourierCouponExpiryReminders(now);
    } catch (error) {
      logger.error({ error }, "job failed: courier coupon expiry reminder");
    }
  });
}

async function sendCourierCouponExpiryReminders(now: Date) {
  const in3DaysStart = startOfDay(addDays(now, 3));
  const in3DaysEnd = endOfDay(addDays(now, 3));

  const in1DayStart = startOfDay(addDays(now, 1));
  const in1DayEnd = endOfDay(addDays(now, 1));

  // 3-day reminders
  const usages3d = await prisma.courierCouponUsage.findMany({
    where: {
      end_date: {
        gte: in3DaysStart,
        lt: in3DaysEnd,
      },
      expiry_reminder_3d_sent_at: null,
      coupon: {
        is_active: true,
        deleted_at: null,
      },
      user: {
        is_active: true,
        deleted_at: null,
      },
    },
    select: {
      id: true,
      end_date: true,
      user: {
        select: {
          id: true,
          lang: true,
          fcm_token: true,
        },
      },
      coupon: {
        select: {
          id: true,
          title: true,
          title_ar: true,
        },
      },
    },
  });

  for (const usage of usages3d) {
    if (!usage.user) continue;

    await notifyUser({
      user: usage.user,
      content: {
        titleKey: "courier-coupons:notifications.expiring_soon.title",
        bodyKey: "courier-coupons:notifications.expiring_soon.body",
        bodyParams: {
          title: usage.coupon.title,
          days: 3,
        },
      },
      data: {
        type: "COURIER_COUPON_EXPIRING",
        couponId: usage.coupon.id,
        usageId: usage.id,
        daysLeft: 3,
        page: "/courier/coupons",
        navigate: "coupons",
      },
    });

    await prisma.courierCouponUsage.update({
      where: { id: usage.id },
      data: {
        expiry_reminder_3d_sent_at: now,
      },
    });
  }

  // 1-day reminders
  const usages1d = await prisma.courierCouponUsage.findMany({
    where: {
      end_date: {
        gte: in1DayStart,
        lt: in1DayEnd,
      },
      expiry_reminder_1d_sent_at: null,
      coupon: {
        is_active: true,
        deleted_at: null,
      },
      user: {
        is_active: true,
        deleted_at: null,
      },
    },
    select: {
      id: true,
      end_date: true,
      user: {
        select: {
          id: true,
          lang: true,
          fcm_token: true,
        },
      },
      coupon: {
        select: {
          id: true,
          title: true,
          title_ar: true,
        },
      },
    },
  });

  for (const usage of usages1d) {
    if (!usage.user) continue;
    await notifyUser({
      user: usage.user,
      content: {
        titleKey: "courier-coupons:notifications.expiring_soon.title",
        bodyKey: "courier-coupons:notifications.expiring_soon.body",
        bodyParams: {
          title: usage.coupon.title,
          days: 1,
        },
      },
      data: {
        type: "COURIER_COUPON_EXPIRING",
        couponId: usage.coupon.id,
        usageId: usage.id,
        daysLeft: 1,
        page: "/courier/coupons",
        navigate: "coupons",
      },
    });

    await prisma.courierCouponUsage.update({
      where: { id: usage.id },
      data: {
        expiry_reminder_1d_sent_at: now,
      },
    });
  }

  logger.info(
    {
      reminders3d: usages3d.length,
      reminders1d: usages1d.length,
    },
    "job completed: courier coupon expiry reminder",
  );
}
