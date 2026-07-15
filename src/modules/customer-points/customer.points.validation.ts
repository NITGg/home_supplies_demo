import z from "zod";

// Buy Coupon Params Schema
export const buyCouponUsingPointsSchema = z.object({
  couponId: z.string().regex(/^\d+$/).transform(Number),
});

// convertPointsToMoneySchema
export const convertPointsToMoneySchema = z.object({
  userId: z.string().regex(/^\d+$/).transform(Number),
  piontsToMoney: z.number(),
});

// payFinesSchema
export const payFinesSchema = z.object({
  user_id: z.string().regex(/^\d+$/).transform(Number),
  penalty_ids: z.array(z.number().int().positive()).optional(),
  commission_ids: z.array(z.number().int().positive()).optional(),
});

// payFinesUsingPointsSchema
export const payFinesUsingPointsSchema = z.object({
  user_id: z.string().regex(/^\d+$/).transform(Number),
  penalty_ids: z.array(z.number().int().positive()).optional(),
  commission_ids: z.array(z.number().int().positive()).optional(),
});