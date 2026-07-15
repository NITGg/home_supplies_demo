import api from "./api";

export interface CourierOffice {
  id: number;
  name: string;
  address?: string | null;
  phone?: string | null;
  email?: string | null;
  website?: string | null;
  description?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  commission_type: "FIXED_PER_ORDER" | "PERCENTAGE";
  commission_value: string;
  couriers: any;
}
export interface CourierOfficesResponse {
  total: number;
  total_pages: number;
  couriers: CourierOffice[];
}

export async function fetchCourierOffices(
  params?: Record<string, string | number>,
) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<{ data: CourierOfficesResponse }>(
    "/admin/courier-office/all-courier-offices",
    { params: { limit, skip, ...rest } },
  );
  return res.data.data;
}
export async function createCourierOffice(data: {
  name: string;
  address?: string;
  phone?: string;
  email?: string;
  website?: string;
  description?: string;
  commission_type?: "FIXED_PER_ORDER" | "PERCENTAGE";
  commission_value?: number;
}) {
  const res = await api.post(
    "/admin/courier-office/create-courier-office",
    data,
  );
  return res.data;
}
export async function updateCourierOffice(
  id: number,
  data: Partial<{
    name: string;
    address: string;
    phone: string;
    email: string;
    website: string;
    description: string;
    commission_type: "FIXED_PER_ORDER" | "PERCENTAGE";
    commission_value: number;
  }>,
) {
  const res = await api.put(
    `/admin/courier-office/update-courier-office/${id}`,
    data,
  );
  return res.data;
}
export async function deleteCourierOffice(id: number) {
  const res = await api.delete(
    `/admin/courier-office/delete-courier-office/${id}`,
  );
  return res.data;
}
export async function assignCourierToOffice(
  courierId: number,
  courierOfficeId: number,
) {
  const res = await api.post("/admin/courier-office/append-courier-to-office", {
    courierId: String(courierId),
    courierOfficeId: String(courierOfficeId),
  });
  return res.data;
}
