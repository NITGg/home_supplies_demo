import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { NextFunction, Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";

export class AdminCourierStatService {
  constructor() {}

  // ============ Helper function to get date range ============
  private getDateRange(fromDate?: Date, toDate?: Date) {
    if (!fromDate && !toDate) {
      return undefined; // All time - no date filter
    }
    if (fromDate && !toDate) {
      return { gte: fromDate }; // From fromDate onwards
    }
    if (!fromDate && toDate) {
      return { lte: toDate }; // Up to toDate
    }
    return { gte: fromDate, lte: toDate }; // Date range
  }

  // ============ Helper function to calculate stats for a single courier ============
  private async calculateCourierStats(
    courierId: number,
    userId: number,
    dateRange?: { gte?: Date; lte?: Date },
  ) {
    const dateFilter = dateRange ? { created_at: dateRange } : {};

    const [
      orders,
      courierCouponUsages,
      receivedReviews,
      givenReviews,
      proposals,
      issues,
      unpaidCommissions,
      penalties,
      wallet,
      // points,
    ] = await Promise.all([
      prisma.order.findMany({
        where: { courier_id: courierId, ...dateFilter },
        select: {
          id: true,
          order_number: true,
          status: true,
          actual_price: true,
          courier_fee: true,
          created_at: true,
          delivered_at: true,
        },
      }),
      prisma.courierCouponUsage.findMany({
        where: { user_id: userId, ...dateFilter },
        select: {
          id: true,
          snapshot_bonus_courier_fee: true,
          snapshot_price: true,
          start_date: true,
          end_date: true,
          coupon: {
            select: { id: true, title: true, duration_days: true },
          },
        },
      }),
      prisma.courierReviewFromCustomer.findMany({
        where: { courier_id: courierId, ...dateFilter },
        select: {
          id: true,
          rating: true,
          comment: true,
          order_id: true,
          customer_id: true,
          created_at: true,
        },
      }),
      prisma.customerReviewFromCourier.findMany({
        where: { courier_id: courierId, ...dateFilter },
        select: {
          id: true,
          rating: true,
          comment: true,
          order_id: true,
          customer_id: true,
          created_at: true,
        },
      }),
      prisma.orderProposal.findMany({
        where: { courier_id: courierId, ...dateFilter },
        select: {
          id: true,
          order_id: true,
          status: true,
          total_fee: true,
          created_at: true,
        },
      }),
      prisma.orderIssue.findMany({
        where: { courier_id: courierId, ...dateFilter },
        select: {
          id: true,
          order_id: true,
          status: true,
          reason: true,
          created_at: true,
        },
      }),
      prisma.unpaidCommission.findMany({
        where: { user_id: userId },
        select: { amount: true, is_paid: true },
      }),
      prisma.penalty.findMany({
        where: { user_id: userId },
        select: {
          id: true,
          amount: true,
          reason: true,
          is_paid: true,
          is_waived: true,
          created_at: true,
        },
      }),
      prisma.wallet.findFirst({
        where: { user_id: userId },
        select: {
          balance: true,
          status: true,
          frozen_at: true,
          freeze_reason: true,
          transactions: {
            select: { type: true, amount: true, status: true },
          },
        },
      }),
      // prisma.points.findFirst({
      //   where: { user_id: userId },
      //   select: {
      //     balance: true,
      //     completed_orders_count: true,
      //     four_star_ratings_count: true,
      //     five_star_ratings_count: true,
      //     cycle_end_date: true,
      //   },
      // }),
    ]);

    // ================================================================
    // ORDER STATS
    // ================================================================
    const totalOrders = orders.length;
    const completedOrders = orders.filter(
      (o) => o.status === "DELIVERED",
    ).length;
    const cancelledOrders = orders.filter(
      (o) => o.status === "CANCELLED",
    ).length;
    const expiredOrders = orders.filter((o) => o.status === "EXPIRED").length;
    const searchFailedOrders = orders.filter(
      (o) => o.status === "SEARCHING_FAILED",
    ).length;
    const activeOrders = orders.filter(
      (o) => o.status === "IN_PROGRESS",
    ).length;
    const pendingOrders = orders.filter((o) => o.status === "PENDING").length;

    const completionRate =
      totalOrders > 0 ? Math.round((completedOrders / totalOrders) * 100) : 0;
    const cancellationRate =
      totalOrders > 0 ? Math.round((cancelledOrders / totalOrders) * 100) : 0;

    const totalCourierFee = orders.reduce(
      (sum, o) => sum + Number(o.courier_fee || 0),
      0,
    );
    const totalActualPrice = orders.reduce(
      (sum, o) => sum + Number(o.actual_price || 0),
      0,
    );
    const avgOrderValue =
      completedOrders > 0 ? Math.round(totalActualPrice / completedOrders) : 0;

    // avg delivery time
    let avgDeliveryTime = 0;
    const deliveredOrders = orders.filter(
      (o) => o.status === "DELIVERED" && o.delivered_at,
    );
    if (deliveredOrders.length > 0) {
      const totalTime = deliveredOrders.reduce((sum, o) => {
        return (
          sum +
          (new Date(o.delivered_at!).getTime() -
            new Date(o.created_at).getTime())
        );
      }, 0);
      avgDeliveryTime = Math.round(totalTime / deliveredOrders.length / 60000);
    }

    // proposals
    const totalProposals = proposals.length;
    const acceptedProposals = proposals.filter(
      (p) => p.status === "ACCEPTED",
    ).length;
    const acceptanceRate =
      totalProposals > 0
        ? Math.round((acceptedProposals / totalProposals) * 100)
        : 0;

    // issues
    const totalIssues = issues.length;
    const openIssues = issues.filter((i) => i.status === "OPEN").length;
    const resolvedIssues = issues.filter((i) => i.status === "RESOLVED").length;
    const dismissedIssues = issues.filter(
      (i) => i.status === "DISMISSED",
    ).length;

    // unpaid commissions
    const unpaidCommissionCount = unpaidCommissions.filter(
      (u) => !u.is_paid,
    ).length;
    const totalUnpaidCommissionAmount = unpaidCommissions
      .filter((u) => !u.is_paid)
      .reduce((sum, u) => sum + Number(u.amount), 0);

    // penalties
    const totalPenalties = penalties.length;
    const paidPenalties = penalties.filter((p) => p.is_paid).length;
    const waivedPenalties = penalties.filter((p) => p.is_waived).length;
    const unpaidPenalties = penalties.filter(
      (p) => !p.is_paid && !p.is_waived,
    ).length;
    const totalPenaltyAmount = penalties.reduce(
      (sum, p) => sum + Number(p.amount),
      0,
    );
    const paidPenaltyAmount = penalties
      .filter((p) => p.is_paid)
      .reduce((sum, p) => sum + Number(p.amount), 0);
    const waivedPenaltyAmount = penalties
      .filter((p) => p.is_waived)
      .reduce((sum, p) => sum + Number(p.amount), 0);
    const unpaidPenaltyAmount = penalties
      .filter((p) => !p.is_paid && !p.is_waived)
      .reduce((sum, p) => sum + Number(p.amount), 0);

    // ================================================================
    // COUPON STATS
    // ================================================================
    const totalCouponsUsed = courierCouponUsages.length;
    const totalBonusCourierFee = courierCouponUsages.reduce(
      (sum, u) => sum + Number(u.snapshot_bonus_courier_fee),
      0,
    );
    const totalSpent = courierCouponUsages.reduce(
      (sum, u) => sum + Number(u.snapshot_price),
      0,
    );
    const roiRatio =
      totalSpent > 0
        ? Math.round((totalBonusCourierFee / totalSpent) * 100) / 100
        : 0;
    const avgDurationDays =
      totalCouponsUsed > 0
        ? Math.round(
            courierCouponUsages.reduce((sum, u) => {
              return (
                sum +
                (new Date(u.end_date).getTime() -
                  new Date(u.start_date).getTime()) /
                  86400000
              );
            }, 0) / totalCouponsUsed,
          )
        : 0;

    const now = new Date();
    const activeUsage = courierCouponUsages.find(
      (u) => new Date(u.start_date) <= now && new Date(u.end_date) >= now,
    );
    const activeCoupon = activeUsage
      ? {
          title: activeUsage.coupon.title,
          expiresAt: new Date(activeUsage.end_date).toISOString().split("T")[0],
          daysRemaining: Math.ceil(
            (new Date(activeUsage.end_date).getTime() - now.getTime()) /
              86400000,
          ),
          bonusCourierFee: Number(activeUsage.snapshot_bonus_courier_fee),
        }
      : null;

    // wallet transactions breakdown
    const walletTransactions = wallet?.transactions ?? [];
    const topups = walletTransactions.filter((t) => t.type === "TOPUP");
    const withdrawals = walletTransactions.filter(
      (t) => t.type === "WITHDRAWAL",
    );
    const penaltyTransactions = walletTransactions.filter(
      (t) => t.type === "PENALTY",
    );

    // ================================================================
    // REVIEW STATS
    // ================================================================
    const receivedReviewsCount = receivedReviews.length;
    const avgReceivedRating =
      receivedReviewsCount > 0
        ? Math.round(
            (receivedReviews.reduce((sum, r) => sum + r.rating, 0) /
              receivedReviewsCount) *
              10,
          ) / 10
        : 0;
    const fiveStarCount = receivedReviews.filter((r) => r.rating === 5).length;
    const fourStarCount = receivedReviews.filter((r) => r.rating === 4).length;
    const threeStarOrBelow = receivedReviews.filter(
      (r) => r.rating <= 3,
    ).length;

    const givenReviewsCount = givenReviews.length;
    const avgGivenRating =
      givenReviewsCount > 0
        ? Math.round(
            (givenReviews.reduce((sum, r) => sum + r.rating, 0) /
              givenReviewsCount) *
              10,
          ) / 10
        : 0;

    // ================================================================
    // RETURN
    // ================================================================
    return {
      orderStats: {
        total: totalOrders, // All orders ever assigned to this courier
        completed: completedOrders, // Orders successfully delivered
        cancelled: cancelledOrders, // Orders cancelled by any party
        expired: expiredOrders, // Orders that expired before assignment
        searchFailed: searchFailedOrders, // Orders where courier search failed
        active: activeOrders, // Orders currently in progress
        pending: pendingOrders, // Orders waiting for courier response
        completionRate, // % of orders delivered (completed / total * 100)
        cancellationRate, // % of orders cancelled (cancelled / total * 100)
        totalCourierFee: Math.round(totalCourierFee), // Sum of courier_fee (courier's cut)
        totalActualPrice: Math.round(totalActualPrice), // Sum of actual_price (order value)
        avgOrderValue, // Average value per completed order
        avgDeliveryTime, // Average minutes from creation to delivery
        proposals: {
          total: totalProposals, // Total proposals submitted by this courier
          accepted: acceptedProposals, // Proposals accepted by customers
          acceptanceRate, // % of proposals accepted
        },
        issues: {
          total: totalIssues, // Total issues reported against this courier
          open: openIssues, // Issues still awaiting admin review
          resolved: resolvedIssues, // Issues resolved by admin
          dismissed: dismissedIssues, // Issues dismissed as false reports
        },
        unpaidCommissions: {
          count: unpaidCommissionCount, // Number of unpaid commission records
          totalAmount: Math.round(totalUnpaidCommissionAmount), // Total amount owed to platform
        },
        penalties: {
          total: totalPenalties, // Total penalties ever issued
          paid: paidPenalties, // Penalties that were paid
          waived: waivedPenalties, // Penalties waived by admin
          unpaid: unpaidPenalties, // Penalties still pending payment
          totalAmount: Math.round(totalPenaltyAmount), // Total penalty amount issued
          paidAmount: Math.round(paidPenaltyAmount), // Amount already paid
          waivedAmount: Math.round(waivedPenaltyAmount), // Amount waived by admin
          unpaidAmount: Math.round(unpaidPenaltyAmount), // Amount still owed
        },
      },
      couponStats: {
        used: totalCouponsUsed, // Number of courier coupons purchased
        totalSpent: Math.round(totalSpent), // Total EGP paid to buy coupons
        totalBonusEarned: Math.round(totalBonusCourierFee), // Total bonus courier fee earned
        roiRatio, // Bonus earned per EGP spent — healthy if > 1.0
        avgDurationDays, // Average duration in days of purchased coupons
        activeCoupon, // Currently active coupon, null if none
        // points: {
        //   balance: points?.balance ?? 0, // Current points balance
        //   completedOrdersCount: points?.completed_orders_count ?? 0, // Orders counted this cycle
        //   fourStarRatingsCount: points?.four_star_ratings_count ?? 0, // 4-star ratings this cycle
        //   fiveStarRatingsCount: points?.five_star_ratings_count ?? 0, // 5-star ratings this cycle
        //   cycleEndsAt: points?.cycle_end_date ?? null, // When current cycle resets
        // },
        wallet: {
          balance: wallet?.balance ?? 0, // Current wallet balance
          status: wallet?.status ?? null, // ACTIVE or FROZEN
          frozenAt: wallet?.frozen_at ?? null, // When wallet was frozen, null if active
          freezeReason: wallet?.freeze_reason ?? null, // Why wallet was frozen, null if active
          transactions: {
            total: walletTransactions.length, // Total number of wallet transactions
            topups: topups.length, // Number of TOPUP transactions
            withdrawals: withdrawals.length, // Number of WITHDRAWAL transactions
            penalties: penaltyTransactions.length, // Number of PENALTY transactions
            totalTopupAmount: Math.round(
              topups.reduce((sum, t) => sum + Number(t.amount), 0),
            ), // Total EGP added via topups
            totalWithdrawalAmount: Math.round(
              withdrawals.reduce((sum, t) => sum + Number(t.amount), 0),
            ), // Total EGP withdrawn
            totalPenaltyAmount: Math.round(
              penaltyTransactions.reduce((sum, t) => sum + Number(t.amount), 0),
            ), // Total EGP deducted as penalties
          },
        },
      },
      reviewStats: {
        received: {
          count: receivedReviewsCount, // Total reviews received from customers
          avgRating: avgReceivedRating, // Average rating given by customers (out of 5)
          fiveStarCount, // Number of 5-star reviews received
          fourStarCount, // Number of 4-star reviews received
          threeStarOrBelow, // Reviews rated 3 or below (quality risk signal)
        },
        given: {
          count: givenReviewsCount, // Total reviews given to customers
          avgRating: avgGivenRating, // Average rating this courier gives (out of 5)
        },
      },
      details: {
        orders: orders.map((o) => ({
          id: o.id,
          orderNumber: o.order_number, // navigate to /admin/orders/:id
          status: o.status,
          courierFee: Number(o.courier_fee ?? 0),
          actualPrice: Number(o.actual_price ?? 0),
          createdAt: o.created_at,
          deliveredAt: o.delivered_at ?? null,
        })),

        coupons: courierCouponUsages.map((u) => ({
          usageId: u.id,
          couponId: u.coupon.id, // navigate to /admin/courier-coupons/:couponId
          title: u.coupon.title,
          spent: Number(u.snapshot_price),
          bonusEarned: Number(u.snapshot_bonus_courier_fee),
          startDate: u.start_date,
          endDate: u.end_date,
          isActive:
            new Date(u.start_date) <= now && new Date(u.end_date) >= now,
        })),

        receivedReviews: receivedReviews.map((r) => ({
          id: r.id,
          orderId: r.order_id ?? null, // navigate to /admin/orders/:orderId
          customerId: r.customer_id, // navigate to /admin/users/:customerId
          rating: r.rating,
          comment: r.comment ?? null,
          createdAt: r.created_at,
        })),

        givenReviews: givenReviews.map((r) => ({
          id: r.id,
          orderId: r.order_id ?? null, // navigate to /admin/orders/:orderId
          customerId: r.customer_id, // navigate to /admin/users/:customerId
          rating: r.rating,
          comment: r.comment ?? null,
          createdAt: r.created_at,
        })),

        proposals: proposals.map((p) => ({
          id: p.id,
          orderId: p.order_id, // navigate to /admin/orders/:orderId
          status: p.status,
          totalFee: Number(p.total_fee),
          createdAt: p.created_at,
        })),

        issues: issues.map((i) => ({
          id: i.id,
          orderId: i.order_id, // navigate to /admin/orders/:orderId
          status: i.status,
          reason: i.reason,
          createdAt: i.created_at,
        })),

        penalties: penalties.map((p) => ({
          id: p.id, // navigate to /admin/penalties/:id
          amount: Number(p.amount),
          reason: p.reason ?? null,
          isPaid: p.is_paid,
          isWaived: p.is_waived,
          createdAt: p.created_at,
        })),
      },
    };
  }

  // ============ Helper function to format response ============
  private formatCourierStatResponse(
    courier: any,
    stats: any,
    dateRange?: { gte?: Date; lte?: Date },
  ) {
    return {
      courier: {
        id: courier.id,
        name: courier.user?.full_name || "Unknown",
        phone: courier.user?.phone || "N/A",
        vehicle: courier.vehicle?.name || null,
      },
      dateRange: dateRange
        ? {
            from: dateRange.gte?.toISOString().split("T")[0] || null,
            to: dateRange.lte?.toISOString().split("T")[0] || null,
          }
        : { from: null, to: null }, // All time
      orders: stats.orderStats,
      coupons: stats.couponStats,
      reviews: stats.reviewStats,
      details: stats.details,
    };
  }

  // ============================ courierStat ============================
  courierStat = async (req: Request, res: Response, next: NextFunction) => {
    const { courierId } = req.sanitized.params;
    const { fromDate, toDate } = res.locals.validatedData || req.sanitized.body;

    // step: validate courierId
    const courier = await prisma.courier.findUnique({
      where: { id: Number(courierId) },
      include: {
        user: {
          select: {
            full_name: true,
            phone: true,
          },
        },
        vehicle: {
          select: {
            name: true,
          },
        },
      },
    });

    if (!courier) {
      throw new HttpError(
        404,
        req.t("admin-courier-stat:errors.courier_not_found"),
      );
    }

    // step: get date range
    const dateRange = this.getDateRange(fromDate, toDate);

    // step: calculate stats
    const stats = await this.calculateCourierStats(
      courier.id,
      courier.user_id,
      dateRange,
    );

    // step: format and return response
    const formattedStats = this.formatCourierStatResponse(
      courier,
      stats,
      dateRange,
    );

    return res.json({
      message: req.t("admin-courier-stat:messages.courier_stat_retrieved"),
      data: formattedStats,
    });
  };

  // ============================ allCourierStat ============================
  allCourierStat = async (req: Request, res: Response, next: NextFunction) => {
    const { fromDate, toDate } = res.locals.validatedData || req.sanitized.body;

    // step: get date range
    const dateRange = this.getDateRange(fromDate, toDate);

    // step: apply filters and pagination using FeatureApi
    const queryOptions = new FeatureApi(req)
      .filter()
      .sort("-created_at")
      .limit(10)
      .skip(0)
      .includes()
      .keyword([])
      .fields().data;

    // Extract specific options for Prisma query
    const take = queryOptions.take || 10;
    const skip = queryOptions.skip || 0;

    // step: fetch all couriers with relations
    const [couriers, total] = await Promise.all([
      prisma.courier.findMany({
        include: {
          user: {
            select: {
              full_name: true,
              phone: true,
            },
          },
          vehicle: {
            select: {
              name: true,
            },
          },
        },
        where: queryOptions.where,
        orderBy: queryOptions.orderBy,
        take,
        skip,
      }),
      prisma.courier.count({
        where: queryOptions.where,
      }),
    ]);

    // step: calculate stats for each courier in parallel
    const courierStatsArray = await Promise.all(
      couriers.map(async (courier) => {
        const stats = await this.calculateCourierStats(
          courier.id,
          courier.user_id,
          dateRange,
        );
        return this.formatCourierStatResponse(courier, stats, dateRange);
      }),
    );

    // Build pagination response
    const pages = Math.ceil(total / take);
    const page = Math.floor(skip / take) + 1;

    // step: return response with pagination
    return res.json({
      message: req.t("admin-courier-stat:messages.courier_stats_retrieved"),
      data: {
        couriers: courierStatsArray,
        pagination: {
          page,
          limit: take,
          total,
          pages,
        },
      },
    });
  };
}
