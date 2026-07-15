import z from "zod";

export const reviewIdParamSchema = z.object({
  orderId: z.string().regex(/^\d+$/, "Invalid order ID").transform(Number),
});

export const allReviewsSchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
  ratingFrom: z.string().regex(/^\d+$/).transform(Number).optional(),
  ratingTo: z.string().regex(/^\d+$/).transform(Number).optional(),
  created_atFrom: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  created_atTo: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

export const  submitReviewSchema = z.object({
  rating: z.number().min(1).max(5),
  comment: z.string().optional(),
});
