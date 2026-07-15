import axiosInstance from "@/lib/axios";
import {
  PaginatedReviewsResponse,
  ReviewFilter,
  ReviewDetailsResponse,
} from "@/types/review";

export const reviewService = {
  // Courier Reviews From Customers
  fetchCourierReviewsFromCustomers: async (
    page: number = 1,
    limit: number = 20,
    sort: string = "-courier_id",
    filters: Partial<ReviewFilter> = {},
  ): Promise<PaginatedReviewsResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.courier_id) params.append("courier_id", filters.courier_id);
    if (filters.customer_id) params.append("customer_id", filters.customer_id);
    if (filters.order_id) params.append("order_id", filters.order_id);
    if (filters.rating) params.append("rating", filters.rating);
    if (filters.created_atFrom)
      params.append("created_at[gte]", filters.created_atFrom);
    if (filters.created_atTo)
      params.append("created_at[lte]", filters.created_atTo);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", filters.updated_atFrom);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", filters.updated_atTo);
    if (filters.comment) {
      params.append("keyword", filters.comment);
      params.append("items", "comment");
    }

    const response = await axiosInstance.get(
      `/admin/customer-reviews?${params.toString()}`,
    );
    return response.data;
  },

  fetchCourierReviewFromCustomerDetails: async (
    id: number,
  ): Promise<ReviewDetailsResponse> => {
    const response = await axiosInstance.get(`/admin/customer-reviews/${id}`);
    return response.data;
  },

  deleteCourierReviewFromCustomer: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/customer-reviews/${id}`);
  },

  // Customer Reviews From Couriers
  fetchCustomerReviewsFromCouriers: async (
    page: number = 1,
    limit: number = 20,
    sort: string = "-courier_id",
    filters: Partial<ReviewFilter> = {},
  ): Promise<PaginatedReviewsResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id);
    if (filters.courier_id) params.append("courier_id", filters.courier_id);
    if (filters.customer_id) params.append("customer_id", filters.customer_id);
    if (filters.order_id) params.append("order_id", filters.order_id);
    if (filters.rating) params.append("rating", filters.rating);
    if (filters.created_atFrom)
      params.append("created_at[gte]", filters.created_atFrom);
    if (filters.created_atTo)
      params.append("created_at[lte]", filters.created_atTo);
    if (filters.updated_atFrom)
      params.append("updated_at[gte]", filters.updated_atFrom);
    if (filters.updated_atTo)
      params.append("updated_at[lte]", filters.updated_atTo);
    if (filters.comment) {
      params.append("keyword", filters.comment);
      params.append("items", "comment");
    }

    const response = await axiosInstance.get(
      `/admin/courier-reviews?${params.toString()}`,
    );
    return response.data;
  },

  fetchCustomerReviewFromCourierDetails: async (
    id: number,
  ): Promise<ReviewDetailsResponse> => {
    const response = await axiosInstance.get(`/admin/courier-reviews/${id}`);
    return response.data;
  },

  deleteCustomerReviewFromCourier: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/courier-reviews/${id}`);
  },
};
