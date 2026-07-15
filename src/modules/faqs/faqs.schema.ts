import { z } from "zod";

export const faqIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createFaqSchema = z.object({
  question: z.string().trim().min(1).max(255),
  answer: z.string().trim().min(1),
  language: z.enum(["EN", "AR"]).optional(),
  is_active: z.boolean().optional(),
  sort_id: z.coerce.number().int().optional(),
  target_user: z.enum(["CUSTOMER", "COURIER", "ALL"]).optional(),
});

export const updateFaqSchema = createFaqSchema.partial();

export const deleteFaqSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const deleteManyFaqsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type FaqIdParamInput = z.infer<typeof faqIdParamSchema>;
export type CreateFaqInput = z.infer<typeof createFaqSchema>;
export type UpdateFaqInput = z.infer<typeof updateFaqSchema>;
export type DeleteManyFaqsInput = z.infer<typeof deleteManyFaqsSchema>;
