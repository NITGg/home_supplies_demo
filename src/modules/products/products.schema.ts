import { z } from "zod";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const booleanFromString = z
  .union([z.boolean(), z.string().transform((v) => v === "true" || v === "1")])
  .optional();

const jsonNumberArray = z
  .union([
    z.array(z.number()),
    z.string().transform((val) => {
      try {
        const parsed = val ? JSON.parse(val) : [];
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }),
  ])
  .optional();

const jsonStringArray = z
  .union([
    z.array(z.string()),
    z.string().transform((val) => {
      try {
        const parsed = val ? JSON.parse(val) : [];
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }),
  ])
  .optional();

// ─── Shared Schemas ───────────────────────────────────────────────────────────

const attributeEntrySchema = z.object({
  key: z.string().min(1),
  value: z.string(),
  value_ar: z.string().optional(),
});

// ─── Product Base Shape ───────────────────────────────────────────────────────

const productShape = z.object({
  name: z.string().min(1),
  name_ar: z.string().optional(),
  description: z.string().optional(),
  description_ar: z.string().optional(),
  synonyms: z.string().optional(),

  sku: z.string().optional(),
  barcode: z.string().optional(),

  weight: z.coerce.number().optional().nullable(),
  dimensions: z.string().optional().nullable(),
  color: z.string().optional().nullable(),
  category_id: z.coerce.number().int(),
  brand_id: z.coerce.number().int().optional().nullable(),
  sort_id: z.coerce.number().int().optional(),

  refundable: booleanFromString,
  refundable_period: z.coerce.number().optional().nullable(),
  refund_policy: z.string().optional().nullable(),

  attributes: z
    .union([
      z.array(attributeEntrySchema),
      z.string().transform((val) => {
        try {
          const parsed = JSON.parse(val);
          return Array.isArray(parsed) ? parsed : [];
        } catch {
          return [];
        }
      }),
    ])
    .optional(),
});

// ─── Create Schema ────────────────────────────────────────────────────────────

export const createProductSchema = productShape.transform((data) => ({
  ...data,
  slug: data.name.toLowerCase().trim().replaceAll(/\s+/g, "-"),
}));

// ─── Update Schema ────────────────────────────────────────────────────────────

export const updateProductSchema = productShape
  .partial()
  .extend({
    deleteSpecificImages: jsonStringArray,
    deleteAllImages: booleanFromString,
    replaceImages: booleanFromString,
    deleteAttributes: jsonNumberArray,
  })
  .transform((data) => ({
    ...data,
    ...(data.name
      ? { slug: data.name.toLowerCase().trim().replaceAll(/\s+/g, "-") }
      : {}),
  }));

// ─── SupplierProduct Schemas ──────────────────────────────────────────────────

export const supplierProductSchema = z.object({
  supplier_id: z.coerce.number().int(),
  price: z.coerce.number().optional().nullable(),
  cost_price: z.coerce.number().optional().nullable(),
  stock: z.coerce.number().int().default(0),
  min_stock: z.coerce.number().int().default(5),
  is_active: booleanFromString,
  is_featured: booleanFromString,
  is_best_seller: booleanFromString,
  pickup_ready_duration: z.coerce.number().int().optional().nullable(),
  min_amount_for_one_order: z.coerce.number().optional().nullable(),
  max_amount_for_one_order: z.coerce.number().optional().nullable(),
  min_amount_for_one_user: z.coerce.number().optional().nullable(),
  max_amount_for_one_user: z.coerce.number().optional().nullable(),
  reserved_in_carts_amount: z.coerce.number().optional().nullable(),
});

// export const updateSupplierProductSchema = supplierProductSchema
//   .omit({ supplier_id: true })
//   .partial();

// ─── List Products: customer-location options (body) ──────────────────────────

export const listProductsLocationSchema = z.object({
  // current customer location (the radius / governorate / cheapest-per-product
  // behaviour is controlled globally via ApplicationSetting, not the request)
  lat: z.coerce.number().min(-90).max(90).optional(),
  // accept both `lng` and `long` for longitude
  lng: z.coerce.number().min(-180).max(180).optional(),
});

export type ListProductsLocationOptions = z.infer<
  typeof listProductsLocationSchema
>;

// ─── Reorder ──────────────────────────────────────────────────────────────────

export const reorderProductsSchema = z.object({
  products: z
    .array(
      z.object({
        id: z.number().int().positive(),
        sort_id: z.number().int().min(1),
      }),
    )
    .min(1),
});

export const deleteProductsSchema = z.discriminatedUnion("strategy", [
  z.object({ strategy: z.literal("inactive") }),
  z.object({ strategy: z.literal("outOfStock") }),
  z.object({ strategy: z.literal("lowStock") }),
  z.object({
    strategy: z.literal("ids"),
    ids: z.array(z.number().int()).min(1),
    archived: z.boolean().optional(),
  }),
]);

export const productIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const supplierProductParamSchema = z.object({
  id: z.coerce.number().int().positive(),
  spId: z.coerce.number().int().positive(),
});

// ─── Types ────────────────────────────────────────────────────────────────────

export type CreateProductInput = z.output<typeof createProductSchema>;
export type UpdateProductInput = z.output<typeof updateProductSchema>;
export type CreateSupplierProductInput = z.infer<typeof supplierProductSchema>;
// export type UpdateSupplierProductInput = z.infer<typeof updateSupplierProductSchema>;
export type ReorderProductsInput = z.infer<typeof reorderProductsSchema>;
export type DeleteProductsInput = z.infer<typeof deleteProductsSchema>;
