export interface Role {
  id: number;
  name: string;
  name_ar: string;
  description: string | null;
  description_ar: string | null;
  created_at: string;
  updated_at: string;
}

export interface Badge {
  id: number;
  role_id: number;
  name: string;
  name_ar: string;
  image: string;
  description: string;
  description_ar: string;
  min_count: number;
  max_count: number;
  ratio: number;
  created_at: string;
  updated_at: string;
  role?: Role;
}

export interface BadgeFilter {
  id: string;
  name: string;
  name_ar: string;
  role_id: string;
  min_countFrom: string;
  min_countTo: string;
  max_countFrom: string;
  max_countTo: string;
  ratioFrom: string;
  ratioTo: string;
  created_atFrom: string;
  created_atTo: string;
  updated_atFrom: string;
  updated_atTo: string;
}

export interface PaginatedBadgesResponse {
  totalBadges: number;
  totalPages: number;
  badges: Badge[];
}

export interface RolesResponse {
  totalRoles: number;
  totalPages: number;
  roles: Role[];
}

export interface CreateBadgePayload {
  name: string;
  name_ar: string;
  description: string;
  description_ar: string;
  min_count: number;
  max_count: number;
  ratio: number;
  role_id: number;
  image: File | null;
}

export interface UpdateBadgePayload {
  name?: string;
  name_ar?: string;
  description?: string;
  description_ar?: string;
  min_count?: number;
  max_count?: number;
  ratio?: number;
  role_id?: number;
  deleteImage?: boolean;
  image?: File | null;
}
