import { z } from "zod";

export const createRoleSchema = z.object({
  name: z
    .string()
    .min(2, "roles:errors.name_min")
    .max(100, "roles:errors.name_max"),
  name_ar: z
    .string()
    .min(2, "roles:errors.name_ar_min")
    .max(100, "roles:errors.name_ar_max"),

  description: z
    .string()
    .max(100, "roles:errors.desc_max")
    .optional()
    .nullable(),
  description_ar: z
    .string()
    .max(100, "roles:errors.desc_ar_max")
    .optional()
    .nullable(),
});

export type CreateRoleInput = z.infer<typeof createRoleSchema>;

export const updateRoleSchema = createRoleSchema.partial();
export type UpdateRoleInput = z.infer<typeof updateRoleSchema>;

export const roleIdParamSchema = z.object({
  id: z.coerce.number().int().positive("roles:errors.role_id_invalid"),
});

export const deleteRolesSchema = z.object({
  ids: z
    .array(z.coerce.number().int().positive("roles:errors.role_id_invalid"))
    .min(1, "roles:errors.ids_min_1"),
});

export type DeleteRolesInput = z.infer<typeof deleteRolesSchema>;

export const deleteRoleSchema = z.object({
  id: z.coerce.number().int().positive("roles:errors.role_id_invalid"),
});
export type DeleteRoleInput = z.infer<typeof deleteRoleSchema>;
