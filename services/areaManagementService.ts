import axiosInstance from "@/lib/axios";
import {
  Area,
  AreaFilter,
  AreaListResponse,
  Governorate,
  GovernorateFilter,
  GovernorateListResponse,
} from "@/types/areaManagement";

const parseNumberParam = (value: unknown) => {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed === "") return value;
    const parsed = Number(trimmed);
    return Number.isNaN(parsed) ? value : parsed;
  }
  return value;
};

export const areaManagementService = {
  async fetchGovernorates(
    page = 1,
    limit = 10,
    sort = "id",
    filters?: GovernorateFilter,
  ): Promise<GovernorateListResponse> {
    const skip = (page - 1) * limit;
    const params: Record<string, unknown> = { skip, limit, sort };

    if (filters) {
      if (filters.id) params.id = parseNumberParam(filters.id);
      if (filters.name) params["name[contains]"] = filters.name;
      if (filters.name_ar) params["name_ar[contains]"] = filters.name_ar;
      if (filters.is_active) {
        params.is_active =
          filters.is_active === "true"
            ? true
            : filters.is_active === "false"
              ? false
              : filters.is_active;
      }
    }

    const response = await axiosInstance.get("/admin/governorates", { params });
    return response.data;
  },

  async fetchAllGovernorates(): Promise<Governorate[]> {
    const response = await axiosInstance.get("/admin/governorates", {
      params: { skip: 0, limit: 1000 },
    });
    return response.data?.governorates || [];
  },

  async createGovernorate(payload: {
    name: string;
    name_ar: string;
    is_active: boolean;
  }): Promise<{ message: string; governorate: Governorate }> {
    const response = await axiosInstance.post("/admin/governorates", payload);
    return response.data;
  },

  async updateGovernorate(
    governorateId: number,
    payload: { name?: string; name_ar?: string; is_active?: boolean },
  ): Promise<{ message: string; governorate: Governorate }> {
    const response = await axiosInstance.put(
      `/admin/governorates/${governorateId}`,
      payload,
    );
    return response.data;
  },

  async deleteGovernorate(governorateId: number): Promise<void> {
    await axiosInstance.delete(`/admin/governorates/${governorateId}`);
  },

  async fetchAreas(
    page = 1,
    limit = 10,
    sort = "id",
    filters?: AreaFilter,
  ): Promise<AreaListResponse> {
    const skip = (page - 1) * limit;
    const params: Record<string, unknown> = { skip, limit, sort };

    if (filters) {
      if (filters.id) params.id = parseNumberParam(filters.id);
      if (filters.name) params["name[contains]"] = filters.name;
      if (filters.name_ar) params["name_ar[contains]"] = filters.name_ar;
      if (filters.governorate_id) {
        params.governorate_id = parseNumberParam(filters.governorate_id);
      }
      if (filters.is_active) {
        params.is_active =
          filters.is_active === "true"
            ? true
            : filters.is_active === "false"
              ? false
              : filters.is_active;
      }
    }

    const response = await axiosInstance.get("/admin/areas", { params });
    return response.data;
  },

  async createArea(payload: {
    governorate_id: number;
    name: string;
    name_ar: string;
    boundaries: Record<string, { lat: number; lng: number }>;
    is_active: boolean;
  }): Promise<{ message: string; area: Area }> {
    const response = await axiosInstance.post("/admin/areas", payload);
    return response.data;
  },

  async updateArea(
    areaId: number,
    payload: {
      governorate_id?: number;
      name?: string;
      name_ar?: string;
      boundaries?: Record<string, { lat: number; lng: number }>;
      is_active?: boolean;
    },
  ): Promise<{ message: string; area: Area }> {
    const response = await axiosInstance.put(`/admin/areas/${areaId}`, payload);
    return response.data;
  },

  async deleteArea(areaId: number): Promise<void> {
    await axiosInstance.delete(`/admin/areas/${areaId}`);
  },

  async fetchAreasByGovernorate(governorateId: number): Promise<Area[]> {
    const response = await axiosInstance.get("/admin/areas", {
      params: { governorate_id: governorateId, skip: 0, limit: 1000 },
    });
    return response.data?.areas || [];
  },

  async fetchAllAreas(): Promise<Area[]> {
    const response = await axiosInstance.get("/admin/areas", {
      params: { skip: 0, limit: 1000 },
    });
    return response.data?.areas || [];
  },
};
