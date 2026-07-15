import { z } from "zod";

export const contactUsIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createContactUsSchema = z.object({
  name: z.string().trim().min(1).max(255),
  email: z.email().max(255),
  message: z.string().trim().min(1),
});

export const updateContactUsSchema = z.object({
  response: z.string().trim().optional().nullable(),
  read: z.boolean().optional(),
  read_at: z.coerce.date().optional().nullable(),
});

export const deleteContactUsSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const deleteManyContactUsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type ContactUsIdParamInput = z.infer<typeof contactUsIdParamSchema>;
export type CreateContactUsInput = z.infer<typeof createContactUsSchema>;
export type UpdateContactUsInput = z.infer<typeof updateContactUsSchema>;
export type DeleteManyContactUsInput = z.infer<typeof deleteManyContactUsSchema>;
