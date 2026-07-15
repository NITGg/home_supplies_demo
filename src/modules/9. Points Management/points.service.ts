import { NextFunction, Request, Response } from "express";
import { responseHandler } from "../../core/handlers/response.handler";
import { prisma } from "../../DB/lib/prisma";
import { HttpStatusCode } from "../../core/http/http.status.code";

export class PointsService {
  constructor() {}

  // ============================ rules ============================
  rules = async (req: Request, res: Response, next: NextFunction) => {
    // step: get application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.settings_not_found"),
      });
    }

    const rules = {
      orders_reward: `Complete ${settings.courier_number_of_delivered_orders_required_per_reward_batch} delivered orders with ratings >= ${settings.courier_points_minimum_rating_threshold} to earn ${settings.courier_number_of_points_awarded_per_completed_order_batch} points`,
      points_value: `Every ${settings.courier_number_of_points_required_per_1egp} points = 1 EGP`,
      expiration: `Each point expires after ${settings.courier_points_validity_days} days`,
      redemption:
        "Redeem points to buy coupons, pay commissions, or cover penalties",
    };

    const rules_ar = {
      orders_reward: `أكمل ${settings.courier_number_of_delivered_orders_required_per_reward_batch} طلبات تم توصيلها بتقييم لا يقل عن ${settings.courier_points_minimum_rating_threshold} لتحصل على ${settings.courier_number_of_points_awarded_per_completed_order_batch} نقطة`,
      points_value: `كل ${settings.courier_number_of_points_required_per_1egp} نقاط = 1 جنيه`,
      expiration: `تنتهي صلاحية كل نقطة بعد ${settings.courier_points_validity_days} يومًا`,
      redemption:
        "يمكنك استخدام النقاط لشراء كوبونات أو سداد العمولات أو تغطية الغرامات",
    };

    return responseHandler({
      res,
      message: res.__("messages.points_retrieved"),
      data: { rules, rules_ar },
    });
  };

  // ============================ progress ============================
  progress = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.settings_not_found"),
      });
    }

    // step: get settings values
    const validityDays = Number(settings.courier_points_validity_days);
    const requiredOrders = Number(
      settings.courier_number_of_delivered_orders_required_per_reward_batch,
    );

    // step: get available CourierPointBatch (completed batches only)
    const availableCourierPointBatch = await prisma.courierPointBatch.findMany({
      where: {
        user_id: user.id,
        is_expired: false,
        deleted_at: null,
        NOT: { all_points_collected_at: null },
      },
      orderBy: {
        created_at: "desc",
      },
    });

    // step: get pending CourierPointBatch (in-progress batches)
    const pendingCourierPointBatch = await prisma.courierPointBatch.findMany({
      where: {
        user_id: user.id,
        is_expired: false,
        deleted_at: null,
        all_points_collected_at: null,
      },
      orderBy: {
        created_at: "desc",
      },
    });

    // step: get pending batch (the active one being filled)
    const pendingBatch =
      pendingCourierPointBatch.length > 0 ? pendingCourierPointBatch[0] : null;

    // step: build ordersProgress from pending batch
    const ordersCompletedInCurrentBatch =
      pendingBatch?.successful_orders_count || 0;
    const percentComplete = Math.round(
      (ordersCompletedInCurrentBatch / requiredOrders) * 100,
    );

    // step: build allExpirations from available batches
    const now = new Date();
    const allExpirations = availableCourierPointBatch
      .filter((batch) => (batch.balance || 0) > 0)
      .map((batch) => {
        const computedExpiry = new Date(batch.created_at);
        computedExpiry.setDate(computedExpiry.getDate() + validityDays);
        return {
          batchId: batch.id,
          points: batch.balance || 0,
          expiryDate: computedExpiry.toISOString().split("T")[0],
          daysLeft: Math.max(
            0,
            Math.ceil(
              (computedExpiry.getTime() - now.getTime()) /
                (1000 * 60 * 60 * 24),
            ),
          ),
        };
      })
      .sort((a, b) => a.daysLeft - b.daysLeft);

    return responseHandler({
      res,
      message: res.__("messages.points_progress_retrieved"),
      data: {
        ordersProgress: {
          ordersCompletedInCurrentBatch,
          requiredOrdersForNextBatch: requiredOrders,
          percentComplete,
        },
        pendingBatch: pendingBatch || null,
        allExpirations,
        availableBatches: availableCourierPointBatch,
      },
    });
  };
}
