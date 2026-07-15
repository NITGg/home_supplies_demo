import axiosInstance from "@/lib/axios";
import {
  CreateFaqPayload,
  FaqItem,
  FaqFilter,
  PaginatedFaqResponse,
  UpdateFaqPayload,
} from "@/types/faq";

export const faqService = {
  fetchFaqs: async (
    page: number = 1,
    limit: number = 20,
    sort: string = "id",
    filters: Partial<FaqFilter> = {},
  ): Promise<PaginatedFaqResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id.trim());
    if (filters.question) params.append("question[contains]", filters.question.trim());
    if (filters.answer) params.append("answer[contains]", filters.answer.trim());
    if (filters.sort_id) params.append("sort_id", filters.sort_id.trim());
    if (filters.target_user) params.append("target_user", filters.target_user);
    if (filters.is_active !== undefined && filters.is_active !== "") {
      params.append("is_active", filters.is_active);
    }
    if (filters.created_from) params.append("created_at[gte]", filters.created_from);
    if (filters.created_to) params.append("created_at[lte]", filters.created_to);
    if (filters.updated_from) params.append("updated_at[gte]", filters.updated_from);
    if (filters.updated_to) params.append("updated_at[lte]", filters.updated_to);

    const response = await axiosInstance.get(
      `/admin/faqs?${params.toString()}`,
    );
    return response.data;
  },

  createFaq: async (data: CreateFaqPayload) => {
    const response = await axiosInstance.post("/admin/faqs", data);
    return response.data;
  },

  updateFaq: async (id: number, data: UpdateFaqPayload) => {
    const response = await axiosInstance.put(`/admin/faqs/${id}`, data);
    return response.data;
  },

  deleteFaq: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/faqs/${id}`);
  },
};
