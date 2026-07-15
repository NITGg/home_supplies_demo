import api from "./api";

export type AreaRequestType = "PICKUP" | "DELIVERY";

export interface AreaRequest {
  id: number;
  request_type: AreaRequestType;
  lat?: number | null;
  long?: number | null;
  address?: string | null;
  area: string;
  governorate: string;
  created_at: string;
  customer?: { id: number; full_name: string; phone: string } | null;
}
export interface AreaRequestsResponse {
  total: number;
  totalPages: number;
  items: AreaRequest[];
}
export interface AreaRequestStats {
  data: {
    byArea: { name: string; count: number }[];
    byGovernorate: { name: string; count: number }[];
    byType: { name: string; count: number }[];
    topAreasPerGovernorate: Record<string, { name: string; count: number }[]>;
  };
}

export async function fetchAreaRequests(
  params?: Record<string, string | number>,
) {
  const { page = 1, limit = 20, keyword, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const queryParams: Record<string, string | number> = {
    limit,
    skip,
    includes: "customer=id-full_name-phone",
    items: "governorate,customer.full_name,customer.phone",
    ...rest,
  };
  if (keyword) queryParams.keyword = keyword;
  const res = await api.get<AreaRequestsResponse>("/unavailable-area-request", {
    params: queryParams,
  });
  return res.data;
}
export async function fetchAreaRequestStats() {
  const res = await api.get<AreaRequestStats>(
    "/unavailable-area-request/stats",
  );
  return res.data;
}
export async function deleteAreaRequest(id: number) {
  const res = await api.delete(`/unavailable-area-request/${id}`);
  return res.data;
}
