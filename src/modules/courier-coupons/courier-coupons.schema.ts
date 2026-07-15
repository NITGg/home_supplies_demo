import { z } from "zod";

export const courierCouponIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const userIdParamSchema = z.object({
  userId: z.coerce.number().int().positive(),
});

const courierCouponBaseSchema = z.object({
  title: z.string().trim().min(1).max(255),
  title_ar: z.string().trim().max(255).optional().nullable(),
  description: z.string().optional().nullable(),
  description_ar: z.string().optional().nullable(),
  price: z.coerce.number().positive(),
  bonus_courier_fee: z.coerce.number().min(0),
  duration_days: z.coerce.number().int().positive(),
  is_active: z.boolean().optional().default(true),
});

export const createCourierCouponSchema = courierCouponBaseSchema;

export const updateCourierCouponSchema = courierCouponBaseSchema.partial();

export const deleteManyCourierCouponsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
  archived: z.boolean().optional(),
});
export const deleteCourierCouponsSchema = z.object({
  id: z.coerce.number().int().positive(),
  archived: z.boolean().optional(),
});

export const validateCourierCouponSchema = z.object({
  coupon_id: z.coerce.number().int().positive(),
});

export type CreateCourierCouponInput = z.infer<
  typeof createCourierCouponSchema
>;
export type UpdateCourierCouponInput = z.infer<
  typeof updateCourierCouponSchema
>;
export type DeleteManyCourierCouponsInput = z.infer<
  typeof deleteManyCourierCouponsSchema
>;
export type ValidateCourierCouponInput = z.infer<
  typeof validateCourierCouponSchema
>;
