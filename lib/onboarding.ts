import api from "./api";

export type OnboardingTarget = "CUSTOMER" | "COURIER" | "ALL";

export interface OnboardingItem {
  id: number;
  image_url?: string | null;
  title: string;
  title_ar?: string | null;
  content?: string | null;
  content_ar?: string | null;
  subtitle?: string | null;
  subtitle_ar?: string | null;
  sort_id?: number | null;
  target_user?: OnboardingTarget | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}
export interface OnboardingResponse { total: number; total_pages: number; items: OnboardingItem[]; }

export async function fetchOnboarding(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<{ data: OnboardingResponse }>("/admin/on-boarding", { params: { limit, skip, ...rest } });
  return res.data.data;
}
export async function createOnboarding(data: FormData) {
  const res = await api.post("/admin/on-boarding", data, { headers: { "Content-Type": "multipart/form-data" } });
  return res.data;
}
export async function updateOnboarding(id: number, data: FormData) {
  const res = await api.put(`/admin/on-boarding/${id}`, data, { headers: { "Content-Type": "multipart/form-data" } });
  return res.data;
}
export async function deleteOnboarding(id: number, archived = false) {
  const res = await api.delete(`/admin/on-boarding/${id}`, { data: { archived } });
  return res.data;
}
export async function bulkDeleteOnboarding(ids: number[], archived = false) {
  const res = await api.delete("/admin/on-boarding", { data: { ids, archived } });
  return res.data;
}
