import api from "./api";

/** Unified review shape returned by all three /admin/supplier-reviews/ list endpoints. */
export interface Review {
  id: number;
  supplier_id?: number | null;
  user_id?: number | null;
  courier_id?: number | null;
  order_id?: number | null;
  rating: number;
  comment?: string | null;
  created_at: string;
  updated_at?: string;
  source: string;
  user?: { full_name: string } | null;
  courier?: { user: { full_name: string } } | null;
  supplier?: { user: { full_name: string } } | null;
}
export interface ReviewsResponse { totalReviews: number; totalPages: number; reviews: Review[]; }

/* ── Customer reviews (about customers, from couriers) ────────────────── */

export async function fetchCustomerReviews(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<ReviewsResponse>("/admin/supplier-reviews/list-customer-reviews", { params: { limit, skip, ...rest } });
  return res.data;
}
export async function deleteCustomerReview(id: number, reviewFrom: string) {
  const res = await api.delete(`/admin/supplier-reviews/delete-supplier-review/${id}`, { data: { review_from: reviewFrom } });
  return res.data;
}

/* ── Courier reviews (about couriers, from customers + suppliers) ─────── */

export async function fetchCourierReviews(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<ReviewsResponse>("/admin/supplier-reviews/list-courier-reviews", { params: { limit, skip, ...rest } });
  return res.data;
}
export async function deleteCourierReview(id: number, reviewFrom: string) {
  const res = await api.delete(`/admin/supplier-reviews/delete-supplier-review/${id}`, { data: { review_from: reviewFrom } });
  return res.data;
}

/* ── Supplier reviews (about suppliers, from customers + couriers) ────── */

export async function fetchSupplierReviews(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<ReviewsResponse>("/admin/supplier-reviews/list-supplier-reviews", { params: { limit, skip, ...rest } });
  return res.data;
}
export async function deleteSupplierReview(id: number, reviewFrom: string) {
  const res = await api.delete(`/admin/supplier-reviews/delete-supplier-review/${id}`, { data: { review_from: reviewFrom } });
  return res.data;
}
