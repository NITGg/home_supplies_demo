import axiosInstance from "@/lib/axios";
import {
  CourierOffice,
  CourierOfficeFilter,
  CreateCourierOfficePayload,
  PaginatedCourierOfficesResponse,
  UpdateCourierOfficePayload,
} from "@/types/courierOffice";

export const courierOfficeService = {
  fetchCourierOffices: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<CourierOfficeFilter> = {},
  ): Promise<PaginatedCourierOfficesResponse> => {
    const skip = (page - 1) * limit;
    const params = new URLSearchParams();

    params.append("limit", limit.toString());
    params.append("skip", skip.toString());
    params.append("sort", sort);

    if (filters.name) params.append("name[contains]", filters.name.trim());
    if (filters.address)
      params.append("address[contains]", filters.address.trim());
    if (filters.email) params.append("email[contains]", filters.email.trim());
    if (filters.phone) {
      params.append("items", "phone");
      params.append("keyword", filters.phone.trim());
    }

    const response = await axiosInstance.get(
      `/admin/courier-office/all-courier-offices?${params.toString()}`,
    );
    return response.data.data;
  },

  fetchCourierOfficeDetails: async (id: number): Promise<CourierOffice | null> => {
    const response = await axiosInstance.get(
      "/admin/courier-office/all-courier-offices?limit=1000&skip=0",
    );
    const couriers: CourierOffice[] = response.data?.data?.couriers || [];
    return couriers.find((office) => office.id === id) || null;
  },

  createCourierOffice: async (
    data: CreateCourierOfficePayload,
  ): Promise<CourierOffice> => {
    const response = await axiosInstance.post(
      "/admin/courier-office/create-courier-office",
      data,
    );
    return response.data?.data || response.data;
  },

  updateCourierOffice: async (
    id: number,
    data: UpdateCourierOfficePayload,
  ): Promise<CourierOffice> => {
    const response = await axiosInstance.put(
      `/admin/courier-office/update-courier-office/${id}`,
      data,
    );
    return response.data?.data || response.data;
  },

  deleteCourierOffice: async (id: number): Promise<void> => {
    await axiosInstance.delete(
      `/admin/courier-office/delete-courier-office/${id}`,
    );
  },
};
