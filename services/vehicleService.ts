import axiosInstance from "@/lib/axios";
import {
  Vehicle,
  PaginatedVehiclesResponse,
  CreateVehiclePayload,
  UpdateVehiclePayload,
  VehicleFilter,
} from "@/types/vehicle";

export const vehicleService = {
  fetchVehicles: async (
    page: number = 1,
    limit: number = 10,
    sort: string = "id",
    filters: Partial<VehicleFilter> = {},
  ): Promise<PaginatedVehiclesResponse> => {
    const params = new URLSearchParams();
    params.append("page", page.toString());
    params.append("limit", limit.toString());
    params.append("sort", sort);

    if (filters.name) params.append("name", filters.name.trim());
    if (filters.name_ar) params.append("name_ar", filters.name_ar.trim());
    if (filters.price_per_km)
      params.append("price_per_km", filters.price_per_km);
    if (filters.min_distance_per_kmFrom)
      params.append("min_distance_per_kmFrom", filters.min_distance_per_kmFrom);
    if (filters.min_distance_per_kmTo)
      params.append("min_distance_per_kmTo", filters.min_distance_per_kmTo);
    if (filters.max_distance_per_kmFrom)
      params.append("max_distance_per_kmFrom", filters.max_distance_per_kmFrom);
    if (filters.max_distance_per_kmTo)
      params.append("max_distance_per_kmTo", filters.max_distance_per_kmTo);

    if (filters.min_delivery_feeFrom)
      params.append("min_delivery_feeFrom", filters.min_delivery_feeFrom);
    if (filters.min_delivery_feeTo)
      params.append("min_delivery_feeTo", filters.min_delivery_feeTo);
    // if (filters.delivery_price_for_each_1mFrom)
    //   params.append(
    //     "delivery_price_for_each_1mFrom",
    //     filters.delivery_price_for_each_1mFrom,
    //   );
    // if (filters.delivery_price_for_each_1mTo)
    //   params.append(
    //     "delivery_price_for_each_1mTo",
    //     filters.delivery_price_for_each_1mTo,
    //   );
    if (filters.delivery_fee_ratioFrom)
      params.append("delivery_fee_ratioFrom", filters.delivery_fee_ratioFrom);
    if (filters.delivery_fee_ratioTo)
      params.append("delivery_fee_ratioTo", filters.delivery_fee_ratioTo);
    if (filters.total_finesFrom)
      params.append("total_finesFrom", filters.total_finesFrom);
    if (filters.total_finesTo)
      params.append("total_finesTo", filters.total_finesTo);

    const response = await axiosInstance.get(
      `/admin/vehicle/list-vehicles?${params.toString()}`,
    );
    return response.data.data;
  },

  createVehicle: async (data: CreateVehiclePayload): Promise<Vehicle> => {
    const formData = new FormData();
    formData.append("name", data.name);
    formData.append("name_ar", data.name_ar);
    formData.append("price_per_km", data.price_per_km);
    formData.append("min_distance_per_km", data.min_distance_per_km.toString());
    formData.append("max_distance_per_km", data.max_distance_per_km.toString());
    formData.append("min_delivery_fee", data.min_delivery_fee.toString());
    // formData.append(
    //   "delivery_price_for_each_1m",
    //   data.delivery_price_for_each_1m.toString(),
    // );
    formData.append("delivery_fee_ratio", data.delivery_fee_ratio.toString());
    formData.append("total_fines", data.total_fines.toString());

    if (data.icon) formData.append("icon", data.icon);

    const response = await axiosInstance.post(
      "/admin/vehicle/create-vehicle",
      formData,
      {
        headers: { "Content-Type": "multipart/form-data" },
      },
    );
    return response.data;
  },

  updateVehicle: async (
    id: number,
    data: UpdateVehiclePayload,
  ): Promise<Vehicle> => {
    const formData = new FormData();
    if (data.name !== undefined) formData.append("name", data.name);
    if (data.name_ar !== undefined) formData.append("name_ar", data.name_ar);
    if (data.price_per_km !== undefined)
      formData.append("price_per_km", data.price_per_km);
    if (data.min_distance_per_km !== undefined)
      formData.append(
        "min_distance_per_km",
        data.min_distance_per_km.toString(),
      );
    if (data.max_distance_per_km !== undefined)
      formData.append(
        "max_distance_per_km",
        data.max_distance_per_km.toString(),
      );
    if (data.min_delivery_fee !== undefined)
      formData.append("min_delivery_fee", data.min_delivery_fee.toString());
    // if (data.delivery_price_for_each_1m !== undefined)
    //   formData.append(
    //     "delivery_price_for_each_1m",
    //     data.delivery_price_for_each_1m.toString(),
    //   );
    if (data.delivery_fee_ratio !== undefined)
      formData.append("delivery_fee_ratio", data.delivery_fee_ratio.toString());
    if (data.total_fines !== undefined)
      formData.append("total_fines", data.total_fines.toString());
    if (data.deleteIcon) formData.append("deleteIcon", "true");
    if (data.icon) formData.append("icon", data.icon);

    const response = await axiosInstance.patch(
      `/admin/vehicle/update-vehicle/${id}`,
      formData,
      {
        headers: { "Content-Type": "multipart/form-data" },
      },
    );
    return response.data;
  },

  deleteVehicle: async (id: number): Promise<void> => {
    await axiosInstance.delete(`/admin/vehicle/delete-vehicle/${id}`);
  },
};
