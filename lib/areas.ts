import api from "./api";

export interface BoundaryPoint {
  lat: number;
  lng: number;
}

export interface Boundaries {
  [key: string]: BoundaryPoint;
}

export interface Area {
  id: number;
  governorate_id: number;
  name: string;
  name_ar: string;
  is_active: boolean;
  boundaries?: Boundaries | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  governorate?: { id: number; name: string; name_ar: string } | null;
}
export interface AreasResponse {
  totalCount: number;
  totalPages: number;
  areas: Area[];
}

export async function fetchAreas(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<AreasResponse>("/admin/areas", {
    params: { limit, skip, ...rest },
  });
  return res.data;
}
export async function createArea(data: {
  governorate_id: number;
  name: string;
  name_ar: string;
  is_active?: boolean;
  boundaries?: Boundaries;
}) {
  const res = await api.post("/admin/areas", data);
  return res.data;
}
export async function updateArea(
  id: number,
  data: Partial<{
    governorate_id: number;
    name: string;
    name_ar: string;
    is_active: boolean;
    boundaries?: Boundaries;
  }>,
) {
  const res = await api.put(`/admin/areas/${id}`, data);
  return res.data;
}
export async function deleteArea(id: number) {
  const res = await api.delete(`/admin/areas/${id}`);
  return res.data;
}
export async function bulkDeleteAreas(ids: number[]) {
  const res = await api.delete("/admin/areas", { data: { ids } });
  return res.data;
}
