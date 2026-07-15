import { z } from "zod";

const dateString = z.coerce.date();

// 1. Define the base shape WITHOUT the refinement
const offerBaseShape = z.object({
  supplier_product_id: z.coerce.number().int().positive(),
  offer_type: z.enum(["PERCENT", "FIXED_CENTS"]),
  offer_value: z.coerce.number().positive(),
  start_date: dateString,
  end_date: dateString,
  is_active: z
    .union([
      z.boolean(),
      z.string().transform((v) => v === "true" || v === "1"),
    ])
    .optional(),
  created_by_role: z.enum(["ADMIN", "SUPPLIER"]).optional().default("ADMIN"),
});

// 2. Build Create Schema by adding refinement to the base
export const createOfferSchema = offerBaseShape.refine(
  (d) => d.end_date > d.start_date,
  {
    message: "offers:errors.end_date_before_start",
    path: ["end_date"],
  },
);

// 3. Build Update Schema using the base shape (so .omit and .partial work)
export const updateOfferSchema = offerBaseShape
  .omit({ supplier_product_id: true }) // Works now because it's calling on the base shape
  .partial()
  .refine(
    (d) => {
      // Logic check: if both dates exist in the update, compare them
      if (d.start_date && d.end_date) return d.end_date > d.start_date;
      return true;
    },
    { message: "offers:errors.end_date_before_start", path: ["end_date"] },
  );

// Rest of your schemas...
export const offerIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const deleteOffersSchema = z.discriminatedUnion("strategy", [
  z.object({ strategy: z.literal("expired") }),
  z.object({ strategy: z.literal("inactive") }),
  z.object({
    strategy: z.literal("ids"),
    ids: z.array(z.number().int().positive()).min(1),
  }),
]);

// Infer types from the FINAL schemas (including refinements)
export type CreateOfferInput = z.infer<typeof createOfferSchema>;
export type UpdateOfferInput = z.infer<typeof updateOfferSchema>;
export type DeleteOffersInput = z.infer<typeof deleteOffersSchema>;
