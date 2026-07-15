import axiosInstance from "@/lib/axios";
import {
  CourierLocation,
  Order,
  OrderFilter,
  PaginatedOrdersResponse,
  UpdateOrderPayload,
} from "@/types/order";

// Fields that are stored in cents but displayed in EG
const CENTS_FIELDS = [
  "budget",
  "total_fee",
  "actual_price",
  "courier_fee",
  "platform_fee",
  "discount_amount",
  "payable_amount",
  "cancellation_fee",
];

const ORDER_INCLUDES = [
  "customer",
  "courier",
  "pickup_area",
  "delivery_area",
  "coupon",
  "proposals",
  "courierReviews",
  "customerReviews",
  "unpaidCommission",
  "escrows",
  "transactions",
].join(",");

const appendDateRange = (
  params: URLSearchParams,
  apiField: string,
  from?: string,
  to?: string,
) => {
  if (from) params.append(`${apiField}[gte]`, from);
  if (to) params.append(`${apiField}[lte]`, to);
};

const egToCents = (value: string): string => {
  const num = parseFloat(value);
  if (isNaN(num)) return value;
  return Math.round(num * 100).toString();
};

const appendNumericRange = (
  params: URLSearchParams,
  apiField: string,
  from?: string,
  to?: string,
  convertToCents = false,
) => {
  if (from) {
    const convertedValue = convertToCents ? egToCents(from) : from;
    params.append(`${apiField}[gte]`, convertedValue);
  }
  if (to) {
    const convertedValue = convertToCents ? egToCents(to) : to;
    params.append(`${apiField}[lte]`, convertedValue);
  }
};

