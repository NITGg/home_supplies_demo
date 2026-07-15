import cron from "node-cron";
import { prisma } from "../../DB/lib/prisma";
import logger from "../../config/logger.config";
import { notifyUser } from "../firebase-notification/notification.service";

export const pointsNodeCron = () => {
  // Run every day at midnight
  cron.schedule("0 0 * * *", async () => {
    logger.info("[Cron] Starting points expiration check...");
    try {
      // step: get settings
      const settings = await prisma.applicationSetting.findFirst();
      const validityDays = Number(settings?.courier_points_validity_days || 90);
      const notificationDays = Number(
        settings?.courier_points_expiration_notification_days || 4,
      );

      // ============================ NOTIFY USERS ABOUT EXPIRING POINTS ============================
      await notifyExpiringPoints(validityDays, notificationDays);

      // ============================ EXPIRE OLD POINTS ============================
      await expireOldPoints(validityDays);
    } catch (error) {
      logger.error(
        { err: error },
        "[Cron] Error running points expiration check",
      );
    }
  });
};

async function notifyExpiringPoints(
  validityDays: number,
  notificationDays: number,
) {
  logger.info(
    `[Cron] Checking for points expiring in ${notificationDays} days...`,
  );

  const now = new Date();

  // Calculate the expiration threshold date for notification
  // Points created on or before this date will expire within notificationDays
  const notificationThreshold = new Date(now);
  notificationThreshold.setDate(
    notificationThreshold.getDate() - validityDays + notificationDays,
  );

  // Calculate the lower bound - don't notify for already expired points
  const expiredThreshold = new Date(now);
  expiredThreshold.setDate(expiredThreshold.getDate() - validityDays);

  // Find batches that will expire soon (within notificationDays)
  const expiringBatches = await prisma.courierPointBatch.findMany({
    where: {
      is_expired: false,
      deleted_at: null,
      balance: { gt: 0 },
      created_at: {
        lte: notificationThreshold,
        gt: expiredThreshold,
      },
    },
    include: {
      user: {
        select: {
          id: true,
          lang: true,
          fcm_token: true,
        },
      },
    },
  });

  if (expiringBatches.length === 0) {
    logger.info("[Cron] No points batches expiring soon.");
    return;
  }

  logger.info(`[Cron] Found ${expiringBatches.length} batches expiring soon.`);

  // Group batches by user for consolidated notifications
  const batchesByUser = new Map<number, typeof expiringBatches>();
  for (const batch of expiringBatches) {
    if (!batch.user_id || !batch.user) continue;

    if (!batchesByUser.has(batch.user_id)) {
      batchesByUser.set(batch.user_id, []);
    }
    batchesByUser.get(batch.user_id)!.push(batch);
  }

  // Send notifications to users
  for (const [userId, batches] of batchesByUser) {
    const firstBatch = batches[0];
    if (!firstBatch) continue;

    const user = firstBatch.user;
    if (!user) continue;

    const totalPoints = batches.reduce(
      (sum, batch) => sum + (batch.balance || 0),
      0,
    );
    const expiryDate = new Date(firstBatch.created_at);
    expiryDate.setDate(expiryDate.getDate() + validityDays);
    const daysLeft = Math.max(
      0,
      Math.ceil((expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)),
    );

    try {
      await notifyUser({
        user: {
          id: user.id,
          lang: user.lang,
          fcm_token: user.fcm_token,
        },
        content: {
          title: {
            en: "Points Expiring Soon",
            ar: "النقاط على وشك الانتهاء",
          },
          body: {
            en: `You have ${totalPoints} points that will expire in ${daysLeft} day(s). Use them before they expire!`,
            ar: `لديك ${totalPoints} نقطة ستنتهي صلاحيتها خلال ${daysLeft} يوم. استخدمها قبل انتهاء صلاحيتها!`,
          },
        },
        data: {
          page: "/points",
          navigate: "points",
        },
      });
      logger.info(
        `[Cron] Notified user ${userId} about ${totalPoints} points expiring in ${daysLeft} days.`,
      );
    } catch (error) {
      logger.error(
        { err: error },
        `[Cron] Failed to notify user ${userId} about expiring points`,
      );
    }
  }
}

async function expireOldPoints(validityDays: number) {
  logger.info("[Cron] Checking for expired points to process...");

  // Calculate the expiration threshold date
  // if a batch was created on or before this date, it is expired.
  const expirationThreshold = new Date();
  expirationThreshold.setDate(expirationThreshold.getDate() - validityDays);

  // step: find all batches that should be expired
  const expiredBatches = await prisma.courierPointBatch.findMany({
    where: {
      is_expired: false,
      deleted_at: null,
      created_at: {
        lte: expirationThreshold,
      },
    },
  });

  if (expiredBatches.length === 0) {
    logger.info("[Cron] No points batches to expire today.");
    return;
  }

  logger.info(`[Cron] Found ${expiredBatches.length} batches to expire.`);

  let processedCount = 0;

  // step: process each expired batch
  for (const batch of expiredBatches) {
    await prisma.$transaction(async (tx: any) => {
      // 1. Mark batch as expired
      await tx.courierPointBatch.update({
        where: { id: batch.id },
        data: {
          is_expired: true,
          expired_at: new Date(),
        },
      });

      // 2. If the batch has a remaining balance, deduct it from the wallet points
      const remainingBalance = batch.balance || 0;
      if (remainingBalance > 0 && batch.user_id) {
        const wallet = await tx.wallet.findUnique({
          where: { user_id: batch.user_id },
        });

        if (wallet) {
          await tx.wallet.update({
            where: { id: wallet.id },
            data: { points: { decrement: remainingBalance } },
          });

          // 3. Log a transaction for the points deduction
          await tx.transaction.create({
            data: {
              wallet_id: wallet.id,
              courier_point_batch_id: batch.id,
              type: "MANUAL_DECREASE",
              status: "COMPLETED",
              amount: -remainingBalance,
              description: `Points expired from batch #${batch.id}`,
            },
          });
        }
      }
    });
    processedCount++;
  }

  logger.info(`[Cron] Successfully expired ${processedCount} point batches.`);
}
