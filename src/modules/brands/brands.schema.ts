import { z } from "zod";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const booleanFromString = z
  .union([z.boolean(), z.string().transform((val) => val === "true")])
  .optional();

const jsonNumberArray = z
  .union([
    z.array(z.number()),
    z.string().transform((val) => {
      try {
        console.log("val:", val);
        
        const parsed = val ? JSON.parse(val) : [];
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }),
  ])
  .optional();

// ─── Base Shape ──────────────────────────────────────────────────────────────

const brandShape = z.object({
  name: z.string().min(1),
  name_ar: z.string().optional(),
  description: z.string().optional(),
  description_ar: z.string().optional(),
  synonyms: z.string().max(191).optional(),
  logo_url: z.string().optional().nullable(),
  cover_url: z.string().optional().nullable(),
  is_active: booleanFromString,
  is_popular: booleanFromString,
  deleted_at: z
    .union([z.string().transform((s) => new Date(s)), z.date()])
    .nullable()
    .optional(),
  categories: jsonNumberArray,
  products: jsonNumberArray,
});

// ─── Schemas ──────────────────────────────────────────────────────────────────

export const brandIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createBrandSchema = brandShape.transform((data) => ({
  ...data,
  slug: data.name.toLowerCase().trim().replaceAll(/\s+/g, "-"),
}));

export const updateBrandSchema = brandShape
  .partial() // Works now because brandShape is a raw ZodObject
  .extend({
    deleteLogoUrl: booleanFromString,
    deleteCoverUrl: booleanFromString,
  })
  .transform((data) => ({
    ...data,
    ...(data.name
      ? { slug: data.name.toLowerCase().trim().replaceAll(/\s+/g, "-") }
      : {}),
  }));

export const reorderBrandsSchema = z.object({
  brands: z
    .array(
      z.object({
        id: z.number().int().positive(),
        sort_id: z.number().int().min(1),
      }),
    )
    .min(1),
});

export const deleteBrandsSchema = z.union([
  z.object({
    isDeleted: z.literal(true),
  }),
  z.object({
    notActive: z.literal(true),
  }),
  z.object({
    ids: z.array(z.number()).min(1),
    permanent: z.boolean().optional(),
  }),
]);

// ─── Types ────────────────────────────────────────────────────────────────────

// Using z.output ensure the slug is included in the inferred type
export type CreateBrandInput = z.output<typeof createBrandSchema>;
export type UpdateBrandInput = z.output<typeof updateBrandSchema>;
export type ReorderBrandsInput = z.infer<typeof reorderBrandsSchema>;
export type DeleteBrandsInput = z.infer<typeof deleteBrandsSchema>;
