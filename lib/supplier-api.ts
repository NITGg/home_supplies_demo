import { supplierApi } from "./api";

export interface WorkingHours {
  timezone: string;
  days: Record<
    string,
    {
      is_closed: boolean;
      slots: Array<{
        open: string;
        close: string;
      }>;
    }
  >;
}

export interface SupplierAddress {
  id: number;
  supplier_id: number;
  area_id: number;
  address_line_1: string;
  address_line_2?: string | null;
  city: string;
  state: string;
  country: string;
  google_map_link?: string | null;
  latitude?: string | null;
  longitude?: string | null;
  contact_name?: string | null;
  contact_phone?: string | null;
  working_hours: WorkingHours;
  created_at: string;
  updated_at: string;
}

export interface SupplierProfile {
  id: number;
  user_id: number;
  type_id: number;
  national_id_photo_front?: string | null;
  national_id_photo_back?: string | null;
  national_id_number?: string | null;
  supplier_criminal_record?: string | null;
  synonyms?: string | null;
  tax_card?: string | null;
  commercial_register?: string | null;
  min_price_for_one_order?: number | null;
  max_price_for_one_order?: number | null;
  shopping_min_price_for_one_order?: number | null;
  shopping_max_price_for_one_order?: number | null;
  shopping_budget_fee?: number | null;
  is_approved: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  addresses: SupplierAddress[];
}

export interface SupplierProfileUser {
  id: number;
  role_id: number;
  badge_id?: number | null;
  full_name: string;
  email?: string | null;
  phone: string;
  extra_phones?: string | null;
  personal_photo?: string | null;
  is_email_verified: boolean;
  is_phone_verified: boolean;
  is_active: boolean;
  fcm_token?: string | null;
  lang?: string | null;
  google_id?: string | null;
  apple_id?: string | null;
  last_login_at?: string | null;
  login_type?: string | null;
  password_last_updated?: string | null;
  gender?: string | null;
  referral_code?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  supplier: SupplierProfile;
  wallet?: {
    balance: number;
    status: string;
  } | null;
}

export interface SupplierProfileResponse {
  status: number;
  message: string;
  data: {
    user: SupplierProfileUser;
  };
}

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

export interface BadgeProgressResponse {
  status: number;
  message: string;
  data: {
    current_badge: Badge;
    all_badges: Badge[];
  };
}

export interface UpdateSupplierProfileData {
  full_name?: string;
  phone?: string;
  gender?: string;
  language?: string;
  type_id?: string | number;
  badge_id?: string | number;
  synonyms?: string;
  tax_card?: string;
  commercial_register?: string;
  min_price_for_one_order?: number;
  max_price_for_one_order?: number;
  shopping_min_price_for_one_order?: number;
  shopping_max_price_for_one_order?: number;
  shopping_budget_fee?: number;
  address_line_1?: string;
  address_line_2?: string;
  city?: string;
  state?: string;
  country?: string;
  google_map_link?: string;
  latitude?: string;
  longitude?: string;
  contact_name?: string;
  contact_phone?: string;
  working_hours?: WorkingHours;
}

export async function fetchSupplierProfile(
  userId: number,
): Promise<SupplierProfileUser> {
  const res = await supplierApi.get<SupplierProfileResponse>(
    `/profile/get-profile/${userId}`,
  );
  return res.data.data.user;
}

export async function fetchSupplierBadgeProgress(
  userId: number,
): Promise<BadgeProgressResponse["data"]> {
  const res = await supplierApi.get<BadgeProgressResponse>(
    `/profile/badge-progress/${userId}`,
  );
  return res.data.data;
}

export async function updateSupplierProfile(
  userId: number,
  data: UpdateSupplierProfileData,
): Promise<SupplierProfileResponse> {
  const res = await supplierApi.patch<SupplierProfileResponse>(
    `/profile/update-profile/${userId}`,
    data,
  );
  return res.data;
}

export async function updateSupplierDocuments(
  userId: number,
  data: FormData,
): Promise<SupplierProfileResponse> {
  const res = await supplierApi.patch<SupplierProfileResponse>(
    `/profile/update-documents/${userId}`,
    data,
    {
      headers: { "Content-Type": "multipart/form-data" },
    },
  );
  return res.data;
}
