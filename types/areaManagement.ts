export interface Governorate {
  id: number;
  name: string;
  name_ar: string;
  is_active?: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface AreaBoundaryPoint {
  lat: number;
  lng: number;
}

export interface Area {
  id: number;
  governorate_id: number;
  name: string;
  name_ar: string;
  is_active?: boolean;
  boundaries: Record<string, AreaBoundaryPoint>;
  created_at: string;
  updated_at: string;
}

export interface GovernorateListResponse {
  governorates: Governorate[];
  totalCount: number;
  totalPages: number;
}

export interface AreaListResponse {
  areas: Area[];
  totalCount: number;
  totalPages: number;
}

export interface GovernorateFilter {
  id?: string;
  name?: string;
  name_ar?: string;
  is_active?: string;
}

export interface AreaFilter {
  id?: string;
  name?: string;
  name_ar?: string;
  governorate_id?: string;
  is_active?: string;
}
