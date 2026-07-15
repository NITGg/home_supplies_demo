import api from "./api";

export interface UserRole {
  id: number;
  name: string;
  name_ar: string;
}

export interface UserBadge {
  id: number;
  name: string;
  name_ar: string;
  image?: string;
}

export interface User {
  id: number;
  role_id: number;
  badge_id?: number | null;
  full_name: string;
  email?: string | null;
  phone: string;
  personal_photo?: string | null;
  gender?: "MALE" | "FEMALE" | null;
  lang?: "AR" | "EN";
  is_email_verified: boolean;
  is_phone_verified: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  role?: UserRole | null;
  badge?: UserBadge | null;
  referral_code?: string | null;
  last_login_at?: string | null;
  google_id?: string | null;
  apple_id?: string | null;
  login_type?: string | null;
  fcm_token?: string | null;
  courier?: {
    id?: number;
    courier_office_id?: number | null;
    courierOffice?: { id: number; name?: string } | null;
    vehicle_type?: string;
    vehicle_plate?: string;
    national_id_number?: string;
    is_approved?: boolean;
    reject_reason?: string | null;
    lat?: number | null;
    lng?: number | null;
    last_location_update?: string | null;
    selectedAreas?: any[];
    // Document photos
    national_id_photo_front?: string | null;
    national_id_photo_back?: string | null;
    vehicle_license_front?: string | null;
    vehicle_license_back?: string | null;
    courier_license_front?: string | null;
    courier_license_back?: string | null;
    courier_criminal_record?: string | null;
  } | null;
  wallet?: {
    id: number;
    user_id: number;
    owner_type: string;
    balance: number;
    points: number;
    status: string;
    freeze_reason?: string | null;
    frozen_at?: string | null;
    frozen_by?: string | null;
    created_at?: string;
    updated_at?: string;
    deleted_at?: string | null;
  } | null;
  /** Prisma _count — available when includes=_count is requested */
  _count?: { orders?: number } | null;
}

export interface UsersResponse {
  totalUsers: number;
  totalPages: number;
  users: User[];
}

export interface Role {
  id: number;
  name: string;
  name_ar: string;
}

export async function fetchUsers(params?: Record<string, string | number>) {
  const { page, limit = 10, ...rest } = params || {};
  const skip = page ? (Number(page) - 1) * Number(limit) : undefined;
  const res = await api.get<UsersResponse>("/users", {
    params: { ...rest, limit, ...(skip !== undefined ? { skip } : {}) },
  });
  return res.data;
}

export async function fetchUser(id: number, includes?: string) {
  const res = await api.get<{ user: User }>(`/users/${id}`, {
    params: includes ? { includes } : undefined,
  });
  return res.data.user;
}

