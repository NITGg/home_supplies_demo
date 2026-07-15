import { z } from "zod";

export const courierReviewIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createCustomerReviewFromCourierSchema = z.object({
  courier_id: z.coerce.number().int().positive(),
  customer_id: z.coerce.number().int().positive(),
  order_id: z.coerce.number().int().positive().optional().nullable(),
  rating: z.coerce.number().int().min(1).max(5),
  comment: z.string().trim().optional().nullable(),
});

export const updateCustomerReviewFromCourierSchema = z
  .object({
    courier_id: z.coerce.number().int().positive().optional(),
    customer_id: z.coerce.number().int().positive().optional(),
    order_id: z.coerce.number().int().positive().optional().nullable(),
    rating: z.coerce.number().int().min(1).max(5).optional(),
    comment: z.string().trim().optional().nullable(),
  })
  .refine(
    (data) =>
      data.courier_id !== undefined ||
      data.customer_id !== undefined ||
      data.order_id !== undefined ||
      data.rating !== undefined ||
      data.comment !== undefined,
    { message: "At least one field is required" },
  );

export const deleteManyCourierReviewsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type CreateCustomerReviewFromCourierInput = z.infer<
  typeof createCustomerReviewFromCourierSchema
>;
export type UpdateCustomerReviewFromCourierInput = z.infer<
  typeof updateCustomerReviewFromCourierSchema
>;
export type DeleteManyCourierReviewsInput = z.infer<
  typeof deleteManyCourierReviewsSchema
>;
