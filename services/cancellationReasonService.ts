import axiosInstance from "@/lib/axios";
import {
  PaginatedCancellationReasonsResponse,
  CancellationReasonFilter,
  CreateCancellationReasonPayload,
  UpdateCancellationReasonPayload,
  CancellationReason,
} from "@/types/cancellationReason";

export const cancellationReasonService = {
  fetchReasons: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<CancellationReasonFilter> = {},
  ): Promise<PaginatedCancellationReasonsResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.role_id) params.append("role_id", filters.role_id);

    if (filters.reason_en)
      params.append("reason_en[contains]", filters.reason_en.trim());
    if (filters.reason_ar)
      params.append("reason_ar[contains]", filters.reason_ar.trim());
    if (filters.created_atFrom)
      params.append("created_at[gte]", `${filters.created_atFrom}T00:00:00Z`);
    if (filters.created_atTo)
      params.append("created_at[lte]", `${filters.created_atTo}T23:59:59Z`);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", `${filters.updated_atFrom}T00:00:00Z`);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", `${filters.updated_atTo}T23:59:59Z`);

    const response = await axiosInstance.get(
      `/admin/cancellation-reason/all-reasons?${params.toString()}`,
    );
    return response.data.data;
  },

  fetchReasonDetails: async (id: number): Promise<CancellationReason> => {
    const response = await axiosInstance.get(
      `/admin/cancellation-reason/reason-details/${id}`,
    );
    return response.data.data;
  },

  createReason: async (
    data: CreateCancellationReasonPayload,
  ): Promise<CancellationReason> => {
    const response = await axiosInstance.post(
      "/admin/cancellation-reason/reason",
      data,
    );
    return response.data.data;
  },

  updateReason: async (
    id: number,
    data: UpdateCancellationReasonPayload,
  ): Promise<CancellationReason> => {
    const response = await axiosInstance.put(
      `/admin/cancellation-reason/update-reason/${id}`,
      data,
    );
    return response.data.data;
  },

  deleteReason: async (id: number): Promise<void> => {
    await axiosInstance.delete(
      `/admin/cancellation-reason/delete-reason/${id}`,
    );
  },

  fetchAllReasons: async (roleId?: string): Promise<CancellationReason[]> => {
    let url = "/admin/cancellation-reason/all-reasons?limit=1000&skip=0";
    if (roleId) {
      url += `&role_id=${roleId}`;
    }
    const response = await axiosInstance.get(url);
    return response.data?.data?.reasons || [];
  },
};
