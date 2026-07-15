import api from "./api";

export type FaqTarget = "CUSTOMER" | "COURIER" | "ALL";

export interface Faq {
  id: number;
  question: string;
  answer: string;
  language?: "EN" | "AR" | null;
  is_active: boolean;
  sort_id?: number | null;
  target_user?: FaqTarget | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}
export interface FaqsResponse { total: number; total_pages: number; faqs: Faq[]; }

export async function fetchFaqs(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<{ data: FaqsResponse }>("/admin/faqs", { params: { limit, skip, ...rest } });
  return res.data.data;
}
export async function createFaq(data: {
  question: string; answer: string; language?: "EN" | "AR";
  is_active?: boolean; sort_id?: number; target_user?: FaqTarget;
}) {
  const res = await api.post("/admin/faqs", data);
  return res.data;
}
export async function updateFaq(id: number, data: Partial<{
  question: string; answer: string; language: "EN" | "AR";
  is_active: boolean; sort_id: number; target_user: FaqTarget;
}>) {
  const res = await api.put(`/admin/faqs/${id}`, data);
  return res.data;
}
export async function deleteFaq(id: number) {
  const res = await api.delete(`/admin/faqs/${id}`);
  return res.data;
}
export async function bulkDeleteFaqs(ids: number[]) {
  const res = await api.delete("/admin/faqs", { data: { ids } });
  return res.data;
}
