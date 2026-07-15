import axiosInstance from "@/lib/axios";
import { GetOnlineCouriersAPIResponse, OnlineCouriersResponse, User, UserFilter, UserListResponse } from "@/types/user";

interface FetchUsersParams {
  page?: number;
  limit?: number;
  sort?: string;
  filters?: UserFilter;
}

interface CreateUserPayload {
  full_name: string;
  email?: string;
  phone: string;
  password: string;
  gender?: string;
  role_id: number;
  badge_id?: number | null;
  lang?: string;
  is_active?: boolean;
  is_email_verified?: boolean;
  is_phone_verified?: boolean;
  fcm_token?: string | null;
  google_id?: string | null;
  apple_id?: string | null;
  last_login_at?: string | null;
  login_type?: string;
}

interface UpdateUserPayload {
  full_name?: string;
  email?: string;
  phone?: string;
  password?: string;
  gender?: string;
  role_id?: number;
  badge_id?: number | null;
  lang?: string;
  is_active?: boolean;
  is_email_verified?: boolean;
  is_phone_verified?: boolean;
  deleted_at?: string | null;
  wallet?: {
    balance: number;
    points?: number;
  };
}

export const userService = {
  async fetchUsers(
    page = 1,
    limit = 5,
    sort = "-created_at",
    filters?: UserFilter,
  ): Promise<UserListResponse> {
    const parseNumberParam = (value: unknown) => {
      if (typeof value === "number") return value;
      if (typeof value === "string") {
        const trimmed = value.trim();
        if (trimmed === "") return value;
        const parsed = Number(trimmed);
        return Number.isNaN(parsed) ? value : parsed;
      }
      return value;
    };

    const skip = (page - 1) * limit;
    const params: Record<string, any> = {
      skip,
      limit,
      sort,
      includes:
        "courier=id,courier=lat,courier=lng,courier=last_location_update,courier=national_id_number,courier.courierOffice",
    };

    if (filters) {
      // Text fields that should use "contains" operator
      const textFields = ["full_name", "email", "phone"];
      // Courier search fields (keyword-based)
      const courierSearchFields = ["vehicle_plate", "national_id_number"];
      const courierItemsMap: Record<string, string> = {
        vehicle_plate: "courier.vehicle_plate",
        national_id_number: "courier.national_id_number",
      };
      // Courier nested fields (direct pass-through)
      const courierNestedFields = ["is_approved"];
      const courierSearchItems: string[] = [];

      Object.entries(filters).forEach(([key, value]) => {
        if (value !== "" && value !== undefined && value !== null) {
          // Handle id as an exact match (not contains)
          if (key === "id") {
            params.id = parseNumberParam(value);
          }
          // Handle vehicle_id with courier[vehicle][id] format
          else if (key === "vehicle_id") {
            params["courier[vehicle][id]"] = parseNumberParam(value);
          }
          // Filter users by courier selected areas (exact match ids)
          else if (key === "governorate_id" || key === "area_id") {
            if (key === "area_id") {
              params["courier[selectedAreas][some][area_id]"] =
                parseNumberParam(value);
            } else {
              params["courier[selectedAreas][some][area][governorate_id]"] =
                parseNumberParam(value);
            }
          }
          // Filter users by courier office id
          else if (key === "courier_office_id") {
            params["courier[courier_office_id]"] = parseNumberParam(value);
          }
          // Handle courier nested fields directly
          else if (courierNestedFields.includes(key)) {
            if (key === "is_approved") {
              params[`courier[${key}]`] =
                value === "true" ? true : value === "false" ? false : value;
            } else {
              params[`courier[${key}]`] =
                value === "true" ? true : value === "false" ? false : value;
            }
          }
          // Handle courier search fields (keyword-based)
          else if (courierSearchFields.includes(key)) {
            courierSearchItems.push(courierItemsMap[key]);
            // Set keyword from first courier search field found
            if (!params.keyword) {
              params.keyword = value;
            }
          }
          // Handle text fields with contains operator
          else if (textFields.includes(key)) {
            params[`${key}[contains]`] = value;
          }
          // Handle date range fields
          else if (key === "created_atFrom") {
            params["created_at[gte]"] = value;
          } else if (key === "created_atTo") {
            params["created_at[lte]"] = value;
          } else if (key === "updated_atFrom") {
            params["updated_at[gte]"] = value;
          } else if (key === "updated_atTo") {
            params["updated_at[lte]"] = value;
          }
          // Other fields (select filters)
          else {
            params[key] = value;
          }
        }
      });

      // Add items param if courier search fields were found
      if (courierSearchItems.length > 0) {
        params.items = courierSearchItems.join(",");
      }
    }

    const response = await axiosInstance.get("/users", { params });
    return response.data.data ? response.data.data : response.data;
  },

  async fetchCouriers(
    page = 1,
    limit = 5,
    sort = "-created_at",
    filters?: UserFilter,
  ): Promise<UserListResponse> {
    const params: Record<string, any> = {
      page,
      limit,
    };

    if (filters) {
      // Map filters to courier endpoint parameters
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== "" && value !== undefined && value !== null) {
          // Map user fields to user_ prefixed fields for courier endpoint
          if (key === "full_name") {
            params["user_full_name"] = value;
          } else if (key === "email") {
            params["user_email"] = value;
          } else if (key === "phone") {
            params["user_phone"] = value;
          } else if (key === "is_active") {
            params["user_is_active"] =
              value === "true" ? true : value === "false" ? false : value;
          }
          // Map date fields to courier endpoint format
          else if (key === "created_atFrom") {
            params["created_atFrom"] = value;
          } else if (key === "created_atTo") {
            params["created_atTo"] = value;
          } else if (key === "updated_atFrom") {
            params["updated_atFrom"] = value;
          } else if (key === "updated_atTo") {
            params["updated_atTo"] = value;
          }
          // Direct pass-through fields for courier endpoint
          else if (
            [
              "id",
              "user_id",
              "vehicle_plate",
              "is_approved",
              "governorate_id",
              "area_id",
              "vehicle_id",
              "courier_office_id",
            ].includes(key)
          ) {
            if (key === "is_approved") {
              params[key] =
                value === "true" ? true : value === "false" ? false : value;
            } else if (key === "vehicle_id") {
              params["vehicle_id"] = value;
            } else {
              params[key] = value;
            }
          }
        }
      });
    }

    const response = await axiosInstance.get("/admin/approval/all-couriers", {
      params,
    });
    // Normalize response format to match UserListResponse
    // API returns: { data: { couriers: [...], pagination: {...} } }
    // Each courier has nested user object that needs to be flattened
    const couriers = response.data?.data?.couriers || [];
    const pagination = response.data?.data?.pagination || {};

    // Flatten courier objects to match User structure expected by the table
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const normalizedUsers = couriers.map((courier: any) => ({
      ...courier.user, // Flatten user fields (full_name, email, phone, etc.)
      id: courier.user_id || courier.user?.id, // Use user_id as the main id
      role_id: 2, // Couriers have role_id = 2
      courier: {
        id: courier.id,
        courier_office_id: courier.courier_office_id,
        courierOffice: courier.courierOffice ?? null,
        vehicle_type: courier.vehicle_type,
        vehicle_plate: courier.vehicle_plate,
        national_id_number: courier.national_id_number,
        is_approved: courier.is_approved,
        selectedAreas: courier.selectedAreas,
        lat: courier.lat ?? null,
        lng: courier.lng ?? null,
        last_location_update: courier.last_location_update ?? null,
      },
    }));

    return {
      users: normalizedUsers,
      totalUsers: pagination.total || 0,
      totalPages: pagination.total_pages || 1,
    };
  },

  async fetchUserById(userId: number): Promise<{ data: User }> {
    const response = await axiosInstance.get(`/users/${userId}`);
    return response.data.data
      ? { data: response.data.data }
      : { data: response.data };
  },

  async createUser(
    payload: CreateUserPayload,
    photo?: File,
  ): Promise<{ data: User }> {
    const formData = new FormData();

    // Add all fields to form data
    Object.entries(payload).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        if (typeof value === "object") {
          formData.append(key, JSON.stringify(value));
        } else {
          formData.append(key, String(value));
        }
      }
    });

    // Add photo if provided
    if (photo) {
      formData.append("photo", photo);
    }

    const response = await axiosInstance.post("/users", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data;
  },

  async updateUser(
    userId: number,
    payload: UpdateUserPayload,
    photo?: File,
  ): Promise<{ data: User }> {
    const formData = new FormData();

    // Add all fields to form data
    Object.entries(payload).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        if (typeof value === "object") {
          formData.append(key, JSON.stringify(value));
        } else {
          formData.append(key, String(value));
        }
      }
    });

    // Add photo if provided
    if (photo) {
      formData.append("photo", photo);
    }

    const response = await axiosInstance.put(`/users/${userId}`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    return response.data;
  },

  async deleteUser(
    userId: number,
    payload: { archived: boolean },
  ): Promise<void> {
    await axiosInstance.delete(`/users/${userId}`, { data: payload });
  },

  async fetchRoles(): Promise<any[]> {
    const response = await axiosInstance.get("/roles");
    // Handle both nested and flat response structures
    return (
      response.data?.roles || response.data?.data?.roles || response.data || []
    );
  },

  async fetchBadges(): Promise<any[]> {
    const response = await axiosInstance.get("/badges");
    // Handle both nested and flat response structures
    return (
      response.data?.badges ||
      response.data?.data?.badges ||
      response.data ||
      []
    );
  },

  async fetchBadgesByRoleId(roleId: number): Promise<any[]> {
    const response = await axiosInstance.get(`/badges?role[id]=${roleId}`);
    return (
      response.data?.badges ||
      response.data?.data?.badges ||
      response.data ||
      []
    );
  },

  async fetchAllUserIds(): Promise<number[]> {
    const params: Record<string, any> = {
      limit: 10000, // Fetch all users to get IDs
      skip: 0,
      sort: "id",
    };

    const response = await axiosInstance.get("/users", { params });
    const data = response.data.data ? response.data.data : response.data;
    const users = data.users || [];
    return users
      .map((user: { id: number }) => user.id)
      .sort((a: number, b: number) => a - b);
  },

  async fetchProfile(): Promise<{ data: User }> {
    const response = await axiosInstance.get("/profile");
    // API returns { user: {...} }
    return { data: response.data.user };
  },

  async getOnlineCouriers(params: {
  order_lat?: string;
  order_lng?: string;
}): Promise<{ data: OnlineCouriersResponse }> {
  const response = await axiosInstance.get<GetOnlineCouriersAPIResponse>(
    "/users/online-couriers",
    { params }
  );

  return {
    data: response.data.online_courier_ids,
  };
}
};
