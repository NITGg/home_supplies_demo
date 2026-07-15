import api from "./api";

export interface Role {
  id: number;
  name: string;
  name_ar: string;
  description?: string | null;
  description_ar?: string | null;
  created_at: string;
  updated_at: string;
}

export interface RolesResponse {
  roles: Role[];
  totalRoles: number;
  totalPages: number;
}

export async function fetchRoles(params?: {
  page?: number;
  limit?: number;
  search?: string;
}): Promise<RolesResponse> {
  const { page = 1, limit = 20, search } = params ?? {};
  const skip = (page - 1) * limit;
  const res = await api.get<RolesResponse>("/roles", {
    params: {
      limit,
      skip,
      ...(search ? { "name[contains]": search } : {}),
    },
  });
  return res.data;
}

export async function createRole(data: {
  name: string;
  name_ar: string;
  description?: string;
  description_ar?: string;
}): Promise<Role> {
  const res = await api.post<{ role: Role }>("/roles", data);
  return res.data.role;
}

export async function updateRole(
  id: number,
  data: { name?: string; name_ar?: string; description?: string; description_ar?: string },
): Promise<Role> {
  const res = await api.put<{ role: Role }>(`/roles/${id}`, data);
  return res.data.role;
}

export async function deleteRole(id: number): Promise<void> {
  await api.delete(`/roles/${id}`);
}
