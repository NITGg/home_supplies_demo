import { z } from "zod";

export const govtIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export type GovtIdParamSchema = z.infer<typeof govtIdParamSchema>;

export const createGovtSchema = z.object({
  name: z.string().trim().min(1).max(100),
  name_ar: z.string().trim().min(1).max(100),
  is_active: z.boolean().optional(),
});

export type CreateGovtInput = z.infer<typeof createGovtSchema>;

export const updateGovtSchema = createGovtSchema
  .extend({
    deleted_at: z.coerce.date().nullable(),
  })
  .partial();
export type UpdateGovtInput = z.infer<typeof updateGovtSchema>;

export const deleteManyGovtSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
  archived: z.boolean().optional(),
});

export type DeleteManyGovtInput = z.infer<typeof deleteManyGovtSchema>;

export const deleteGovtSchema = z.object({
  id: z.coerce.number().int().positive(),
  archived: z.boolean().optional(),
});
export type DeleteGovtInput = z.infer<typeof deleteGovtSchema>;
