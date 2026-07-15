import z from "zod";

// ========== availableOrdersSchema ==========
export const availableOrdersSchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional(),
  limit: z.string().regex(/^\d+$/).transform(Number).optional(),
  priceFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  priceTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  created_atFrom: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  created_atTo: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  lat: z
    .string()
    .regex(/^-?\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  lng: z
    .string()
    .regex(/^-?\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  is_scheduled: z
    .string()
    .transform((val) => val === "true" || val === "1")
    .optional(),
  is_ready_for_pickup: z
    .string()
    .transform((val) => val === "true" || val === "1")
    .optional(),
});

// ========== Param Schemas ==========
export const orderIdParamSchema = z.object({
  orderId: z.string().regex(/^\d+$/, "Invalid order ID").transform(Number),
});

// ========== Submit Offer ==========
export const submitOfferSchema = z.object({
  total_fee: z
    .number({ message: "Delivery fee is required" })
    .positive("Delivery fee must be positive"),
  courier_lat: z.number().optional(),
  courier_long: z.number().optional(),
  courier_location_address: z.string().max(255).optional(),
  distance_to_pickup: z.number().optional(),
  estimated_arrival_at_pickup: z.number().int().optional(),
  vehicle_id: z.number().int().optional(),
});

// ========== Report Unavailable Order ==========
export const reportUnavailableOrderSchema = z.object({
  note: z.string().max(500).optional(),
});

// ========== Cancel Other ==========
export const cancelOtherSchema = z.object({
  reason: z
    .string({ message: "Cancellation reason is required" })
    .min(1, "Cancellation reason is required")
    .max(500, "Reason cannot exceed 500 characters"),
});

// ========== Accept Assigned Order ==========
export const acceptAssignedOrderSchema = z.object({
  orderId: z.string().regex(/^\d+$/, "Invalid order ID").transform(Number),
});

// ========== Reject Assigned Order ==========
export const rejectAssignedOrderSchema = z.object({
  orderId: z.string().regex(/^\d+$/, "Invalid order ID").transform(Number),
  reason: z
    .string({ message: "Cancellation reason is required" })
    .min(1, "Cancellation reason is required")
    .max(500, "Reason cannot exceed 500 characters"),
});

// ========== Report High Price ==========
export const reportOrderHighPriceSchema = z.object({
  actual_price: z
    .number({ message: "Actual price is required" })
    .positive("Actual price must be positive"),
});

// ========== Complete Delivery ==========
export const completeDeliverySchema = z.object({
  actual_price: z.number({ message: "Actual price is required" }),
  confirmation_otp: z.string().optional(),
});

// ========== historySchema ==========
export const historySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
  status: z
    .enum(["PENDING", "IN_PROGRESS", "DELIVERED", "CANCELLED"])
    .optional(),
  budgetFrom: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  budgetTo: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  pickup_area_id: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_area_id: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  pickup_lat: z.string().optional(),
  pickup_long: z.string().optional(),
  delivery_lat: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  delivery_long: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  created_atFrom: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  created_atTo: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

// ========== Accept / Reject Fixed-Fee Offer ==========
export const acceptFixedFeeOfferSchema = z.object({
  action: z.enum(["ACCEPT", "REJECT"], {
    message: "Action must be ACCEPT or REJECT",
  }),
  courier_lat: z.number().optional(),
  courier_long: z.number().optional(),
  courier_location_address: z.string().max(255).optional(),
  distance_to_pickup: z.number().optional(),
  estimated_arrival_at_pickup: z.number().int().optional(),
  vehicle_id: z.number().int().optional(),
});

export const updateLocationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});
