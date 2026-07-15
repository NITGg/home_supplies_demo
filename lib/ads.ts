import api from "./api";

export type AdStatus = "ACTIVE" | "INACTIVE" | "SCHEDULED" | "PAUSED";
export type AdPlacement = "HOME" | "CATEGORY" | "PRODUCT" | "CHECKOUT" | "SPLASH";

export interface Ad {
  id: number;
  title?: string | null;
  title_ar?: string | null;
  description?: string | null;
  description_ar?: string | null;
  status: AdStatus;
  ad_type?: string | null;
  placement?: AdPlacement | null;
  target_url?: string | null;
  image_url?: string | null;
  start_date?: string | null;
  end_date?: string | null;
  sort_id: number;
  priority?: number | null;
  source?: string | null;
  budget?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface AdsResponse {
  totalCount: number;
  totalPages: number;
  ads: Ad[];
}

export async function fetchAds(params?: Record<string, string | number>) {
  const { page = 1, limit = 12, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<AdsResponse>("/ads", {
    params: { limit, skip, ...rest },
  });
  return res.data;
}

export async function createAd(data: FormData) {
  const res = await api.post("/ads", data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function updateAd(id: number, data: FormData) {
  const res = await api.put(`/ads/${id}`, data, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export async function deleteAd(id: number, permanent = false) {
  const res = await api.delete(`/ads/${id}`, {
    data: { permanent },
  });
  return res.data;
}
