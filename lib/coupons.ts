import api from "./api";

export type CouponType = "ORDER_DISCOUNT" | "WALLET_CREDIT";
export type DiscountType = "PERCENT" | "FIXED_CENTS";
export type CouponScope =
  | "ORDER_TOTAL"
  | "DELIVERY_FEE"
  | "PRODUCTS_ONLY"
  | "NOT_APPLICABLE";

export interface Coupon {
  id: number;
  code: string;
  title: string;
  title_ar?: string | null;
  description?: string | null;
  description_ar?: string | null;
  type: CouponType;
  is_active: boolean;
  is_first: boolean;
  discount_type?: DiscountType | null;
  discount_value?: number | null;
  scope: CouponScope;
  wallet_amount_cents: number;
  wallet_points: number;
  max_total_uses?: number | null;
  max_user_uses?: number | null;
  min_orders_count: number;
  max_discount_cents?: number | null;
  min_order_total_cents?: number | null;
  is_purchasable?: boolean;
  purchase_price_cents?: number | null;
  start_at?: string | null;
  end_at?: string | null;
  image_url?: string | null;
  button_text?: string | null;
  button_text_ar?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface CouponsResponse {
  totalCoupons: number;
  totalPages: number;
  coupons: Coupon[];
}

export async function fetchCoupons(params?: Record<string, string | number>) {
  const { page = 1, limit = 12, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<CouponsResponse>("/admin/customer-coupons", {
    params: { limit, skip, ...rest },
  });
  return res.data;
}

export async function fetchCoupon(id: number): Promise<Coupon> {
  const res = await api.get<{ coupon: Coupon }>(
    `/admin/customer-coupons/${id}`,
  );
  return res.data.coupon;
}

export async function createCoupon(data: FormData) {
  const res = await api.post("/admin/customer-coupons", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function updateCoupon(id: number, data: FormData) {
  const res = await api.put(`/admin/customer-coupons/${id}`, data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function deleteCoupon(id: number, archived = false) {
  const res = await api.delete(`/admin/customer-coupons/${id}`, {
    data: { archived },
  });
  return res.data;
}

export async function bulkDeleteCoupons(ids: number[], archived = false) {
  const res = await api.delete("/admin/customer-coupons", {
    data: { ids, archived },
  });
  return res.data;
}
