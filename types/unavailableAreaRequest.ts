export type UnavailableAreaRequestType = "PICKUP" | "DELIVERY";

export interface UnavailableAreaRequest {
  id: number;
  customer_id: number | null;
  customer?: {
    id: number;
    full_name: string;
    phone: string;
    role_id: number;
  } | null;
  request_type: UnavailableAreaRequestType;
  lat?: number | string | null;
  long?: number | string | null;
  address?: string | null;
  area: string;
  governorate: string;
  created_at: string;
}

export interface UnavailableAreaRequestFilter {
  request_type: string;
  area: string;
  governorate: string;
  customer_id: string;
  from: string;
  to: string;
}

// Updated to match the new backend shape
export interface UnavailableAreaRequestStats {
  byArea: { name: string; count: number }[];
  byGovernorate: { name: string; count: number }[];
  byType: { name: string; count: number }[];
  topAreasPerGovernorate: Record<string, { name: string; count: number }[]>;
}

export interface PaginatedUnavailableAreaRequestsResponse {
  items: UnavailableAreaRequest[];
  total: number;
  totalPages: number;
}
