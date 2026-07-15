import { z } from "zod";

export const refundReasonIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createRefundReasonSchema = z.object({
  reason_en: z.string().trim().min(1).max(255),
  reason_ar: z.string().trim().min(1).max(255),
});

export const updateRefundReasonSchema = createRefundReasonSchema.partial();

export const deleteRefundReasonsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type CreateRefundReasonInput = z.infer<typeof createRefundReasonSchema>;

export type UpdateRefundReasonInput = z.infer<typeof updateRefundReasonSchema>;

export type DeleteRefundReasonsInput = z.infer<
  typeof deleteRefundReasonsSchema
>;
