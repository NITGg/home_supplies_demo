import axiosInstance from "@/lib/axios";
import {
  PaginatedCourierCouponsResponse,
  CourierCouponFilter,
  CourierCoupon,
  CreateCourierCouponPayload,
  UpdateCourierCouponPayload,
  PaginatedCourierCouponUsagesResponse,
  CourierCouponUsageFilter,
  CourierCouponUsage,
  PaginatedCustomerCouponsResponse,
  CustomerCouponFilter,
  CustomerCoupon,
  CreateCustomerCouponPayload,
  UpdateCustomerCouponPayload,
  PaginatedCustomerCouponUsagesResponse,
  CustomerCouponUsageFilter,
  CustomerCouponUsage,
} from "@/types/coupon";
import { toCentsOrEgp } from "@/utils/toCentsOrEgp";

export const couponService = {
  // Courier Coupons
  fetchCourierCoupons: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<CourierCouponFilter> = {},
  ): Promise<PaginatedCourierCouponsResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.title) params.append("title[contains]", filters.title.trim());
    if (filters.title_ar)
      params.append("title_ar[contains]", filters.title_ar.trim());
    if (filters.priceFrom)
      params.append("price[gte]", toCentsOrEgp(filters.priceFrom, "toCents"));
    if (filters.priceTo)
      params.append("price[lte]", toCentsOrEgp(filters.priceTo, "toCents"));
    if (filters.bonus_courier_feeFrom)
      params.append(
        "bonus_courier_fee[gte]",
        toCentsOrEgp(filters.bonus_courier_feeFrom, "toCents"),
      );
    if (filters.bonus_courier_feeTo)
      params.append(
        "bonus_courier_fee[lte]",
        toCentsOrEgp(filters.bonus_courier_feeTo, "toCents"),
      );
    if (filters.duration_daysFrom)
      params.append("duration_days[gte]", filters.duration_daysFrom);
    if (filters.duration_daysTo)
      params.append("duration_days[lte]", filters.duration_daysTo);
    if (filters.is_active) params.append("is_active", filters.is_active);
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", `${filters.updated_atFrom}T00:00:00Z`);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", `${filters.updated_atTo}T23:59:59Z`);
    if (filters.deleted_atFrom)
      params.append("deleted_at[gte]", `${filters.deleted_atFrom}T00:00:00Z`);
    if (filters.deleted_atTo)
      params.append("deleted_at[lte]", `${filters.deleted_atTo}T23:59:59Z`);

    const response = await axiosInstance.get(
      `/admin/courier-coupons?${params.toString()}`,
    );
    return response.data;
  },

  fetchCourierCouponDetails: async (
    id: number,
  ): Promise<{ coupon: CourierCoupon }> => {
    const response = await axiosInstance.get(`/admin/courier-coupons/${id}`);
    return response.data;
  },

  createCourierCoupon: async (
    data: CreateCourierCouponPayload,
  ): Promise<CourierCoupon> => {
    const payload = {
      ...data,
      price: Number(toCentsOrEgp(data.price, "toCents")),
    };
    const response = await axiosInstance.post(
      "/admin/courier-coupons",
      payload,
    );
    return response.data;
  },

  updateCourierCoupon: async (
    id: number,
    data: UpdateCourierCouponPayload,
  ): Promise<CourierCoupon> => {
    const payload = { ...data };
    if (data.price !== undefined) {
      payload.price = Number(toCentsOrEgp(data.price, "toCents"));
    }
    const response = await axiosInstance.put(
      `/admin/courier-coupons/${id}`,
      payload,
    );
    return response.data;
  },

  deleteCourierCoupon: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/courier-coupons/${id}`);
  },

  fetchAllCourierCoupons: async (): Promise<CourierCoupon[]> => {
    const response = await axiosInstance.get(
      "/admin/courier-coupons?limit=1000&skip=0",
    );
    return response.data?.coupons || [];
  },

  fetchCourierCouponUsages: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<CourierCouponUsageFilter> = {},
  ): Promise<PaginatedCourierCouponUsagesResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("includes", "user");
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.user_id) params.append("user_id", filters.user_id);
    if (filters.coupon_id) params.append("coupon_id", filters.coupon_id);
    if (filters.user_full_name) {
      params.append("user[full_name][contains]", filters.user_full_name.trim());
    }
    if (filters.snapshot_priceFrom)
      params.append(
        "snapshot_price[gte]",
        toCentsOrEgp(filters.snapshot_priceFrom, "toCents"),
      );
    if (filters.snapshot_priceTo)
      params.append(
        "snapshot_price[lte]",
        toCentsOrEgp(filters.snapshot_priceTo, "toCents"),
      );
    if (filters.snapshot_bonus_courier_feeFrom)
      params.append(
        "snapshot_bonus_courier_fee[gte]",
        toCentsOrEgp(filters.snapshot_bonus_courier_feeFrom, "toCents"),
      );
    if (filters.snapshot_bonus_courier_feeTo)
      params.append(
        "snapshot_bonus_courier_fee[lte]",
        toCentsOrEgp(filters.snapshot_bonus_courier_feeTo, "toCents"),
      );
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);
    if (filters.start_dateFrom)
      params.append("start_date[gte]", `${filters.start_dateFrom}T00:00:00Z`);
    if (filters.start_dateTo)
      params.append("start_date[lte]", `${filters.start_dateTo}T23:59:59Z`);
    if (filters.end_dateFrom)
      params.append("end_date[gte]", `${filters.end_dateFrom}T00:00:00Z`);
    if (filters.end_dateTo)
      params.append("end_date[lte]", `${filters.end_dateTo}T23:59:59Z`);
    if (filters.expiry_reminder_3d_sent_atFrom)
      params.append(
        "expiry_reminder_3d_sent_at[gte]",
        `${filters.expiry_reminder_3d_sent_atFrom}T00:00:00Z`,
      );
    if (filters.expiry_reminder_3d_sent_atTo)
      params.append(
        "expiry_reminder_3d_sent_at[lte]",
        `${filters.expiry_reminder_3d_sent_atTo}T23:59:59Z`,
      );

    const response = await axiosInstance.get(
      `/admin/courier-coupons/usages?${params.toString()}`,
    );
    return response.data;
  },

  fetchAllCourierCouponUsages: async (): Promise<CourierCouponUsage[]> => {
    const response = await axiosInstance.get(
      "/admin/courier-coupons/usages?limit=1000&skip=0&includes=user",
    );
    return response.data?.usages || [];
  },

  // Customer Coupons
  fetchCustomerCoupons: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<CustomerCouponFilter> = {},
  ): Promise<PaginatedCustomerCouponsResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.code) params.append("code[contains]", filters.code.trim());
    if (filters.title) params.append("title[contains]", filters.title.trim());
    if (filters.title_ar)
      params.append("title_ar[contains]", filters.title_ar.trim());
    // 🔥 ADD THESE under title/title_ar
    if (filters.description)
      params.append("description[contains]", filters.description.trim());

    if (filters.description_ar)
      params.append("description_ar[contains]", filters.description_ar.trim());
    if (filters.type) params.append("type", filters.type);
    if (filters.start_atFrom)
      params.append("start_at[gte]", `${filters.start_atFrom}T00:00:00Z`);
    if (filters.start_atTo)
      params.append("start_at[lte]", `${filters.start_atTo}T23:59:59Z`);
    if (filters.end_atFrom)
      params.append("end_at[gte]", `${filters.end_atFrom}T00:00:00Z`);
    if (filters.end_atTo)
      params.append("end_at[lte]", `${filters.end_atTo}T23:59:59Z`);
    if (filters.is_active) params.append("is_active", filters.is_active);
    if (filters.max_total_usesFrom)
      params.append("max_total_uses[gte]", filters.max_total_usesFrom);
    if (filters.max_total_usesTo)
      params.append("max_total_uses[lte]", filters.max_total_usesTo);
    if (filters.max_user_usesFrom)
      params.append("max_user_uses[gte]", filters.max_user_usesFrom);
    if (filters.max_user_usesTo)
      params.append("max_user_uses[lte]", filters.max_user_usesTo);
    if (filters.min_orders_countFrom)
      params.append("min_orders_count[gte]", filters.min_orders_countFrom);
    if (filters.min_orders_countTo)
      params.append("min_orders_count[lte]", filters.min_orders_countTo);
    if (filters.discount_type)
      params.append("discount_type", filters.discount_type);
    if (filters.discount_valueFrom)
      params.append("discount_value[gte]", filters.discount_valueFrom);
    if (filters.discount_valueTo)
      params.append("discount_value[lte]", filters.discount_valueTo);
    if (filters.max_discount_centsFrom)
      params.append(
        "max_discount_cents[gte]",
        toCentsOrEgp(filters.max_discount_centsFrom, "toCents"),
      );
    if (filters.max_discount_centsTo)
      params.append(
        "max_discount_cents[lte]",
        toCentsOrEgp(filters.max_discount_centsTo, "toCents"),
      );
    if (filters.min_order_total_centsFrom)
      params.append(
        "min_order_total_cents[gte]",
        toCentsOrEgp(filters.min_order_total_centsFrom, "toCents"),
      );
    if (filters.min_order_total_centsTo)
      params.append(
        "min_order_total_cents[lte]",
        toCentsOrEgp(filters.min_order_total_centsTo, "toCents"),
      );
    if (filters.wallet_amount_centsFrom)
      params.append(
        "wallet_amount_cents[gte]",
        toCentsOrEgp(filters.wallet_amount_centsFrom, "toCents"),
      );
    if (filters.wallet_amount_centsTo)
      params.append(
        "wallet_amount_cents[lte]",
        toCentsOrEgp(filters.wallet_amount_centsTo, "toCents"),
      );
    if (filters.wallet_pointsFrom)
      params.append("wallet_points[gte]", filters.wallet_pointsFrom);
    if (filters.wallet_pointsTo)
      params.append("wallet_points[lte]", filters.wallet_pointsTo);
    if (filters.is_purchasable)
      params.append("is_purchasable", filters.is_purchasable);
    if (filters.purchase_price_centsFrom)
      params.append(
        "purchase_price_cents[gte]",
        toCentsOrEgp(filters.purchase_price_centsFrom, "toCents"),
      );
    if (filters.purchase_price_centsTo)
      params.append(
        "purchase_price_cents[lte]",
        toCentsOrEgp(filters.purchase_price_centsTo, "toCents"),
      );
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", `${filters.updated_atFrom}T00:00:00Z`);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", `${filters.updated_atTo}T23:59:59Z`);
    if (filters.deleted_atFrom)
      params.append("deleted_at[gte]", `${filters.deleted_atFrom}T00:00:00Z`);
    if (filters.deleted_atTo)
      params.append("deleted_at[lte]", `${filters.deleted_atTo}T23:59:59Z`);
    if (filters.scope) params.append("scope", filters.scope);
    if (filters.is_first) params.append("is_first", filters.is_first);

    const response = await axiosInstance.get(
      `/admin/customer-coupons?${params.toString()}`,
    );
    return response.data;
  },

  fetchCustomerCouponDetails: async (
    id: number,
  ): Promise<{ coupon: CustomerCoupon }> => {
    const response = await axiosInstance.get(`/admin/customer-coupons/${id}`);
    return response.data;
  },

  createCustomerCoupon: async (
    data: FormData, // ← accept FormData directly, the modal already builds it
  ): Promise<CustomerCoupon> => {
    const response = await axiosInstance.post("/admin/customer-coupons", data, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data;
  },

  updateCustomerCoupon: async (
    id: number,
    data: UpdateCustomerCouponPayload,
  ): Promise<CustomerCoupon> => {
    // Use a loose Record to avoid spread type reassignment errors
    const payload: Record<string, unknown> = { ...data };

    if (
      data.max_discount_cents !== undefined &&
      data.max_discount_cents !== null
    ) {
      payload.max_discount_cents = Number(
        toCentsOrEgp(data.max_discount_cents, "toCents"),
      );
    }
    if (
      data.min_order_total_cents !== undefined &&
      data.min_order_total_cents !== null
    ) {
      payload.min_order_total_cents = Number(
        toCentsOrEgp(data.min_order_total_cents, "toCents"),
      );
    }
    if (
      data.wallet_amount_cents !== undefined &&
      data.wallet_amount_cents !== null
    ) {
      payload.wallet_amount_cents = Number(
        toCentsOrEgp(data.wallet_amount_cents, "toCents"),
      );
    }
    if (
      data.purchase_price_cents !== undefined &&
      data.purchase_price_cents !== null
    ) {
      payload.purchase_price_cents = Number(
        toCentsOrEgp(data.purchase_price_cents, "toCents"),
      );
    }

    const response = await axiosInstance.put(
      `/admin/customer-coupons/${id}`,
      payload,
    );
    return response.data;
  },

  deleteCustomerCoupon: async (
    id: number,
    archived: boolean = true,
  ): Promise<void> => {
    await axiosInstance.delete(`/admin/customer-coupons/${id}`, {
      data: { archived },
    });
  },

  fetchAllCustomerCoupons: async (): Promise<CustomerCoupon[]> => {
    const response = await axiosInstance.get(
      "/admin/customer-coupons?limit=1000&skip=0",
    );
    return response.data?.coupons || [];
  },

  fetchCustomerCouponUsages: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<CustomerCouponUsageFilter> = {},
  ): Promise<PaginatedCustomerCouponUsagesResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.user_id) params.append("user_id", filters.user_id);
    if (filters.coupon_id) params.append("coupon_id", filters.coupon_id);
    if (filters.user_full_name) {
      params.append("user[full_name][contains]", filters.user_full_name.trim());
    }
    if (filters.context) params.append("context", filters.context);
    if (filters.order_id) params.append("order_id", filters.order_id);
    if (filters.discount_centsFrom)
      params.append(
        "discount_cents[gte]",
        toCentsOrEgp(filters.discount_centsFrom, "toCents"),
      );
    if (filters.discount_centsTo)
      params.append(
        "discount_cents[lte]",
        toCentsOrEgp(filters.discount_centsTo, "toCents"),
      );
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);

    const response = await axiosInstance.get(
      `/admin/customer-coupons/usages?${params.toString()}`,
    );
    return response.data;
  },

  fetchAllCustomerCouponUsages: async (): Promise<CustomerCouponUsage[]> => {
    const response = await axiosInstance.get(
      "/admin/customer-coupons/usages?limit=1000&skip=0&includes=user",
    );
    return response.data?.usages || [];
  },
};
