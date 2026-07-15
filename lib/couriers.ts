import api from "./api";

export interface OnlineCourier {
  id: number;
  user_id: number;
  lat: string | number | null;
  lng: string | number | null;
  // Present in all responses
  user?: {
    id: number;
    full_name: string;
    phone: string;
    personal_photo?: string | null;
  };
  // Present in flat (distance-mode) responses
  full_name?: string;
  phone?: string;
  personal_photo?: string | null;
  // Distance-mode extras
  real_distance?: number | null; // meters
  duration?: number | null;      // seconds
  has_active_order?: boolean;
}

export interface OnlineCouriersResponse {
  total: number;
  couriers: OnlineCourier[];
}

export function courierName(c: OnlineCourier): string {
  return c.user?.full_name ?? c.full_name ?? "";
}
export function courierPhone(c: OnlineCourier): string {
  return c.user?.phone ?? c.phone ?? "";
}
export function courierPhoto(c: OnlineCourier): string | null | undefined {
  return c.user?.personal_photo ?? c.personal_photo;
}

export async function fetchOnlineCouriers(params?: {
  order_lat?: number;
  order_lng?: number;
  take?: number;  // backend param name is "take", not "limit"
  skip?: number;
}): Promise<OnlineCouriersResponse> {
  const res = await api.get<{ online_courier_ids: OnlineCouriersResponse }>(
    "/users/online-couriers",
    {
      params: {
        take: params?.take ?? 200,  // default high — backend defaults to 10 which hides most
        ...(params?.skip != null && { skip: params.skip }),
        ...(params?.order_lat != null && { order_lat: params.order_lat }),
        ...(params?.order_lng != null && { order_lng: params.order_lng }),
      },
    }
  );
  return res.data.online_courier_ids;
}

export interface ActiveCourierUser {
  id: number;
  full_name: string;
  phone: string;
  personal_photo?: string | null;
  courier?: {
    id: number;
    lat: string | number | null;
    lng: string | number | null;
    last_location_update: string | null;
    has_active_order?: boolean;
  } | null;
}

export interface ActiveCouriersResponse {
  totalUsers: number;
  totalPages: number;
  users: ActiveCourierUser[];
}

export async function fetchAllActiveCouriers(params?: {
  limit?: number;
  skip?: number;
  keyword?: string;
}): Promise<ActiveCouriersResponse> {
  const res = await api.get<ActiveCouriersResponse>("/users", {
    params: {
      role_id: 2,
      is_active: true,
      includes: "courier",
      limit: params?.limit ?? 100,
      ...(params?.skip != null && { skip: params.skip }),
      ...(params?.keyword && { keyword: params.keyword }),
    },
  });
  return res.data;
}
