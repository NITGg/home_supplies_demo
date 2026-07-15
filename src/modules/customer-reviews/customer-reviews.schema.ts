import { z } from "zod";

export const customerReviewIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createCourierReviewFromCustomerSchema = z.object({
  courier_id: z.coerce.number().int().positive().optional(),
  order_id: z.coerce.number().int().positive().optional().nullable(),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().trim().optional().nullable(),
});

export const createSupplierReviewFromCustomerSchema = z.object({
  order_id: z.coerce.number().int().positive(),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().trim().optional().nullable(),
});

export const deleteManyCustomerReviewsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type CreateCourierReviewFromCustomerInput = z.infer<
  typeof createCourierReviewFromCustomerSchema
>;
export type CreateSupplierReviewFromCustomerInput = z.infer<
  typeof createSupplierReviewFromCustomerSchema
>;
export type DeleteManyCustomerReviewsInput = z.infer<
  typeof deleteManyCustomerReviewsSchema
>;

export const supplierReviewSourceSchema = z.object({
  review_from: z.enum(["COURIER", "CUSTOMER"]),
});

export type SupplierReviewSourceInput = z.infer<
  typeof supplierReviewSourceSchema
>;
