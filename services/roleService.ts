import axiosInstance from "@/lib/axios";
import {
  PaginatedRolesResponse,
  RoleFilter,
  CreateRolePayload,
  UpdateRolePayload,
  Role,
} from "@/types/role";

export const roleService = {
  fetchRoles: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<RoleFilter> = {},
  ): Promise<PaginatedRolesResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.name) params.append("name[contains]", filters.name.trim());
    if (filters.name_ar)
      params.append("name_ar[contains]", filters.name_ar.trim());
    if (filters.description)
      params.append("description[contains]", filters.description.trim());
    if (filters.description_ar)
      params.append("description_ar[contains]", filters.description_ar.trim());
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", `${filters.updated_atFrom}T00:00:00Z`);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", `${filters.updated_atTo}T23:59:59Z`);

    const response = await axiosInstance.get(`/roles?${params.toString()}`);
    return response.data;
  },

  fetchRoleDetails: async (id: number): Promise<{ role: Role }> => {
    const response = await axiosInstance.get(`/roles/${id}`);
    return response.data;
  },

  createRole: async (data: CreateRolePayload): Promise<Role> => {
    const response = await axiosInstance.post("/roles", data);
    return response.data;
  },

  updateRole: async (id: number, data: UpdateRolePayload): Promise<Role> => {
    const response = await axiosInstance.put(`/roles/${id}`, data);
    return response.data;
  },

  deleteRole: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/roles/${id}`);
  },

  fetchAllRoles: async (): Promise<Role[]> => {
    const response = await axiosInstance.get("/roles?limit=1000&skip=0");
    return response.data?.roles || [];
  },
};
