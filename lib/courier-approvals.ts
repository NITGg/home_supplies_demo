import api from "./api";

export interface CourierApproval {
  id: number;
  user_id: number;
  vehicle_type?: string | null;
  vehicle_plate?: string | null;
  national_id_number?: string | null;
  is_approved: boolean;
  reject_reason?: string | null;
  lat?: number | null;
  lng?: number | null;
  last_location_update?: string | null;
  // Document photos
  national_id_photo_front?: string | null;
  national_id_photo_back?: string | null;
  vehicle_license_front?: string | null;
  vehicle_license_back?: string | null;
  courier_license_front?: string | null;
  courier_license_back?: string | null;
  courier_criminal_record?: string | null;
  created_at: string;
  updated_at: string;
  user?: { id: number; full_name: string; phone: string; email?: string | null; personal_photo?: string | null } | null;
  governorate?: { id: number; name: string; name_ar: string } | null;
}
export interface CourierApprovalsResponse { couriers: CourierApproval[]; pagination: { total: number; total_pages: number; page: number; limit: number } }

export async function fetchCourierApprovals(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: CourierApprovalsResponse }>("/admin/approval/all-couriers", { params: { page, limit, ...rest } });
  return res.data.data;
}
export async function approveCourier(courierId: number) {
  const res = await api.post(`/admin/approval/approve-courier/${courierId}`);
  return res.data;
}
export async function rejectCourier(courierId: number, reject_reason: string) {
  const res = await api.post(`/admin/approval/reject-courier/${courierId}`, { reject_reason });
  return res.data;
}
