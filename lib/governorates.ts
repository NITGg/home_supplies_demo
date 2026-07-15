import api from "./api";

export interface Governorate {
  id: number;
  name: string;
  name_ar: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}
export interface GovernoratesResponse {
  totalCount: number;
  totalPages: number;
  governorates: Governorate[];
}
export interface GovernoratesWithAreasResponse {
  governorates: (Governorate & { areas: Area[] })[];
}

export async function fetchGovernorates(
  params?: Record<string, string | number>,
) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<GovernoratesResponse>("/admin/governorates", {
    params: { limit, skip, ...rest },
  });
  return res.data;
}
export async function createGovernorate(data: {
  name: string;
  name_ar: string;
  is_active?: boolean;
}) {
  const res = await api.post("/admin/governorates", data);
  return res.data;
}
export async function updateGovernorate(
  id: number,
  data: Partial<{ name: string; name_ar: string; is_active: boolean }>,
) {
  const res = await api.put(`/admin/governorates/${id}`, data);
  return res.data;
}
export async function deleteGovernorate(id: number, archived = false) {
  const res = await api.delete(`/admin/governorates/${id}`, {
    data: { archived },
  });
  return res.data;
}
export async function bulkDeleteGovernorates(ids: number[], archived = false) {
  const res = await api.delete("/admin/governorates", {
    data: { ids, archived },
  });
  return res.data;
}

export interface Area {
  id: number;
  name: string;
  name_ar: string;
  governorate_id: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export async function fetchAreasByGovernorate(
  governorateId: number,
): Promise<Area[]> {
  const res = await api.get<{ areas: Area[] }>("/admin/areas", {
    params: { governorate_id: governorateId, skip: 0, limit: 1000 },
  });
  return res.data.areas ?? [];
}

export async function fetchAllAreas(): Promise<Area[]> {
  const res = await api.get<{ areas: Area[] }>("/admin/areas", {
    params: { skip: 0, limit: 1000 },
  });
  return res.data.areas ?? [];
}

export async function fetchGovernoratesWithAreas(): Promise<
  (Governorate & { areas: Area[] })[]
> {
  const res = await api.get<GovernoratesWithAreasResponse>("/governorates", {
    params: { includes: "areas" },
  });
  return res.data.governorates ?? [];
}
