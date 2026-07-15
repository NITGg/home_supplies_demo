import api from "./api";

export interface Vehicle {
  id: number;
  name: string;
  name_ar: string;
  icon?: string | null;
  price_per_km?: string | number | null;
  min_distance_per_km?: string | number | null;
  max_distance_per_km?: string | number | null;
  min_delivery_fee?: string | number | null;
  delivery_price_for_each_1m?: string | number | null;
  delivery_fee_ratio?: string | number | null;
  total_fines?: string | number | null;
  fee_base_distance_km: number;
  fee_extra_platform_per_km: number;
  fee_extra_courier_per_km: number;
  peak_time_fee_ratio: number;

  created_at: string;
  updated_at: string;
}

interface Pagination {
  total: number;
  page: number;
  limit: number;
  total_pages: number;
  has_next: boolean;
  has_prev: boolean;
}
export interface VehiclesResponse {
  vehicles: Vehicle[];
  pagination: Pagination;
}

export async function fetchVehicles(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: VehiclesResponse }>(
    "/admin/vehicle/list-vehicles",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}
export async function createVehicle(data: FormData) {
  const res = await api.post("/admin/vehicle/create-vehicle", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}
export async function updateVehicle(id: number, data: FormData) {
  const res = await api.patch(`/admin/vehicle/update-vehicle/${id}`, data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}
export async function deleteVehicle(id: number) {
  const res = await api.delete(`/admin/vehicle/delete-vehicle/${id}`);
  return res.data;
}
