import z from "zod";

export const getSellerStatSchema = z.object({
  userId: z.string().regex(/^\d+$/).transform(Number).optional(),
});

export const referralCodeSchema = z.object({
  referral_code: z.string(),
});
