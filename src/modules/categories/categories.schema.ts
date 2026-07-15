import { z } from "zod";

// ─── Attribute value schema ───────────────────────────────────────────────────

const attributeValueSchema = z.object({
  type: z.enum(["string", "number", "boolean"]),
  enum: z.array(z.union([z.string(), z.number()])).optional(),
  required: z.boolean().default(false),
  default: z.union([z.string(), z.number(), z.boolean()]).optional(),
});

const productAttributesSchema = z.preprocess(
  (val) => {
    if (typeof val === "string") {
      try {
        return JSON.parse(val);
      } catch {
        return {};
      }
    }
    return val;
  },
  z.record(z.string(), attributeValueSchema),
);

// ─── Base Shape ──────────────────────────────────────────────────────────────
// Define the shape first so we can reuse it for Update without .innerType()
const categoryShape = z.object({
  name: z.string().min(1).max(300),
  name_ar: z.string().max(300).optional(),
  description: z.string().max(2000).optional(),
  description_ar: z.string().max(2000).optional(),
  synonyms: z.string().max(500).optional(),

  image_url: z.string().optional().nullable(),
  icon_url: z.string().optional().nullable(),
  parent_id: z
    .union([z.string().transform((v) => Number.parseInt(v, 10)), z.number()])
    .nullable()
    .optional(),
  is_active: z
    .union([
      z.string().transform((val) => val === "true" || val === "1"),
      z.number().transform((val) => val === 1),
      z.boolean(),
    ])
    .default(true),
  sort_id: z.coerce.number().int().optional(),
  product_attributes: productAttributesSchema.optional(),
  has_window: z
    .union([
      z.string().transform((val) => val === "true" || val === "1"),
      z.number().transform((val) => val === 1),
      z.boolean(),
    ])
    .default(true),
});

// ─── Create Schema ────────────────────────────────────────────────────────────

export const createCategorySchema = categoryShape.transform((data) => ({
  ...data,
  slug: data?.name.toLowerCase().trim().replaceAll(/\s+/g, "-"),
}));

// ─── Update Schema ────────────────────────────────────────────────────────────

export const updateCategorySchema = categoryShape
  .partial() // Works perfectly because categoryShape is a raw ZodObject
  .extend({
    delete_image: z
      .union([
        z.string().transform((val) => val === "true" || val === "1"),
        z.number().transform((val) => val === 1),
        z.boolean(),
      ])
      .optional(),
    delete_icon: z
      .union([
        z.string().transform((val) => val === "true" || val === "1"),
        z.number().transform((val) => val === 1),
        z.boolean(),
      ])
      .optional(),
  })
  .transform((data) => ({
    ...data,
    ...(data.name
      ? { slug: data.name.toLowerCase().trim().replaceAll(/\s+/g, "-") }
      : {}),
  }));

// ─── Other schemas ────────────────────────────────────────────────────────────

export const reorderCategoriesSchema = z.object({
  categories: z
    .array(
      z.object({
        id: z.number().int(),
        sort_id: z.number().int(),
      }),
    )
    .min(1),
});

export const categoryIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const deleteCategorySchema = z.object({
  permanent: z.boolean().default(false), // Usually safer to default to soft-delete (false)
});

// ─── Types ────────────────────────────────────────────────────────────────────
export type CreateCategoryInput = z.output<typeof createCategorySchema>;
export type UpdateCategoryInput = z.output<typeof updateCategorySchema>;
export type ReorderCategoriesInput = z.infer<typeof reorderCategoriesSchema>;