export const orderService = {
  fetchAssignedCourierIds: async (): Promise<number[]> => {
    const params = new URLSearchParams();
    params.append("limit", "0");
    params.append("skip", "0");
    params.append("status", "IN_PROGRESS");
    params.append("includes", "courier=user_id");

    try {
      const response = await axiosInstance.get(
        `/admin/orders?${params.toString()}`,
      );
      const orders = response.data?.orders || response.data || [];

      // Extract unique courier user_ids
      const courierIds = new Set<number>();
      orders.forEach((order: Order) => {
        if (order.courier?.user_id) {
          courierIds.add(order.courier.user_id);
        }
      });

      return Array.from(courierIds);
    } catch (error) {
      console.error("Error fetching assigned courier IDs:", error);
      return [];
    }
  },

  fetchOrders: async (
    page: number = 1,
    limit: number = 10,
    filters: Partial<OrderFilter> = {},
  ): Promise<PaginatedOrdersResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", filters.sort || "-created_at");
    params.append("includes", ORDER_INCLUDES);

    if (filters.id) params.append("id", filters.id);
    if (filters.customer_id) params.append("customer_id", filters.customer_id);
    if (filters.courier_id) params.append("courier_id", filters.courier_id);
    if (filters.order_number) {
      params.append("order_number[contains]", filters.order_number.trim());
    }
    if (filters.pickup_area_id) {
      params.append("pickup_area_id", filters.pickup_area_id);
    }
    if (filters.delivery_area_id) {
      params.append("delivery_area_id", filters.delivery_area_id);
    }
    if (filters.coupon_id) params.append("coupon_id", filters.coupon_id);
    if (filters.price_adjustment_status) {
      params.append("price_adjustment_status", filters.price_adjustment_status);
    }
    if (filters.payment_method) {
      params.append("payment_method", filters.payment_method);
    }
    if (filters.status) params.append("status", filters.status);

    appendNumericRange(
      params,
      "budget",
      filters.budgetFrom,
      filters.budgetTo,
      true,
    );
    appendNumericRange(
      params,
      "actual_price",
      filters.actual_priceFrom,
      filters.actual_priceTo,
      true,
    );
    appendNumericRange(
      params,
      "total_fee",
      filters.total_feeFrom,
      filters.total_feeTo,
      true,
    );
    appendNumericRange(
      params,
      "courier_fee",
      filters.courier_feeFrom,
      filters.courier_feeTo,
      true,
    );
    appendNumericRange(
      params,
      "platform_fee",
      filters.platform_feeFrom,
      filters.platform_feeTo,
      true,
    );
    appendNumericRange(
      params,
      "discount_amount",
      filters.discount_amountFrom,
      filters.discount_amountTo,
      true,
    );
    appendNumericRange(
      params,
      "payable_amount",
      filters.payable_amountFrom,
      filters.payable_amountTo,
      true,
    );
    appendNumericRange(
      params,
      "cancellation_fee",
      filters.cancellation_feeFrom,
      filters.cancellation_feeTo,
      true,
    );
    appendNumericRange(
      params,
      "estemated_delivery_fee",
      filters.estemated_delivery_feeFrom,
      filters.estemated_delivery_feeTo,
      true,
    );

    appendDateRange(
      params,
      "proposed_at",
      filters.proposed_atFrom,
      filters.proposed_atTo,
    );
    appendDateRange(
      params,
      "price_adjusted_at",
      filters.price_adjusted_atFrom,
      filters.price_adjusted_atTo,
    );
    appendDateRange(
      params,
      "created_at",
      filters.created_atFrom,
      filters.created_atTo,
    );
    appendDateRange(
      params,
      "update_at",
      filters.update_atFrom,
      filters.update_atTo,
    );
    appendDateRange(
      params,
      "offer_accepted_at",
      filters.offer_accepted_atFrom,
      filters.offer_accepted_atTo,
    );
    appendDateRange(
      params,
      "delivered_at",
      filters.delivered_atFrom,
      filters.delivered_atTo,
    );
    appendDateRange(
      params,
      "canceled_at",
      filters.canceled_atFrom,
      filters.canceled_atTo,
    );
    appendDateRange(
      params,
      "order_collected_at",
      filters.order_collected_atFrom,
      filters.order_collected_atTo,
    );

    if (filters.cancelled_by) {
      params.append("cancelled_by", filters.cancelled_by);
    }

    if (filters.customer_name) {
      params.append(
        "customer[full_name][contains]",
        filters.customer_name.trim(),
      );
    }
    if (filters.pickup_area_name) {
      params.append(
        "pickup_area[name][contains]",
        filters.pickup_area_name.trim(),
      );
    }
    if (filters.delivery_area_name) {
      params.append(
        "delivery_area[name][contains]",
        filters.delivery_area_name.trim(),
      );
    }
    if (filters.coupon_title) {
      params.append("coupon[title][contains]", filters.coupon_title.trim());
    }

    if (filters.created_by_role_id) {
      params.append("customer[role_id]", filters.created_by_role_id);
    }

    if (filters.has_proposals === "yes") {
      params.append("proposals[some][id][gt]", "0");
    } else if (filters.has_proposals === "no") {
      params.append("proposals[none][id][gt]", "0");
    }

    const response = await axiosInstance.get(
      `/admin/orders?${params.toString()}`,
    );
    return response.data;
  },

  fetchOrderDetails: async (id: number): Promise<Order> => {
    const response = await axiosInstance.get(
      `/admin/orders/${id}?includes=${ORDER_INCLUDES}`,
    );
    return response.data?.order || response.data?.data || response.data;
  },

  deleteOrder: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/orders/${id}`);
  },

  updateOrder: async (
    id: number,
    payload: UpdateOrderPayload,
  ): Promise<Order> => {
    const response = await axiosInstance.put(`/admin/orders/${id}`, payload);
    return response.data?.order || response.data?.data || response.data;
  },

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
      params.append("includes", "pickup_area,delivery_area,proposals,courier");

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

  fetchAllOrders: async (): Promise<Order[]> => {
    const response = await axiosInstance.get("/admin/orders?limit=1000&skip=0");
    return response.data?.orders || [];
  },
  // in orderService
  async fetchCourierLocation(orderId: number): Promise<CourierLocation | null> {
    const res = await axiosInstance.get(`/orders/${orderId}/courier-location`);
    return res.data.location
      ? {
          ...res.data.location,
          lat: +res.data.location.lat,
          lng: +res.data.location.lng,
        }
      : null;
  },
};
