import axiosInstance from "@/lib/axios";
import { Order, PaginatedOrdersResponse } from "@/types/order";

const STATS_INCLUDES = [
  "pickup_area",
  "delivery_area",
  "proposals",
  "courier",
].join(",");

export interface SellerStats {
  id: number;
  user_id: number;
  seller_commission_per_order: string;
  seller_commission_per_courier_download: string;
  seller_commission_per_customer_download: string;
  stats: {
    total_orders: number;
    total_pending_orders: number;
    total_in_progress_orders: number;
    total_delivered_orders: number;
    total_cancelled_orders: number;
    total_searching_failed_orders: number;
    total_expired_orders: number;
  };
}

export interface SellersStatsResponse {
  sellers: SellerStats[];
  pagination: {
    total: number;
    totalPages: number;
    page: number;
    limit: number;
  };
}

export const statisticsService = {
  fetchOrdersStatsSource: async (): Promise<Order[]> => {
    const limit = 100;
    let page = 1;
    let totalPages = 1;
    const collectedOrders: Order[] = [];

    do {
      const skip = (page - 1) * limit;
      const params = new URLSearchParams();

      params.append("limit", limit.toString());
      params.append("skip", skip.toString());
      params.append("sort", "-created_at");
      params.append("includes", STATS_INCLUDES);

      const response = await axiosInstance.get(
        `/admin/orders?${params.toString()}`,
      );
      const data = response.data as PaginatedOrdersResponse & {
        total_pages?: number;
      };

      collectedOrders.push(...(data.orders || []));
      totalPages = data.totalPages || data.total_pages || 1;
      page += 1;
    } while (page <= totalPages);

    return collectedOrders;
  },

  fetchSellersStats: async (): Promise<SellersStatsResponse> => {
    const response = await axiosInstance.get(
      "/admin/manage-seller/list-sellers-stat",
    );
    return response.data.data || response.data;
  },

  fetchCustomerTotalUsers: async (): Promise<number> => {
    const response = await axiosInstance.get("/users?role_id=3");
    return response.data.totalUsers || 0;
  },

  fetchCustomerTotalOrders: async (): Promise<number> => {
    const response = await axiosInstance.get(
      "/admin/orders?limit=0&skip=0&customer[role_id]=3",
    );
    return response.data.totalOrders || 0;
  },

  fetchCustomerOrdersByStatus: async (status: string): Promise<number> => {
    const response = await axiosInstance.get(
      `/users?role_id=3&orders[some][status]=${status}`,
    );
    return response.data.totalUsers || 0;
  },
};
