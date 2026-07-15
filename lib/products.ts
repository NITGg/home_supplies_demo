import api from "./api";

export interface ProductCategory {
  id: number;
  name: string;
  name_ar?: string;
}

export interface ProductBrand {
  id: number;
  name: string;
  name_ar?: string | null;
  logo_url?: string | null;
}

export interface ProductAttribute {
  id: number;
  key: string;
  value: string;
  value_ar?: string | null;
}

export interface Product {
  id: number;
  name: string;
  name_ar?: string | null;
  description?: string | null;
  description_ar?: string | null;
  sku: string;
  barcode?: string | null;
  slug?: string | null;
  synonyms?: string | null;
  images: string[];
  weight?: number | null;
  dimensions?: string | null;
  color?: string | null;
  category_id: number;
  brand_id?: number | null;
  sort_id: number;
  refundable?: boolean | null;
  refundable_period?: number | null;
  refund_policy?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  category?: ProductCategory | null;
  brand?: ProductBrand | null;
  attributes?: ProductAttribute[];
}

export interface ProductsResponse {
  totalProducts: number;
  totalPages: number;
  products: Product[];
}

export interface Brand {
  id: number;
  name: string;
  name_ar?: string | null;
  slug: string;
  logo_url?: string | null;
  cover_url?: string | null;
  is_active: boolean;
  is_popular: boolean;
  description?: string | null;
  description_ar?: string | null;
  synonyms?: string | null;
  sort_id: number;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface BrandsResponse {
  totalBrands: number;
  totalPages: number;
  brands: Brand[];
}

export async function fetchProducts(params?: Record<string, string | number>) {
  // The API uses `skip` for pagination, not `page`
  const { page = 1, limit = 10, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<ProductsResponse>("/products/list-products", {
    params: { limit, skip, ...rest },
  });
  return res.data;
}

export async function fetchProduct(id: number) {
  const res = await api.get<{ product: Product }>(`/products/${id}`);
  return res.data.product;
}

export async function createProduct(data: FormData) {
  const res = await api.post("/products", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function updateProduct(id: number, data: FormData) {
  const res = await api.put(`/products/${id}`, data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function deleteProduct(id: number, archived = true) {
  const res = await api.delete(`/products/${id}`, {
    data: { archived },
  });
  return res.data;
}

export async function bulkDeleteProducts(ids: number[], archived = false) {
  const res = await api.delete("/products", {
    data: { strategy: "ids", ids, archived },
  });
  return res.data;
}

export async function fetchBrands(params?: Record<string, string | number>) {
  const { page = 1, limit = 12, ...rest } = params || {};
  const res = await api.get<BrandsResponse>("/brands", {
    params: { page, limit, ...rest },
  });
  return res.data;
}

export async function fetchAllBrands() {
  const res = await api.get<BrandsResponse>("/brands", {
    params: { limit: 9999, is_active: "true" },
  });
  return res.data.brands ?? [];
}

export async function bulkDeleteBrands(ids: number[], permanent = false) {
  const res = await api.delete("/brands", { data: { ids, permanent } });
  return res.data;
}

export async function createBrand(data: FormData) {
  const res = await api.post("/brands", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function updateBrand(id: number, data: FormData) {
  const res = await api.put(`/brands/${id}`, data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function deleteBrand(id: number, permanent = false) {
  const res = await api.delete("/brands", {
    data: { ids: [id], permanent },
  });
  return res.data;
}
