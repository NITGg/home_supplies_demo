import axiosInstance from "@/lib/axios";
import {
  CreateOnBoardingPayload,
  OnBoardingItem,
  OnBoardingFilter,
  PaginatedOnBoardingResponse,
  UpdateOnBoardingPayload,
} from "@/types/onBoarding";

export const onBoardingService = {
  fetchOnBoardingItems: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<OnBoardingFilter> = {},
  ): Promise<PaginatedOnBoardingResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id.trim());
    if (filters.title) params.append("title[contains]", filters.title.trim());
    if (filters.title_ar) {
      params.append("title_ar[contains]", filters.title_ar.trim());
    }
    if (filters.content) {
      params.append("content[contains]", filters.content.trim());
    }
    if (filters.content_ar) {
      params.append("content_ar[contains]", filters.content_ar.trim());
    }
    if (filters.subtitle) {
      params.append("subtitle[contains]", filters.subtitle.trim());
    }
    if (filters.subtitle_ar) {
      params.append("subtitle_ar[contains]", filters.subtitle_ar.trim());
    }
    if (filters.sort_id) params.append("sort_id", filters.sort_id.trim());
    if (filters.target_user) params.append("target_user", filters.target_user);

    const response = await axiosInstance.get(
      `/admin/on-boarding?${params.toString()}`,
    );
    return response.data;
  },

  fetchOnBoardingDetails: async (
    id: number,
  ): Promise<OnBoardingItem | null> => {
    const response = await onBoardingService.fetchOnBoardingItems(1, 1, "id", {
      id: String(id),
    });

    return response.items?.[0] || null;
  },

  createOnBoardingItem: async (data: CreateOnBoardingPayload) => {
    const formData = new FormData();
    formData.append("title", data.title);
    formData.append("title_ar", data.title_ar);
    formData.append("content", data.content);
    formData.append("content_ar", data.content_ar);
    formData.append("subtitle", data.subtitle);
    formData.append("subtitle_ar", data.subtitle_ar);
    formData.append("sort_id", data.sort_id.toString());
    formData.append("target_user", data.target_user);

    if (data.image) {
      formData.append("image", data.image);
    }

    const response = await axiosInstance.post("/admin/on-boarding", formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });

    return response.data;
  },

  updateOnBoardingItem: async (id: number, data: UpdateOnBoardingPayload) => {
    const formData = new FormData();

    if (data.title !== undefined) formData.append("title", data.title);
    if (data.title_ar !== undefined) formData.append("title_ar", data.title_ar);
    if (data.content !== undefined) formData.append("content", data.content);
    if (data.content_ar !== undefined) {
      formData.append("content_ar", data.content_ar);
    }
    if (data.subtitle !== undefined) formData.append("subtitle", data.subtitle);
    if (data.subtitle_ar !== undefined) {
      formData.append("subtitle_ar", data.subtitle_ar);
    }
    if (data.sort_id !== undefined) {
      formData.append("sort_id", data.sort_id.toString());
    }
    if (data.target_user !== undefined) {
      formData.append("target_user", data.target_user);
    }
    if (data.image) {
      formData.append("image", data.image);
    }

    const response = await axiosInstance.put(
      `/admin/on-boarding/${id}`,
      formData,
      {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      },
    );

    return response.data;
  },

  deleteOnBoardingItem: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/on-boarding/${id}`);
  },

  fetchAllOnBoardingItems: async (): Promise<OnBoardingItem[]> => {
    const response = await axiosInstance.get(
      "/admin/on-boarding?limit=1000&skip=0",
    );
    return response.data?.items || [];
  },
};
