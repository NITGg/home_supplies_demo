import { NextFunction, Request, Response } from "express";
import { OrderStatus } from "@prisma/client";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";
import FeatureApi from "../../utils/featureApi";

export class StatService {
  constructor() {}

  // ============================ allStat ============================
  allStat = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // Step: Get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });

    if (!supplier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_supplier"),
      );
    }

    // Step: Parse date range filters
    const queryOptions = new FeatureApi(req).filter(
      {},
      {
        allowKeys: ["created_at[gte]", "created_at[lte]"],
      },
    ).data;

    let dateRange: { gte?: Date; lte?: Date } | null = null;
    if (queryOptions.where?.created_at) {
      dateRange = queryOptions.where.created_at as any;
    }

    // Step: Calculate date ranges for periods
    const now = new Date();
    const todayStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - ((weekStart.getDay() + 1) % 7));
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const yearStart = new Date(now.getFullYear(), 0, 1);

    // Step: Fetch all statistics in parallel
    const [
      // Order statistics
      allOrders,
      deliveredOrders,
      cancelledOrders,
      pendingOrders,
      inProgressOrders,
      todayOrders,
      weekOrders,
      monthOrders,
      yearOrders,
      lastOrder,
      orderValueSum,

      // Product statistics
      totalProducts,
      activeProducts,
      featuredProducts,
      bestSellerProducts,
      lowStockProducts,
      productsByCategory,

      // Revenue statistics
      totalRevenue,
      todayRevenue,
      weekRevenue,
      monthRevenue,
      yearRevenue,
      revenueByProduct,

      // Customer statistics
      uniqueCustomers,
      allCustomerOrders,

      // Review statistics
      customerReviews,
      courierReviews,

      // Refund statistics
      refundsByStatus,
      totalRefundAmount,

      // Wallet statistics
      wallet,
      earningsTransactions,
      withdrawalTransactions,
      pendingTransactions,
    ] = await Promise.all([
      // Order statistics
      prisma.order.count({ where: { supplier_id: supplier.id } }),
      prisma.order.count({
        where: { supplier_id: supplier.id, status: OrderStatus.DELIVERED },
      }),
      prisma.order.count({
        where: { supplier_id: supplier.id, status: OrderStatus.CANCELLED },
      }),
      prisma.order.count({
        where: { supplier_id: supplier.id, status: OrderStatus.PENDING },
      }),
      prisma.order.count({
        where: { supplier_id: supplier.id, status: OrderStatus.IN_PROGRESS },
      }),
      prisma.order.count({
        where: {
          supplier_id: supplier.id,
          created_at: { gte: todayStart },
        },
      }),
      prisma.order.count({
        where: {
          supplier_id: supplier.id,
          created_at: { gte: weekStart },
        },
      }),
      prisma.order.count({
        where: {
          supplier_id: supplier.id,
          created_at: { gte: monthStart },
        },
      }),
      prisma.order.count({
        where: {
          supplier_id: supplier.id,
          created_at: { gte: yearStart },
        },
      }),
      prisma.order.findFirst({
        where: { supplier_id: supplier.id },
        orderBy: { created_at: "desc" },
        select: { created_at: true },
      }),
      prisma.order.aggregate({
        where: { supplier_id: supplier.id, actual_price: { not: null } },
        _sum: { actual_price: true },
        _count: true,
      }),

      // Product statistics
      prisma.supplierProduct.count({ where: { supplier_id: supplier.id } }),
      prisma.supplierProduct.count({
        where: { supplier_id: supplier.id, is_active: true },
      }),
      prisma.supplierProduct.count({
        where: { supplier_id: supplier.id, is_featured: true },
      }),
      prisma.supplierProduct.count({
        where: { supplier_id: supplier.id, is_best_seller: true },
      }),
      prisma.supplierProduct.findMany({
        where: { supplier_id: supplier.id },
        select: { id: true, stock: true, min_stock: true },
      }),
      prisma.supplierProduct.groupBy({
        by: ["product_id"],
        where: { supplier_id: supplier.id },
        _count: true,
      }),

      // Revenue statistics
      prisma.order.aggregate({
        where: {
          supplier_id: supplier.id,
          status: OrderStatus.DELIVERED,
          actual_price: { not: null },
        },
        _sum: { actual_price: true },
      }),
      prisma.order.aggregate({
        where: {
          supplier_id: supplier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: todayStart },
          actual_price: { not: null },
        },
        _sum: { actual_price: true },
      }),
      prisma.order.aggregate({
        where: {
          supplier_id: supplier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: weekStart },
          actual_price: { not: null },
        },
        _sum: { actual_price: true },
      }),
      prisma.order.aggregate({
        where: {
          supplier_id: supplier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: monthStart },
          actual_price: { not: null },
        },
        _sum: { actual_price: true },
      }),
      prisma.order.aggregate({
        where: {
          supplier_id: supplier.id,
          status: OrderStatus.DELIVERED,
          delivered_at: { gte: yearStart },
          actual_price: { not: null },
        },
        _sum: { actual_price: true },
      }),
      prisma.order.groupBy({
        by: ["id"],
        where: {
          supplier_id: supplier.id,
          status: OrderStatus.DELIVERED,
          actual_price: { not: null },
        },
        _sum: { actual_price: true },
      }),

      // Customer statistics
      prisma.order.groupBy({
        by: ["customer_id"],
        where: { supplier_id: supplier.id, customer_id: { not: null } },
        _count: true,
      }),
      prisma.order.groupBy({
        by: ["customer_id"],
        where: { supplier_id: supplier.id, customer_id: { not: null } },
        _count: true,
      }),

      // Review statistics
      prisma.supplierReviewFromCustomer.aggregate({
        where: { supplier_id: supplier.id },
        _avg: { rating: true },
        _count: true,
      }),
      prisma.supplierReviewFromCourier.aggregate({
        where: { supplier_id: supplier.id },
        _avg: { rating: true },
        _count: true,
      }),

      // Refund statistics
      prisma.refund.groupBy({
        by: ["status"],
        where: {
          order: { supplier_id: supplier.id },
        },
        _count: true,
      }),
      prisma.refund.aggregate({
        where: {
          order: { supplier_id: supplier.id },
        },
        _sum: { amount: true },
      }),

      // Wallet statistics
      prisma.wallet.findFirst({
        where: { user_id: user.id, owner_type: "SUPPLIER" },
      }),
      prisma.transaction.count({
        where: {
          wallet: { user_id: user.id, owner_type: "SUPPLIER" },
          type: "ESCROW_RELEASE",
          status: "COMPLETED",
        },
      }),
      prisma.transaction.count({
        where: {
          wallet: { user_id: user.id, owner_type: "SUPPLIER" },
          type: "WITHDRAWAL",
          status: "COMPLETED",
        },
      }),
      prisma.transaction.count({
        where: {
          wallet: { user_id: user.id, owner_type: "SUPPLIER" },
          status: "PENDING",
        },
      }),
    ]);

    // Step: Calculate derived statistics
    const lowStockCount = lowStockProducts.filter(
      (p) => p.stock < p.min_stock,
    ).length;
    const averageOrderValue =
      orderValueSum._count > 0
        ? Number(orderValueSum._sum.actual_price || 0) / orderValueSum._count
        : 0;
    const totalUniqueCustomers = uniqueCustomers.length;
    const repeatCustomers = allCustomerOrders.filter(
      (c) => c._count > 1,
    ).length;
    const repeatCustomerRate =
      totalUniqueCustomers > 0
        ? (repeatCustomers / totalUniqueCustomers) * 100
        : 0;
    const completionRate =
      allOrders > 0 ? (deliveredOrders / allOrders) * 100 : 0;
    const cancellationRate =
      allOrders > 0 ? (cancelledOrders / allOrders) * 100 : 0;
    const totalCustomerReviews = customerReviews._count;
    const totalCourierReviews = courierReviews._count;
    const totalReviews = totalCustomerReviews + totalCourierReviews;
    const overallAvgRating =
      totalReviews > 0
        ? (Number(customerReviews._avg.rating || 0) * totalCustomerReviews +
            Number(courierReviews._avg.rating || 0) * totalCourierReviews) /
          totalReviews
        : 0;

    // Step: Get product and category details
    const productIds = productsByCategory.map((p) => p.product_id);
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: {
        id: true,
        name: true,
        name_ar: true,
        category_id: true,
        brand_id: true,
      },
    });

    const categoryIds = [...new Set(products.map((p) => p.category_id))];
    const categories = await prisma.category.findMany({
      where: { id: { in: categoryIds } },
      select: { id: true, name: true, name_ar: true },
    });

    const brandIds = [
      ...new Set(
        products
          .map((p) => p.brand_id)
          .filter((id): id is number => id !== null),
      ),
    ];
    const brands = await prisma.brand.findMany({
      where: { id: { in: brandIds } },
      select: { id: true, name: true, name_ar: true },
    });

    // Step: Build category statistics
    const categoryStats = categoryIds.map((catId) => {
      const catProducts = products.filter((p) => p.category_id === catId);
      const category = categories.find((c) => c.id === catId);
      return {
        category_id: catId,
        category_name: category?.name || "Unknown",
        category_name_ar: category?.name_ar || "Unknown",
        count: catProducts.length,
      };
    });

    // Step: Build brand statistics
    const brandStats = brandIds.map((brandId) => {
      const brandProducts = products.filter((p) => p.brand_id === brandId);
      const brand = brands.find((b) => b.id === brandId);
      return {
        brand_id: brandId,
        brand_name: brand?.name || "Unknown",
        brand_name_ar: brand?.name_ar || "Unknown",
        count: brandProducts.length,
      };
    });

    // Step: Build revenue by product
    const revenueByProductData = revenueByProduct
      .map((r: any) => {
        const product = products.find((p) => p.id === r.id);
        return {
          product_id: r.id,
          product_name: product?.name || "Unknown",
          product_name_ar: product?.name_ar || "Unknown",
          revenue: Number(r._sum.actual_price || 0),
        };
      })
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 10);

    // Step: Build revenue by category
    const categoryRevenueMap = new Map<number, number>();
    revenueByProduct.forEach((r: any) => {
      const product = products.find((p) => p.id === r.id);
      if (product && product.category_id) {
        const current = categoryRevenueMap.get(product.category_id) || 0;
        categoryRevenueMap.set(
          product.category_id,
          current + Number(r._sum.actual_price || 0),
        );
      }
    });

    const revenueByCategoryData = Array.from(categoryRevenueMap.entries())
      .map(([catId, revenue]) => {
        const category = categories.find((c) => c.id === catId);
        return {
          category_id: catId,
          category_name: category?.name || "Unknown",
          category_name_ar: category?.name_ar || "Unknown",
          revenue,
        };
      })
      .sort((a, b) => b.revenue - a.revenue);

    // Step: Build refunds by status
    const refundsByStatusData = refundsByStatus.map((r: any) => ({
      status: r.status,
      count: r._count,
    }));

    return responseHandler({
      res,
      message: res.__("messages.all_statistics_retrieved"),
      data: {
        filter_info: {
          date_range: {
            start_date: dateRange?.gte || null,
            end_date: dateRange?.lte || null,
            is_filtered: dateRange !== null,
          },
          description: dateRange
            ? `Statistics filtered from ${dateRange.gte?.toISOString()} to ${dateRange.lte?.toISOString()}`
            : "Statistics show all-time data (no date filter applied)",
        },
        order_stats: {
          total_orders: allOrders,
          delivered_orders: deliveredOrders,
          cancelled_orders: cancelledOrders,
          pending_orders: pendingOrders,
          in_progress_orders: inProgressOrders,
          today_orders: todayOrders,
          this_week_orders: weekOrders,
          this_month_orders: monthOrders,
          this_year_orders: yearOrders,
          last_order_date: lastOrder?.created_at || null,
          average_order_value: Math.round(averageOrderValue * 100) / 100,
        },
        product_stats: {
          total_products: totalProducts,
          active_products: activeProducts,
          featured_products: featuredProducts,
          best_seller_products: bestSellerProducts,
          low_stock_products: lowStockCount,
          products_by_category: categoryStats,
          products_by_brand: brandStats,
        },
        revenue_stats: {
          total_revenue: Number(totalRevenue._sum.actual_price || 0),
          today_revenue: Number(todayRevenue._sum.actual_price || 0),
          this_week_revenue: Number(weekRevenue._sum.actual_price || 0),
          this_month_revenue: Number(monthRevenue._sum.actual_price || 0),
          this_year_revenue: Number(yearRevenue._sum.actual_price || 0),
          revenue_by_product: revenueByProductData,
          revenue_by_category: revenueByCategoryData,
        },
        customer_stats: {
          total_unique_customers: totalUniqueCustomers,
          repeat_customers: repeatCustomers,
          repeat_customer_rate: Math.round(repeatCustomerRate * 100) / 100,
        },
        review_stats: {
          avg_customer_rating:
            Math.round(Number(customerReviews._avg.rating || 0) * 100) / 100,
          total_customer_reviews: totalCustomerReviews,
          avg_courier_rating:
            Math.round(Number(courierReviews._avg.rating || 0) * 100) / 100,
          total_courier_reviews: totalCourierReviews,
          overall_avg_rating: Math.round(overallAvgRating * 100) / 100,
          total_reviews: totalReviews,
        },
        refund_stats: {
          total_refunds: refundsByStatus.reduce((sum, r) => sum + r._count, 0),
          total_refund_amount: Number(totalRefundAmount._sum.amount || 0),
          refunds_by_status: refundsByStatusData,
        },
        wallet_stats: {
          current_balance: wallet?.balance || 0,
          total_earnings: earningsTransactions,
          total_withdrawals: withdrawalTransactions,
          pending_transactions: pendingTransactions,
        },
        performance_metrics: {
          completion_rate: Math.round(completionRate * 100) / 100,
          cancellation_rate: Math.round(cancellationRate * 100) / 100,
          overall_rating: Math.round(overallAvgRating * 100) / 100,
        },
      },
    });
  };
}
