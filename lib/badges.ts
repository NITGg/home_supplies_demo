import api from "./api";

export interface Badge {
  id: number;
  role_id: number;
  name: string;
  name_ar: string;
  image?: string | null;
  description?: string | null;
  description_ar?: string | null;
  min_count: number;
  max_count: number;
  ratio: number;
  created_at: string;
  updated_at: string;
}
export interface BadgesResponse { totalBadges: number; totalPages: number; badges: Badge[]; }

export async function fetchBadges(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<BadgesResponse>("/badges", { params: { limit, skip, ...rest } });
  return res.data;
}
export async function createBadge(data: FormData) {
  const res = await api.post("/badges", data, { headers: { "Content-Type": "multipart/form-data" } });
  return res.data;
}
export async function updateBadge(id: number, data: FormData) {
  const res = await api.put(`/badges/${id}`, data, { headers: { "Content-Type": "multipart/form-data" } });
  return res.data;
}
export async function deleteBadge(id: number) {
  const res = await api.delete(`/badges/${id}`);
  return res.data;
}
export async function bulkDeleteBadges(ids: number[]) {
  const res = await api.delete("/badges", { data: { ids } });
  return res.data;
}
