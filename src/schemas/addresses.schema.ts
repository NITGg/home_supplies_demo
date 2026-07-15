import { z } from "zod";

export const createAddressSchema = z.object({
  area_id: z.coerce.number().int().positive("profile:errors.area_id_invalid"),
  address_lat: z.coerce.string().optional().nullable(),
  address_long: z.coerce.string().optional().nullable(),
  name: z.string().optional().nullable(),
  is_default: z.coerce.boolean().optional(),
  detailed_address: z
    .string()
    .min(3, "profile:errors.address_min")
    .max(1000, "profile:errors.address_max"),
});

export type CreateAddressInput = z.infer<typeof createAddressSchema>;

export const updateAddressSchema = createAddressSchema.partial();
export type UpdateAddressInput = z.infer<typeof updateAddressSchema>;

export const updateAdminAddressSchema = createAddressSchema
  .extend({
    deleted_at: z.coerce.date().nullable().optional(),
  })
  .partial();
export type UpdateAdminAddressInput = z.infer<typeof updateAdminAddressSchema>;

export const addressIdParamSchema = z.object({
  id: z.coerce.number().int().positive("profile:errors.address_id_invalid"),
});

export const userIdParamSchema = z.object({
  userId: z.coerce.number().int().positive("users:errors.user_id_invalid"),
});

export const userAddressParamsSchema = z.object({
  userId: z.coerce.number().int().positive("users:errors.user_id_invalid"),
  addressId: z.coerce
    .number()
    .int()
    .positive("profile:errors.address_id_invalid"),
});

export const adminDeleteAddressesSchema = z.object({
  addressIds: z
    .array(
      z.coerce.number().int().positive("profile:errors.address_id_invalid"),
    )
    .min(1, "profile:errors.address_ids_min"),
  archived: z.boolean().optional().default(true),
});
export type AdminDeleteAddressesInput = z.infer<
  typeof adminDeleteAddressesSchema
>;

export const adminDeleteAddressSchema = z.object({
  id: z.coerce
    .number()
    .int()
    .positive("users:errors.user_id_invalid")
    .min(1, "users:errors.id_min_1"),
  archived: z.boolean().optional().default(true),
});

export type AdminDeleteAddressInput = z.infer<typeof adminDeleteAddressSchema>;
