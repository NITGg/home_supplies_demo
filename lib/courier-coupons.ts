import api from "./api";

export interface CourierCoupon {
  id: number;
  title: string;
  title_ar?: string | null;
  description?: string | null;
  description_ar?: string | null;
  price: number;
  bonus_courier_fee: number;
  duration_days: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}
export interface CourierCouponsResponse { total: number; total_pages: number; coupons: CourierCoupon[]; }

export async function fetchCourierCoupons(params?: Record<string, string | number>) {
  const { page = 1, limit = 12, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<{ data: CourierCouponsResponse }>("/admin/courier-coupons", { params: { limit, skip, ...rest } });
  return res.data.data;
}
export async function createCourierCoupon(data: {
  title: string; title_ar?: string; description?: string; description_ar?: string;
  price: number; bonus_courier_fee: number; duration_days: number; is_active?: boolean;
}) {
  const res = await api.post("/admin/courier-coupons", data);
  return res.data;
}
export async function updateCourierCoupon(id: number, data: Partial<{
  title: string; title_ar: string; description: string; description_ar: string;
  price: number; bonus_courier_fee: number; duration_days: number; is_active: boolean;
}>) {
  const res = await api.put(`/admin/courier-coupons/${id}`, data);
  return res.data;
}
export async function deleteCourierCoupon(id: number, archived = false) {
  const res = await api.delete(`/admin/courier-coupons/${id}`, { data: { archived } });
  return res.data;
}
export async function bulkDeleteCourierCoupons(ids: number[], archived = false) {
  const res = await api.delete("/admin/courier-coupons", { data: { ids, archived } });
  return res.data;
}
