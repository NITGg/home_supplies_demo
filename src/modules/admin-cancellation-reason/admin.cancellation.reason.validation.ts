import z from "zod";

// ========== reasonSchema ==========
export const reasonSchema = z.object({
  role_id: z.string().regex(/^\d+$/).transform(Number),
  reason_en: z.string(),
  reason_ar: z.string(),
});

// ========== updateReasonSchema ==========
export const updateReasonSchema = z.object({
  reason_en: z.string().optional().optional(),
  reason_ar: z.string().optional().optional(),
});
