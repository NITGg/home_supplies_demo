import axiosInstance from "@/lib/axios";
import {
  UnavailableAreaRequestFilter,
  UnavailableAreaRequestStats,
  PaginatedUnavailableAreaRequestsResponse,
} from "@/types/unavailableAreaRequest";

export const unavailableAreaRequestService = {
  fetchRequests: async (
    page: number = 1,
    limit: number = 20,
    filters: Partial<UnavailableAreaRequestFilter> = {},
    sort: string = "-created_at",
  ): Promise<PaginatedUnavailableAreaRequestsResponse> => {
    const queryParams = new URLSearchParams({
      limit: limit?.toString() ?? "20",
      includes: "customer=id-full_name-phone-role_id",
      sort,
    });

    if (filters.request_type)
      queryParams.append("request_type", filters.request_type);
    if (filters.area) queryParams.append("area", filters.area);
    if (filters.governorate)
      queryParams.append("governorate", filters.governorate.trim());
    if (filters.customer_id)
      queryParams.append("customer_id", filters.customer_id);
    if (filters.from) queryParams.append("created_at[gte]", filters.from);
    if (filters.to) queryParams.append("created_at[lte]", filters.to);
    console.log(queryParams.toString());

    const response = await axiosInstance.get(
      `/unavailable-area-request?${queryParams.toString()}`,
    );
    console.log(response.data);

    return response.data;
  },

  fetchStats: async (): Promise<UnavailableAreaRequestStats> => {
    const response = await axiosInstance.get("/unavailable-area-request/stats");
    return response.data.data;
  },

  deleteRequest: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/unavailable-area-request/${id}`);
  },
};