export async function createUser(data: FormData) {
  const res = await api.post("/users", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

/**
 * PUT /users/:id.
 *
 * Send a plain object for normal field updates — the backend only reads the
 * JSON body for this route (its sanitize middleware snapshots req.body before
 * multer parses multipart, so form-data text fields are dropped). Pass FormData
 * ONLY when uploading a photo; the file field must be named "photo".
 */
export async function updateUser(
  id: number,
  data: FormData | Record<string, unknown>,
) {
  const isFormData = typeof FormData !== "undefined" && data instanceof FormData;
  const res = await api.put(`/users/${id}`, data, {
    headers: {
      "Content-Type": isFormData ? "multipart/form-data" : "application/json",
    },
  });
  return res.data;
}

export async function deleteUser(id: number, archived = true) {
  const res = await api.delete(`/users/${id}`, {
    data: { id, archived },
  });
  return res.data;
}

export async function bulkDeleteUsers(ids: number[], archived = false) {
  const res = await api.delete("/users", {
    data: { ids, archived },
  });
  return res.data;
}

export async function fetchRoles(): Promise<Role[]> {
  const res = await api.get<{ roles: Role[] }>("/roles");
  return res.data.roles ?? res.data ?? [];
}

export async function fetchBadgesByRoleId(roleId: number): Promise<UserBadge[]> {
  const res = await api.get<{ badges: UserBadge[] }>(`/badges`, { params: { "role[id]": roleId } });
  return res.data.badges ?? [];
}

export async function fetchBadges(): Promise<UserBadge[]> {
  const res = await api.get<{ badges: UserBadge[] }>("/badges");
  return res.data.badges ?? (res.data as any) ?? [];
}

export async function fetchAllUserIds(): Promise<{ id: number; full_name: string }[]> {
  const res = await api.get<UsersResponse>("/users", { params: { limit: 10000, skip: 0, sort: "id" } });
  return (res.data.users || []).map((u) => ({ id: u.id, full_name: u.full_name })).sort((a, b) => a.id - b.id);
}

export async function fetchCouriers(params?: Record<string, string | number>) {
  const { page = 1, limit = 15, ...rest } = params || {};
  const res = await api.get("/admin/approval/all-couriers", { params: { page, limit, ...rest } });
  const couriers = res.data?.data?.couriers || [];
  const pagination = res.data?.data?.pagination || {};
  const normalizedUsers = couriers.map((courier: any) => ({
    ...courier.user,
    id: courier.user_id || courier.user?.id,
    role_id: 2,
    courier: {
      id: courier.id,
      courier_office_id: courier.courier_office_id,
      courierOffice: courier.courierOffice ?? null,
      vehicle_type: courier.vehicle_type,
      vehicle_plate: courier.vehicle_plate,
      national_id_number: courier.national_id_number,
      is_approved: courier.is_approved,
      selectedAreas: courier.selectedAreas,
      lat: courier.lat ?? null,
      lng: courier.lng ?? null,
      last_location_update: courier.last_location_update ?? null,
    },
  }));
  return { users: normalizedUsers, totalUsers: pagination.total || 0, totalPages: pagination.total_pages || 1 };
}

export async function getOnlineCouriers(params?: { order_lat?: string; order_lng?: string }) {
  const res = await api.get("/users/online-couriers", { params });
  return res.data.online_courier_ids ?? [];
}

export interface SupplierUser {
  id: number;
  full_name: string;
  phone: string;
  email?: string | null;
  personal_photo?: string | null;
  is_active?: boolean;
  gender?: string;
  lang?: string;
  created_at?: string;
  last_login_at?: string | null;
}

export type WorkingHoursDay = {
  open?: string;
  close?: string;
  is_open?: boolean;
};

export type WorkingHours = Record<string, WorkingHoursDay>;

export interface SupplierAddress {
  id: number;
  address_line_1?: string | null;
  address_line_2?: string | null;
  city?: string | null;
  state?: string | null;
  country?: string | null;
  google_map_link?: string | null;
  latitude?: string | null;
  longitude?: string | null;
  contact_name?: string | null;
  contact_phone?: string | null;
  working_hours?: WorkingHours | null;
}

export interface SupplierStats {
  total_customers?: number | null;
  total_orders?: number | null;
  total_delivered_orders?: number | null;
  total_cancelled_orders?: number | null;
  total_active_products?: number | null;
  last_order_date?: string | null;
}

export interface SupplierDetail {
  id: number;
  is_approved: boolean;
  markup_ratio?: number | null;
  created_at: string;
  updated_at?: string;
  national_id_number?: string | null;
  synonyms?: string | null;
  tax_card?: string | null;
  commercial_register?: string | null;
  national_id_photo_front?: string | null;
  national_id_photo_back?: string | null;
  supplier_criminal_record?: string | null;
  user: SupplierUser;
  type?: { id: number; name: string; description?: string | null } | null;
  addresses: SupplierAddress[];
  stats?: SupplierStats | null;
  categories?: {
    category: { id: number; name: string; name_ar?: string | null };
  }[];
}

export interface Supplier {
  id: number;
  is_approved: boolean;
  markup_ratio?: number | null;
  created_at: string;
  updated_at?: string | null;
  national_id_number?: string | null;
  synonyms?: string | null;
  tax_card?: string | null;
  commercial_register?: string | null;
  user: SupplierUser;
}

export interface SupplierProductItem {
  id: number;
  price: number | null;
  cost_price: number | null;
  stock: number;
  min_stock: number;
  is_active: boolean;
  is_featured: boolean;
  is_best_seller: boolean;
  pickup_ready_duration: number | null;
  created_at: string;
  product: {
    id: number;
    name: string;
    name_ar?: string | null;
    sku: string;
    images?: string | null;
    category?: { id: number; name: string; name_ar?: string | null } | null;
  };
}

export async function fetchSuppliers(params?: {
  category_id?: number;
  keyword?: string;
  limit?: number;
}): Promise<Supplier[]> {
  const res = await api.get("/users/suppliers", { params });
  // API returns { result: { suppliers, totalSuppliers, totalPages } }
  return (res.data as any).result?.suppliers ?? (res.data as any).suppliers ?? [];
}

export async function fetchSupplierProducts(
  id: number,
): Promise<SupplierProductItem[]> {
  const res = await api.get<{ products: SupplierProductItem[] }>(
    `/users/suppliers/${id}/products`,
  );
  return res.data.products ?? [];
}

export async function fetchSupplier(id: number): Promise<SupplierDetail> {
  const res = await api.get<{ supplier: SupplierDetail }>(
    `/users/suppliers/${id}`,
  );
  return res.data.supplier;
}

export async function approveSupplier(id: number) {
  const res = await api.patch(`/users/suppliers/${id}/approve`);
  return res.data;
}

export async function rejectSupplier(id: number) {
  const res = await api.patch(`/users/suppliers/${id}/reject`);
  return res.data;
}

export async function createSupplierAddress(supplierId: number, data: Partial<SupplierAddress>) {
  const res = await api.post(`/users/suppliers/${supplierId}/addresses`, data);
  return res.data;
}

export async function updateSupplierAddress(supplierId: number, addressId: number, data: Partial<SupplierAddress>) {
  const res = await api.patch(`/users/suppliers/${supplierId}/addresses/${addressId}`, data);
  return res.data;
}

export async function resetSupplierProductPrice(productId: number, spId: number) {
  const res = await api.patch(`/products/${productId}/suppliers/${spId}/reset-price`);
  return res.data;
}

export async function updateSupplier(
  id: number,
  data: {
    full_name?: string;
    email?: string;
    phone?: string;
    national_id_number?: string;
    synonyms?: string;
    markup_ratio?: number | string;
    min_price_for_one_order?: number;
    personal_photo?: File | null;
    tax_card?: string | File | null;
    commercial_register?: string | File | null;
  },
) {
  const hasFiles =
    data.personal_photo instanceof File ||
    data.tax_card instanceof File ||
    data.commercial_register instanceof File;

  if (hasFiles) {
    const form = new FormData();
    for (const [k, v] of Object.entries(data)) {
      if (v === undefined || v === null || v === "") continue;
      if (v instanceof File) form.append(k, v);
      else form.append(k, String(v));
    }
    const res = await api.patch(`/users/suppliers/${id}`, form, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return res.data;
  }

  const payload: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v !== undefined && v !== null && !(v instanceof File) && v !== "") {
      payload[k] = String(v);
    }
  }
  const res = await api.patch(`/users/suppliers/${id}`, payload);
  return res.data;
}
