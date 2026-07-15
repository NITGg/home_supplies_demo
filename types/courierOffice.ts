export interface CourierOffice {
  id: number;
  name: string;
  address: string | null;
  phone: string | null;
  email: string | null;
  website: string | null;
  description: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CourierOfficeFilter {
  name: string;
  address: string;
  email: string;
  phone: string;
}

export interface PaginatedCourierOfficesResponse {
  totalCouriers: number;
  totalPages: number;
  couriers: CourierOffice[];
}

export interface CreateCourierOfficePayload {
  name: string;
  address?: string | null;
  phone?: string | null;
  email?: string | null;
  website?: string | null;
  description?: string | null;
}

export interface UpdateCourierOfficePayload {
  name?: string;
  address?: string | null;
  phone?: string | null;
  email?: string | null;
  website?: string | null;
  description?: string | null;
}
