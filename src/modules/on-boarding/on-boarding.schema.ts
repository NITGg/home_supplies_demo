import { z } from "zod";

export const onBoardingIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createOnBoardingSchema = z.object({
  image_url: z.string().optional().nullable(),
  title: z.string().trim().min(1).max(255),
  title_ar: z.string().trim().optional().nullable(),
  content: z.string().trim().optional().nullable(),
  content_ar: z.string().trim().optional().nullable(),
  subtitle: z.string().trim().optional().nullable(),
  subtitle_ar: z.string().trim().optional().nullable(),
  sort_id: z.coerce.number().int().optional(),
  target_user: z.enum(["CUSTOMER", "COURIER", "ALL"]).optional(),
});

export const updateOnBoardingSchema = createOnBoardingSchema
  .extend({
    deleted_at: z.coerce.date().optional().nullable(),
  })
  .partial();

export const deleteOnBoardingSchema = z.object({
  id: z.coerce.number().int().positive(),
  archived: z.boolean().optional(),
});

export const deleteManyOnBoardingSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
  archived: z.boolean().optional(),
});

export type OnBoardingIdParamInput = z.infer<typeof onBoardingIdParamSchema>;
export type CreateOnBoardingInput = z.infer<typeof createOnBoardingSchema>;
export type UpdateOnBoardingInput = z.infer<typeof updateOnBoardingSchema>;
export type DeleteManyOnBoardingInput = z.infer<
  typeof deleteManyOnBoardingSchema
>;
