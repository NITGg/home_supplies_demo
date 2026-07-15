import { z } from "zod";

const badgeBaseSchema = z.object({
  role_id: z.coerce.number().int().positive("badges:errors.role_id_invalid"),

  name: z
    .string()
    .min(2, "badges:errors.name_min")
    .max(100, "badges:errors.name_max"),

  name_ar: z
    .string()
    .min(2, "badges:errors.name_ar_min")
    .max(100, "badges:errors.name_ar_max"),

  image: z.string().max(255).optional().nullable(),

  description: z
    .string()
    .max(100, "badges:errors.desc_max")
    .optional()
    .nullable(),
  description_ar: z
    .string()
    .max(100, "badges:errors.desc_ar_max")
    .optional()
    .nullable(),

  min_count: z.coerce
    .number()
    .min(0, "badges:errors.min_count_invalid")
    .max(1_000_000, "badges:errors.min_count_invalid")
    .refine(Number.isFinite, { message: "badges:errors.min_count_invalid" }),

  max_count: z.coerce
    .number()
    .refine(Number.isFinite, { message: "badges:errors.max_count_invalid" }),

  ratio: z.coerce.number().positive("badges:errors.ratio_invalid"),
});

export const createBadgeSchema = badgeBaseSchema.superRefine((data, ctx) => {
  if (data.max_count < data.min_count) {
    ctx.addIssue({
      code: "custom",
      message: "badges:errors.max_less_than_min",
      path: ["max_count"],
    });
  }
});

export type CreateBadgeInput = z.infer<typeof createBadgeSchema>;

// ✅ update = partial first, then refine only if both are provided
export const updateBadgeSchema = badgeBaseSchema
  .extend({
    deleteImage: z.coerce.boolean().optional(),
  })
  .partial()
  .superRefine((data, ctx) => {
    // only validate range if both are provided in update payload
    if (
      data.min_count !== undefined &&
      data.max_count !== undefined &&
      data.max_count < data.min_count
    ) {
      ctx.addIssue({
        code: "custom",
        message: "badges:errors.max_less_than_min",
        path: ["max_count"],
      });
    }
  });

export type UpdateBadgeInput = z.infer<typeof updateBadgeSchema>;

export const badgeIdParamSchema = z.object({
  id: z.coerce.number().int().positive("badges:errors.badge_id_invalid"),
});

export const deleteBadgesSchema = z.object({
  ids: z
    .array(z.coerce.number().int().positive("badges:errors.badge_id_invalid"))
    .min(1, "badges:errors.ids_min_1"),
});

export type DeleteBadgesInput = z.infer<typeof deleteBadgesSchema>;
