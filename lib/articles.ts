import api from "./api";

export interface Article {
  id: number;
  title: string;
  slug: string;
  summary?: string | null;
  content: string;
  cover_image?: string | null;
  keywords?: string | null;
  published_at?: string | null;
  author: string;
  is_active: boolean;
  sort_id?: number | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}
export interface ArticlesResponse { total: number; total_pages: number; articles: Article[]; }

export async function fetchArticles(params?: Record<string, string | number>) {
  const { page = 1, limit = 12, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<{ data: ArticlesResponse }>("/admin/articles", { params: { limit, skip, ...rest } });
  return res.data.data;
}
export async function createArticle(data: FormData) {
  const res = await api.post("/admin/articles", data, { headers: { "Content-Type": "multipart/form-data" } });
  return res.data;
}
export async function updateArticle(id: number, data: FormData) {
  const res = await api.put(`/admin/articles/${id}`, data, { headers: { "Content-Type": "multipart/form-data" } });
  return res.data;
}
export async function deleteArticle(id: number) {
  const res = await api.delete(`/admin/articles/${id}`);
  return res.data;
}
export async function bulkDeleteArticles(ids: number[]) {
  const res = await api.delete("/admin/articles", { data: { ids } });
  return res.data;
}
