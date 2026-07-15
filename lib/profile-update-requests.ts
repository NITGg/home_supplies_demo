import api from "./api";

export type ProfileUpdateStatus = "PENDING" | "APPROVED" | "REJECTED";

export interface ProfileUpdateRequest {
  id: number;
  user_id: number;
  data: Record<string, unknown>;
  status: ProfileUpdateStatus;
  reject_reason?: string | null;
  created_at: string;
  updated_at?: string | null;
}

export interface ProfileUpdateRequestsResponse {
  requests: ProfileUpdateRequest[];
  pagination: { total: number; total_pages: number; page: number; limit: number };
}

export async function fetchProfileUpdateRequests(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: ProfileUpdateRequestsResponse }>(
    "/admin/approval/profile-update-requests",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}

export async function approveProfileUpdateRequest(requestId: number) {
  const res = await api.post(`/admin/approval/profile-update-requests/${requestId}/approve`);
  return res.data;
}

export async function rejectProfileUpdateRequest(requestId: number, reject_reason: string) {
  const res = await api.post(`/admin/approval/profile-update-requests/${requestId}/reject`, { reject_reason });
  return res.data;
}
