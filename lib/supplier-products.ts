import api from "./api";

// Supplier is its own table — has id, user_id, and a nested user object
export interface SupplierUser {
  id: number;
  full_name: string;
  phone: string;
  email?: string | null;
  personal_photo?: string | null;
}

export interface SupplierInfo {
  id: number;           // supplier.id  ← use this when linking
  is_approved?: boolean;
  user: SupplierUser;   // the actual person
}

export interface SupplierProduct {
  id: number;           // supplier_product.id  ← use this for update/delete
  product_id: number;
  supplier_id: number;  // references supplier.id (not user.id)
  supplier?: SupplierInfo;
  cost_price: number | null;
  price: number | null;
  stock: number;
  min_stock: number;
  is_active: boolean;
  is_featured: boolean;
  is_best_seller: boolean;
  rating: number | null;
  total_reviews: number;
  pickup_ready_duration: number | null;
  estimated_time_from: number | null;
  estimated_time_to: number | null;
  max_amount_for_one_order: number | null;
  min_amount_for_one_order: number | null;
  max_amount_for_one_user: number | null;
  min_amount_for_one_user: number | null;
  reserved_in_carts_amount: number | null;
  created_at: string;
  updated_at?: string;
}

export interface SupplierProductPayload {
  supplier_id: number;  // supplier.id
  cost_price?: number | null;
  price?: number | null;
  stock?: number;
  min_stock?: number;
  is_active?: boolean;
  is_featured?: boolean;
  is_best_seller?: boolean;
  pickup_ready_duration?: number | null;
  estimated_time_from?: number | null;
  estimated_time_to?: number | null;
  max_amount_for_one_order?: number | null;
  min_amount_for_one_order?: number | null;
  max_amount_for_one_user?: number | null;
  min_amount_for_one_user?: number | null;
}

// ── Fetch all suppliers (for the add-supplier dropdown) ───────────────────────
export async function fetchAllSuppliers(): Promise<SupplierInfo[]> {
  const res = await api.get("/users/suppliers");
  const d = res.data;
  if (Array.isArray(d)) return d;
  if (Array.isArray(d?.suppliers)) return d.suppliers;
  return [];
}

// ── Fetch supplier-products for a product ─────────────────────────────────────
export async function fetchProductSuppliers(productId: number): Promise<SupplierProduct[]> {
  const res = await api.get(`/products/${productId}/suppliers`);
  const d = res.data;
  if (Array.isArray(d)) return d;
  if (Array.isArray(d?.supplierProducts)) return d.supplierProducts;
  if (Array.isArray(d?.data)) return d.data;
  return [];
}

export async function linkSupplierToProduct(productId: number, payload: SupplierProductPayload) {
  const res = await api.post(`/products/${productId}/suppliers`, payload);
  return res.data;
}

// spId = supplier_product.id (primary key), NOT supplier.id
export async function updateSupplierProduct(
  productId: number,
  spId: number,
  payload: Partial<Omit<SupplierProductPayload, "supplier_id">>
) {
  const res = await api.put(`/products/${productId}/suppliers/${spId}`, payload);
  return res.data;
}

export async function unlinkSupplierFromProduct(productId: number, spId: number) {
  const res = await api.delete(`/products/${productId}/suppliers/${spId}`);
  return res.data;
}
