export interface Role {
  id: number;
  name: string;
  name_ar: string;
  description: string | null;
  description_ar: string | null;
  created_at: string;
  updated_at: string;
}

export interface RoleFilter {
  id: string;
  name: string;
  name_ar: string;
  description: string;
  description_ar: string;
  created_atFrom: string;
  created_atTo: string;
  updated_atFrom: string;
  updated_atTo: string;
}

export interface PaginatedRolesResponse {
  totalRoles: number;
  totalPages: number;
  roles: Role[];
}

export interface CreateRolePayload {
  name: string;
  name_ar: string;
  description: string | null;
  description_ar: string | null;
}

export interface UpdateRolePayload {
  name?: string;
  name_ar?: string;
  description?: string | null;
  description_ar?: string | null;
}
