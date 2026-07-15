export interface User {
  id: number;
  full_name?: string;
  name?: string;
  email: string;
  phone: string;
  referral_code?: string | null;
  gender: "MALE" | "FEMALE" | string;
  role_id: number;
  role?: UserRole;
  lang: "EN" | "AR" | string;
  is_active?: boolean;
  is_email_verified?: boolean;
  is_phone_verified?: boolean;
  status?: string;
  wallet?: Wallet;
  created_at?: string;
  updated_at?: string;
  deleted_at?: string | null;
  last_login_at?: string | null;
  badge_id?: number | null;
  badge?: UserBadge;
  personal_photo?: string | null;
  password_last_updated?: string | null;
  fcm_token?: string | null;
  google_id?: string | null;
  apple_id?: string | null;
  courier?: CourierProfile;
}

export interface UserRole {
  id: number;
  name: string;
  name_ar?: string;
  description?: string;
  description_ar?: string;
  created_at?: string;
  updated_at?: string;
}

export interface UserBadge {
  id: number;
  role_id?: number;
  name: string;
  name_ar?: string;
  image?: string;
  description?: string;
  description_ar?: string;
  min_count?: number;
  max_count?: number;
  ratio?: number;
  created_at?: string;
  updated_at?: string;
}

export interface Wallet {
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
}

export interface CourierProfile {
  id: number;
  user_id: number;
  courier_office_id?: number | null;
  vehicle_type?: string;
  vehicle_plate?: string;
  national_id_number?: string;
  is_approved?: boolean;
  reject_reason?: string;
  courierOffice?: {
    id: number;
    name?: string;
  } | null;
  created_at?: string;
  updated_at?: string;
}

export interface UserFilter {
  id?: string;
  full_name?: string;
  email?: string;
  phone?: string;
  referral_code?: string;
  role_id?: string;
  is_active?: string;
  is_email_verified?: string;
  is_phone_verified?: string;
  gender?: string;
  badge_id?: string;
  created_atFrom?: string;
  created_atTo?: string;
  updated_atFrom?: string;
  updated_atTo?: string;
  keyword?: string;
  vehicle_type?: string;
  vehicle_plate?: string;
  national_id_number?: string;
  is_approved?: string;
  governorate_id?: string;
  area_id?: string;
  is_online?: string;
  courier_availability?: string;
  vehicle_id?: string;
  courier_office_id?: string;
}

export interface UserListResponse {
  users: User[];
  totalUsers: number;
  totalPages: number;
}


export interface OnlineCourier {
  id: number;
  user_id: number;
  lat: number;
  lng: number;
  full_name: string;
  phone: string;
  personal_photo: string | null;
  distance: number;
  real_distance: number | null;
  duration: number | null;
  has_active_order: boolean;
}

export interface OnlineCouriersResponse {
  total: number;
  couriers: OnlineCourier[];
}

export interface GetOnlineCouriersAPIResponse {
  online_courier_ids: OnlineCouriersResponse;
}