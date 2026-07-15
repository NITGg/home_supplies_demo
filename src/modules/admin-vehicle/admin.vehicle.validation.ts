import z from "zod";

// ========== listVehiclesSchema ==========
export const listVehiclesSchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
  name: z.string().optional(),
  name_ar: z.string().optional(),
  price_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  min_distance_per_kmFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  min_distance_per_kmTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  max_distance_per_kmFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  max_distance_per_kmTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  min_delivery_feeFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  min_delivery_feeTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_price_for_each_1mFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_price_for_each_1mTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_fee_ratioFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_fee_ratioTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  total_finesFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  total_finesTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
});

// ========== vehicleIdSchema ==========
export const vehicleIdSchema = z.object({
  vehicleId: z.string().regex(/^\d+$/).transform(Number),
});

const deliveryFields = {
  min_delivery_fee: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_price_for_each_1m: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_fee_ratio: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  total_fines: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),

  fee_base_distance_km: z.coerce.number().positive(),
  fee_extra_platform_per_km: z.coerce.number().positive(),
  fee_extra_courier_per_km: z.coerce.number().positive(),
  peak_time_fee_ratio: z.coerce.number().positive(),
};

// ========== createVehicleSchema ==========
export const createVehicleSchema = z.object({
  name: z.string(),
  name_ar: z.string(),
  price_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number),
  min_distance_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  max_distance_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  ...deliveryFields,
});

// ========== updateVehicleSchema ==========
export const updateVehicleSchema = z.object({
  vehicleId: z.string().regex(/^\d+$/).transform(Number),
  name: z.string().optional(),
  name_ar: z.string().optional(),
  price_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  min_distance_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  max_distance_per_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  ...deliveryFields,
});
