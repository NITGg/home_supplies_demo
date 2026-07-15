import { NextFunction, Request, Response } from "express";
import { OrderStatus } from "@prisma/client";
import { EarningsHistoryQueryDTO, PerformanceQueryDTO } from "./stat.dto";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";

export class StatService {
  constructor() {}

  // ============================ earningsSummary ============================
  earningsSummary = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: calculate date ranges
    const now = new Date();
    const todayStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - ((weekStart.getDay() + 1) % 7)); // Start of week (Saturday)
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const yearStart = new Date(now.getFullYear(), 0, 1);

    // step: get earnings for different periods
    const [
      todayEarnings,
      weekEarnings,
      monthEarnings,
      yearEarnings,
      totalEarningsAgg,
      todayDeliveries,
      weekDeliveries,
      monthDeliveries,
      yearDeliveries,
      totalDeliveriesCount,
    ] = await Promise.all([
      // Today's earnings
      prisma.order.aggregate({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: todayStart },
        },
        _sum: { courier_fee: true },
      }),
      // This week's earnings
      prisma.order.aggregate({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: weekStart },
        },
        _sum: { courier_fee: true },
      }),
      // This month's earnings
      prisma.order.aggregate({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: monthStart },
        },
        _sum: { courier_fee: true },
      }),
      // This year's earnings
      prisma.order.aggregate({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: yearStart },
        },
        _sum: { courier_fee: true },
      }),
      // Total earnings
      prisma.order.aggregate({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
        },
        _sum: { courier_fee: true },
      }),
      // Today's deliveries count
      prisma.order.count({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: todayStart },
        },
      }),
      // This week's deliveries count
      prisma.order.count({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: weekStart },
        },
      }),
      // This month's deliveries count
      prisma.order.count({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: monthStart },
        },
      }),
      // This year's deliveries count
      prisma.order.count({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: yearStart },
        },
      }),
      // Total deliveries count
      prisma.order.count({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
        },
      }),
    ]);

    // step: get total earnings and deliveries
    const totalEarnings = totalEarningsAgg._sum.courier_fee || 0;
    const totalDeliveries = totalDeliveriesCount || 0;

    // step: get unpaid commissions
    const unpaidCommissions = await prisma.unpaidCommission.findMany({
      where: {
        user_id: user.id,
        is_paid: false,
      },
      select: {
        amount: true,
      },
    });

    const totalUnpaidAmount = unpaidCommissions.reduce(
      (sum, commission) => sum + Number(commission.amount),
      0,
    );

    return responseHandler({
      res,
      message: res.__("messages.earnings_summary_retrieved"),
      data: {
        today: {
          earnings: Number(todayEarnings._sum.courier_fee || 0),
          deliveries: todayDeliveries,
        },
        this_week: {
          earnings: Number(weekEarnings._sum.courier_fee || 0),
          deliveries: weekDeliveries,
        },
        this_month: {
          earnings: Number(monthEarnings._sum.courier_fee || 0),
          deliveries: monthDeliveries,
        },
        this_year: {
          earnings: Number(yearEarnings._sum.courier_fee || 0),
          deliveries: yearDeliveries,
        },
        total: {
          earnings: Number(totalEarnings),
          deliveries: totalDeliveries,
        },
        unpaid_commissions: {
          count: unpaidCommissions.length,
          total_amount: totalUnpaidAmount,
        },
      },
    });
  };

  // ============================ earningsHistory ============================
  earningsHistory = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        budget: "range",
        actual_price: "range",
        total_fee: "range",
        courier_fee: "range",
        platform_fee: "range",
        cancellation_fee: "range",
        order_number: "exact",
        pickup_area_id: "exact",
        delivery_area_id: "exact",
        status: "exact",
        created_at: "dateRange",
        offer_accepted_at: "dateRange",
        delivered_at: "dateRange",
        canceled_at: "dateRange",
      },
    );

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: Apply strict filters
    filters.courier_id = courier.id;

    const [orders, total] = await Promise.all([
      prisma.order.findMany({
        where: filters,
        select: {
          id: true,
          order_number: true,
          budget: true,
          actual_price: true,
          total_fee: true,
          courier_fee: true,
          platform_fee: true,
          cancellation_fee: true,
          status: true,
          pickup_area_id: true,
          delivery_area_id: true,
          created_at: true,
          offer_accepted_at: true,
          delivered_at: true,
          canceled_at: true,
          pickup_area: {
            select: { name: true, name_ar: true },
          },
          delivery_area: {
            select: { name: true, name_ar: true },
          },
        },
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
      prisma.order.count({
        where: filters,
      }),
    ]);

    // step: format transactions
    const transactions = orders.map((order) => ({
      order_id: order.id,
      order_number: order.order_number,
      budget: Number(order.budget || 0),
      actual_price: Number(order.actual_price || 0),
      total_fee: Number(order.total_fee || 0),
      courier_fee: Number(order.courier_fee || 0),
      platform_fee: Number(order.platform_fee || 0),
      cancellation_fee: Number(order.cancellation_fee || 0),
      status: order.status,
      pickup_area_id: order.pickup_area_id,
      delivery_area_id: order.delivery_area_id,
      pickup_area: order.pickup_area,
      delivery_area: order.delivery_area,
      created_at: order.created_at,
      offer_accepted_at: order.offer_accepted_at,
      delivered_at: order.delivered_at,
      canceled_at: order.canceled_at,
    }));

    return responseHandler({
      res,
      message: res.__("messages.earnings_history_retrieved"),
      data: {
        transactions,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ performance ============================
  performance = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const start_date = req.query.start_date as string | undefined;
    const end_date = req.query.end_date as string | undefined;

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: calculate date range (if no dates provided, return all data)
    let start: Date | undefined;
    let end: Date | undefined;

    // Helper: parse YYYY-MM-DD as local time (avoids UTC midnight shifting to previous day)
    const parseDateLocal = (dateStr: string): Date => {
      const parts = dateStr.split("-");
      const year = Number(parts[0]);
      const month = Number(parts[1]);
      const day = Number(parts[2]);
      return new Date(year, month - 1, day);
    };

    if (start_date || end_date) {
      if (start_date) {
        start = parseDateLocal(start_date);
      } else {
        start = new Date();
        start.setDate(start.getDate() - 7); // Default start to last 7 days if only end_date is provided
      }
      start.setHours(0, 0, 0, 0);

      if (end_date) {
        end = parseDateLocal(end_date);
      } else {
        end = new Date(); // Default end to today if only start_date is provided
      }
      end.setHours(23, 59, 59, 999);

      if (start > end) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.invalid_date_range"),
        );
      }
    }

    // step: get global statistics
    const [globalOrders, globalReviews, globalProposals, globalDeliveryTimes] =
      await Promise.all([
        prisma.order.groupBy({
          by: ["status"],
          where: {
            courier_id: courier.id,
            status: { in: [OrderStatus.DELIVERED, OrderStatus.CANCELLED] },
          },
          _count: true,
        }),
        prisma.courierReviewFromCustomer.aggregate({
          where: { courier_id: courier.id },
          _avg: { rating: true },
          _count: true,
        }),
        prisma.orderProposal.groupBy({
          by: ["status"],
          where: { courier_id: courier.id },
          _count: true,
        }),
        prisma.order.findMany({
          where: {
            courier_id: courier.id,
            status: OrderStatus.DELIVERED,
            delivered_at: { not: null },
            offer_accepted_at: { not: null },
          },
          select: { delivered_at: true, offer_accepted_at: true },
        }),
      ]);

    const globalCompleted =
      globalOrders.find((o) => o.status === OrderStatus.DELIVERED)?._count || 0;
    const globalCancelled =
      globalOrders.find((o) => o.status === OrderStatus.CANCELLED)?._count || 0;

    const totalProposals = globalProposals.reduce(
      (sum, p) => sum + p._count,
      0,
    );
    const acceptedProposalsTotal =
      globalProposals.find((p) => p.status === "ACCEPTED")?._count || 0;

    const globalAcceptanceRate =
      totalProposals > 0
        ? Math.round((acceptedProposalsTotal / totalProposals) * 100)
        : 0;

    const globalCompletionRate =
      acceptedProposalsTotal > 0
        ? Math.round((globalCompleted / acceptedProposalsTotal) * 100)
        : 0;

    let globalAvgDeliveryTime = 0;
    if (globalDeliveryTimes.length > 0) {
      const totalDiffMinutes = globalDeliveryTimes.reduce((sum, order) => {
        const diffMs =
          order.delivered_at!.getTime() - order.offer_accepted_at!.getTime();
        return sum + diffMs / (1000 * 60);
      }, 0);
      globalAvgDeliveryTime = Math.round(
        totalDiffMinutes / globalDeliveryTimes.length,
      );
    }

    // Define date filters for different entities (omitted when no dates provided = all data)
    const dateRange = start && end ? { gte: start, lte: end } : null;

    // step: get period-specific stats
    const [
      periodOrders,
      periodEarnings,
      periodProposals,
      acceptedProposals,
      dailyEarnings,
      areaPerformance,
    ] = await Promise.all([
      // Orders in period (completed + cancelled)
      prisma.order.groupBy({
        by: ["status"],
        where: {
          courier_id: courier.id,
          ...(dateRange && { created_at: dateRange }),
          status: { in: [OrderStatus.DELIVERED, OrderStatus.CANCELLED] },
        },
        _count: true,
      }),
      // Earnings in period
      prisma.order.aggregate({
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          ...(dateRange && { delivered_at: dateRange }),
        },
        _sum: { courier_fee: true },
      }),
      // Total proposals in period
      prisma.orderProposal.count({
        where: {
          courier_id: courier.id,
          ...(dateRange && { created_at: dateRange }),
        },
      }),
      // Accepted proposals in period
      prisma.orderProposal.count({
        where: {
          courier_id: courier.id,
          status: "ACCEPTED",
          ...(dateRange && { created_at: dateRange }),
        },
      }),
      // Daily earnings for chart
      prisma.order.groupBy({
        by: ["delivered_at"],
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          ...(dateRange && { delivered_at: dateRange }),
        },
        _sum: { courier_fee: true },
        _count: true,
      }),
      // Best performing areas
      prisma.order.groupBy({
        by: ["pickup_area_id"],
        where: {
          courier_id: courier.id,
          status: OrderStatus.DELIVERED,
          ...(dateRange && { delivered_at: dateRange }),
        },
        _count: true,
        _sum: { courier_fee: true },
      }),
    ]);

    // step: calculate period statistics
    const completedInPeriod =
      periodOrders.find((o) => o.status === OrderStatus.DELIVERED)?._count || 0;
    const cancelledInPeriod =
      periodOrders.find((o) => o.status === OrderStatus.CANCELLED)?._count || 0;

    // step: sort areas by order count and take top 5
    const sortedAreaPerformance = areaPerformance
      .sort((a, b) => b._count - a._count)
      .slice(0, 5);

    // step: get area details for best performing areas
    const areaIds = sortedAreaPerformance
      .map((a) => a.pickup_area_id)
      .filter((id): id is number => id !== null);
    const areas = await prisma.area.findMany({
      where: { id: { in: areaIds } },
      select: { id: true, name: true, name_ar: true },
    });

    const bestAreas = sortedAreaPerformance.map((a) => {
      const area = areas.find((ar) => ar.id === a.pickup_area_id);
      return {
        area_id: a.pickup_area_id,
        area_name: area?.name || "Unknown",
        area_name_ar: area?.name_ar || "غير معروف",
        orders_count: a._count,
        earnings: Number(a._sum?.courier_fee || 0),
      };
    });

    // step: format daily earnings for chart
    const earningsChart = dailyEarnings.map((d) => ({
      date: d.delivered_at,
      earnings: Number(d._sum?.courier_fee || 0),
      orders_count: d._count,
    }));

    return responseHandler({
      res,
      message: res.__("messages.performance_retrieved"),
      data: {
        statistics: {
          total_completed_orders: globalCompleted,
          total_cancelled_orders: globalCancelled,
          average_rating: Number(globalReviews._avg.rating || 0),
          total_reviews: globalReviews._count,
          acceptance_rate: globalAcceptanceRate,
          completion_rate: globalCompletionRate,
          avg_delivery_time: globalAvgDeliveryTime,
        },
        period_stats: {
          completed_orders: completedInPeriod,
          cancelled_orders: cancelledInPeriod,
          earnings: Number(periodEarnings._sum.courier_fee || 0),
          total_proposals: periodProposals,
          accepted_proposals: acceptedProposals,
          acceptance_rate:
            periodProposals > 0
              ? Math.round((acceptedProposals / periodProposals) * 100)
              : 0,
          completion_rate:
            acceptedProposals > 0
              ? Math.round((completedInPeriod / acceptedProposals) * 100)
              : 0,
        },
        analytics: {
          earnings_chart: earningsChart,
          best_performing_areas: bestAreas,
        },
      },
    });
  };
}
