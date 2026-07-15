import api from "./api";

export interface Category {
  id: number;
  name: string;
  name_ar: string;
  slug: string;
  description?: string;
  description_ar?: string;
  image_url?: string;
  icon_url?: string;
  parent_id?: number | null;
  is_active: boolean;
  has_window?: boolean;
  sort_id: number;
  synonyms?: string;
  created_at: string;
  updated_at: string;
}

export interface CategoriesResponse {
  totalCount: number;
  totalPages: number;
  categories: Category[];
}

export async function fetchCategories(params?: Record<string, string | number>) {
  // The API uses `skip` for pagination, not `page`
  const { page, limit = 10, ...rest } = params || {};
  const skip = page ? (Number(page) - 1) * Number(limit) : undefined;
  const res = await api.get<CategoriesResponse>("/categories", {
    params: { ...rest, limit, ...(skip !== undefined ? { skip } : {}) },
  });
  return res.data;
}

export async function fetchCategory(id: number) {
  const res = await api.get<{ category: Category }>(`/categories/${id}`);
  return res.data.category;
}

export async function createCategory(data: FormData) {
  const res = await api.post("/categories", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function updateCategory(id: number, data: FormData) {
  const res = await api.put(`/categories/${id}`, data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function deleteCategory(id: number) {
  // Backend requires `permanent` boolean in request body (defaults to soft-delete)
  const res = await api.delete(`/categories/${id}`, {
    data: { permanent: false },
  });
  return res.data;
}

export async function hardDeleteCategory(id: number) {
  const res = await api.delete(`/categories/${id}`, {
    data: { permanent: true },
  });
  return res.data;
}
