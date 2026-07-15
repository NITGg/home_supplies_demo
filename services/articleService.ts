import axiosInstance from "@/lib/axios";
import {
  CreateArticlePayload,
  ArticleFilter,
  PaginatedArticleResponse,
  UpdateArticlePayload,
} from "@/types/article";

export const articleService = {
  fetchArticles: async (
    page: number = 1,
    limit: number = 12,
    sort: string = "id",
    filters: Partial<ArticleFilter> = {},
  ): Promise<PaginatedArticleResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.id) params.append("id", filters.id.trim());
    if (filters.title) params.append("title[contains]", filters.title.trim());
    if (filters.summary) params.append("summary[contains]", filters.summary.trim());
    if (filters.content) params.append("content[contains]", filters.content.trim());
    if (filters.slug) params.append("slug[contains]", filters.slug.trim());
    if (filters.created_from) params.append("created_at[gte]", filters.created_from);
    if (filters.created_to) params.append("created_at[lte]", filters.created_to);
    if (filters.updated_from) params.append("updated_at[gte]", filters.updated_from);
    if (filters.updated_to) params.append("updated_at[lte]", filters.updated_to);

    const response = await axiosInstance.get(
      `/admin/articles?${params.toString()}`,
    );
    return response.data;
  },

  createArticle: async (data: CreateArticlePayload) => {
    const formData = new FormData();
    formData.append("title", data.title);
    formData.append("summary", data.summary);
    formData.append("content", data.content);
    formData.append("keywords", data.keywords);
    formData.append("published_at", data.published_at);
    formData.append("author", data.author);
    if (data.cover_image) {
      formData.append("cover_image", data.cover_image);
    }

    const response = await axiosInstance.post("/admin/articles", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data;
  },

  updateArticle: async (id: number, data: UpdateArticlePayload) => {
    const formData = new FormData();
    if (data.title !== undefined) formData.append("title", data.title);
    if (data.summary !== undefined) formData.append("summary", data.summary);
    if (data.content !== undefined) formData.append("content", data.content);
    if (data.keywords !== undefined) formData.append("keywords", data.keywords);
    if (data.published_at !== undefined) formData.append("published_at", data.published_at);
    if (data.author !== undefined) formData.append("author", data.author);
    if (data.cover_image) {
      formData.append("cover_image", data.cover_image);
    }

    const response = await axiosInstance.put(`/admin/articles/${id}`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data;
  },

  deleteArticle: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/articles/${id}`);
  },
};
