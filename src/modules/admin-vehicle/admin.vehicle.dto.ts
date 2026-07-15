import z from "zod";
import {
  createVehicleSchema,
  listVehiclesSchema,
  updateVehicleSchema,
  vehicleIdSchema,
} from "./admin.vehicle.validation";

export type ListVehiclesQueryDto = z.infer<typeof listVehiclesSchema>;
export type VehicleIdDto = z.infer<typeof vehicleIdSchema>;
export type CreateVehicleDto = z.infer<typeof createVehicleSchema>;
export type UpdateVehicleDto = z.infer<typeof updateVehicleSchema>;
