import api from "./api";

export interface CancellationReason {
  id: number;
  role_id: number;
  reason_en: string;
  reason_ar: string;
  created_at: string;
  updated_at: string;
}
export interface CancellationReasonsResponse { totalReasons: number; totalPages: number; reasons: CancellationReason[]; }

export async function fetchCancellationReasons(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<{ data: CancellationReasonsResponse }>("/admin/cancellation-reason/all-reasons", { params: { limit, skip, ...rest } });
  return res.data.data;
}
export async function createCancellationReason(data: { role_id: number | string; reason_en: string; reason_ar: string }) {
  // Backend validation expects role_id as a numeric string
  const res = await api.post("/admin/cancellation-reason/reason", {
    ...data,
    role_id: String(data.role_id),
  });
  return res.data;
}
export async function updateCancellationReason(id: number, data: { reason_en?: string; reason_ar?: string }) {
  const res = await api.put(`/admin/cancellation-reason/update-reason/${id}`, data);
  return res.data;
}
export async function deleteCancellationReason(id: number) {
  const res = await api.delete(`/admin/cancellation-reason/delete-reason/${id}`);
  return res.data;
}
