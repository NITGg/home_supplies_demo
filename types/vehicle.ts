export interface Vehicle {
  id: number;
  name: string;
  name_ar: string;
  price_per_km: string;
  min_distance_per_km: number;
  max_distance_per_km: number;
  min_delivery_fee: number;
  delivery_price_for_each_1m: number;
  delivery_fee_ratio: number;
  total_fines: number;
  icon: string | null;
  created_at: string;
  updated_at: string | null;
}

export interface PaginatedVehiclesResponse {
  vehicles: Vehicle[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    total_pages: number;
    has_next: boolean;
    has_prev: boolean;
  };
}

export interface CreateVehiclePayload {
  name: string;
  name_ar: string;
  price_per_km: string;
  min_distance_per_km: number;
  max_distance_per_km: number;
  min_delivery_fee: string;
  // delivery_price_for_each_1m: string;
  delivery_fee_ratio: string;
  total_fines: string;
  icon?: File | null;
}

export interface UpdateVehiclePayload {
  name?: string;
  name_ar?: string;
  price_per_km?: string;
  min_distance_per_km?: number;
  max_distance_per_km?: number;
  min_delivery_fee: string;
  // delivery_price_for_each_1m: string;
  delivery_fee_ratio: string;
  total_fines: string;
  icon?: File | null;
  deleteIcon?: boolean;
}

export interface VehicleFilter {
  name: string;
  name_ar: string;
  price_per_km: string;
  min_distance_per_kmFrom: string;
  min_distance_per_kmTo: string;
  max_distance_per_kmFrom: string;
  max_distance_per_kmTo: string;
  min_delivery_feeFrom: string;
  min_delivery_feeTo: string;
  // delivery_price_for_each_1mFrom: string;
  // delivery_price_for_each_1mTo: string;
  delivery_fee_ratioFrom: string;
  delivery_fee_ratioTo: string;
  total_finesFrom: string;
  total_finesTo: string;
}

