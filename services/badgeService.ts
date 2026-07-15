import axiosInstance from "@/lib/axios";
import {
  PaginatedBadgesResponse,
  BadgeFilter,
  RolesResponse,
  CreateBadgePayload,
  UpdateBadgePayload,
  Badge,
} from "@/types/badge";
import { User } from "@/types/user";

export const badgeService = {
  fetchBadges: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<BadgeFilter> = {},
  ): Promise<PaginatedBadgesResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("includes", "role");
    params.append("sort", sort);

    if (filters.name) params.append("name[contains]", filters.name.trim());
    if (filters.name_ar)
      params.append("name_ar[contains]", filters.name_ar.trim());
    if (filters.role_id) params.append("role_id", filters.role_id);
    if (filters.min_countFrom)
      params.append("min_count[gte]", filters.min_countFrom);
    if (filters.min_countTo)
      params.append("min_count[lte]", filters.min_countTo);
    if (filters.max_countFrom)
      params.append("max_count[gte]", filters.max_countFrom);
    if (filters.max_countTo)
      params.append("max_count[lte]", filters.max_countTo);
    if (filters.ratioFrom) params.append("ratio[gte]", filters.ratioFrom);
    if (filters.ratioTo) params.append("ratio[lte]", filters.ratioTo);
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", `${filters.updated_atFrom}T00:00:00Z`);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", `${filters.updated_atTo}T23:59:59Z`);

    const response = await axiosInstance.get(`/badges?${params.toString()}`);
    return response.data;
  },

  fetchRoles: async (): Promise<RolesResponse> => {
    const response = await axiosInstance.get("/roles");
    return response.data;
  },

  fetchBadgeDetails: async (id: number): Promise<{ badge: Badge }> => {
    const response = await axiosInstance.get(`/badges/${id}`);
    return response.data;
  },

  createBadge: async (data: CreateBadgePayload): Promise<Badge> => {
    const formData = new FormData();
    formData.append("name", data.name);
    formData.append("name_ar", data.name_ar);
    formData.append("description", data.description);
    formData.append("description_ar", data.description_ar);
    formData.append("min_count", data.min_count.toString());
    formData.append("max_count", data.max_count.toString());
    formData.append("ratio", data.ratio.toString());
    formData.append("role_id", data.role_id.toString());

    if (data.image) {
      formData.append("image", data.image);
    }

    const response = await axiosInstance.post("/badges", formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
    return response.data;
  },

  updateBadge: async (id: number, data: UpdateBadgePayload): Promise<Badge> => {
    const formData = new FormData();
    if (data.name !== undefined) formData.append("name", data.name);
    if (data.name_ar !== undefined) formData.append("name_ar", data.name_ar);
    if (data.description !== undefined)
      formData.append("description", data.description);
    if (data.description_ar !== undefined)
      formData.append("description_ar", data.description_ar);
    if (data.min_count !== undefined)
      formData.append("min_count", data.min_count.toString());
    if (data.max_count !== undefined)
      formData.append("max_count", data.max_count.toString());
    if (data.ratio !== undefined)
      formData.append("ratio", data.ratio.toString());
    if (data.role_id !== undefined)
      formData.append("role_id", data.role_id.toString());
    if (data.deleteImage) formData.append("deleteImage", "true");

    if (data.image) {
      formData.append("image", data.image);
    }

    const response = await axiosInstance.put(`/badges/${id}`, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
    return response.data;
  },

  deleteBadge: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/badges/${id}`);
  },

  fetchBadgeUsers: async (
    badgeId: number,
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Record<string, string> = {},
  ): Promise<{ totalUsers: number; totalPages: number; users: User[] }> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("includes", "badge");
    params.append("badge[id]", badgeId.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.full_name)
      params.append("full_name[contains]", filters.full_name.trim());
    if (filters.email) params.append("email[contains]", filters.email.trim());

    // For phone numbers with + prefix
    if (filters.phone) {
      const formattedPhone = filters.phone.startsWith("+")
        ? filters.phone
        : `+${filters.phone}`;
      params.append("phone[contains]", formattedPhone);
    }

    const response = await axiosInstance.get(`/users?${params.toString()}`);
    return response.data;
  },

  fetchAllBadges: async (): Promise<Badge[]> => {
    const response = await axiosInstance.get("/badges?limit=1000&skip=0");
    return response.data?.badges || [];
  },
};
