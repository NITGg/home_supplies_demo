import { z } from "zod";
import { AdType, AdStatus, AdPlacement, PopupSize } from "@prisma/client";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const booleanFromString = z.union([
  z.string().transform((val) => val === "true" || val === "1"),
  z.boolean(),
]);

const coerceOptionalInt = z.coerce.number().int().optional();

// Helper
const getEnumValues = <T extends Record<string, any>>(enumObj: T) =>
  Object.values(enumObj) as [string, ...string[]];

// ─── Base Shape ───────────────────────────────────────────────────────────────

const adShape = z.object({
  ad_type: z.enum(AdType).optional(),
  source: z.string().max(255).optional(),
  budget: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, "budget must be a valid decimal (e.g. 10.00)")
    .optional(),

  title: z.string().optional(),
  title_ar: z.string().optional(),
  description: z.string().optional(),
  description_ar: z.string().optional(),

  priority: coerceOptionalInt,
  status: z.enum(AdStatus).optional(),

  target_url: z.url("target_url must be a valid URL").max(255).optional(),

  placement: z.enum(AdPlacement).optional(),
  popup_size: z.enum(PopupSize).optional(),
  closable: booleanFromString.optional(),

  mobile_screen: z.string().optional(),
  image_url: z.string().optional().nullable(),

  start_date: z.coerce.date().optional(),
  end_date: z.coerce.date().optional(),

  /**
   * Accepts a JSON string or object/array — always stored as a raw JSON string
   * matching the @db.LongText column.
   */
  // Replace your existing time_slots definition with this:
  time_slots: z
    .union([
      z.string(),
      z.array(z.unknown()),
      z.record(z.string(), z.unknown()),
    ])
    .transform((v) => (typeof v === "string" ? v : JSON.stringify(v)))
    .optional(),

  duration_seconds: coerceOptionalInt,
  shown_seconds: coerceOptionalInt,
  first_shown_at: z.coerce.date().optional(),
  last_shown_at: z.coerce.date().optional(),

  target_customer_badge_id: z.coerce.number().int().positive().optional(),
  sort_id: z.coerce.number().int().default(0),
  user_badge_id: z.coerce.number().int().positive().optional(),
});

// ─── Create Schema ────────────────────────────────────────────────────────────

export const createAdSchema = adShape;
export type CreateAdInput = z.output<typeof createAdSchema>;

// ─── Update Schema ────────────────────────────────────────────────────────────

export const updateAdSchema = adShape.partial().extend({
  /** Pass "true" or true to remove the existing image without uploading a new one */
  delete_image: booleanFromString.optional(),
});
export type UpdateAdInput = z.output<typeof updateAdSchema>;

// ─── Param / misc schemas ─────────────────────────────────────────────────────

export const adIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const deleteAdSchema = z.object({
  permanent: booleanFromString.default(false),
});

export const reorderAdsSchema = z.object({
  ads: z
    .array(
      z.object({
        id: z.number().int().positive(),
        sort_id: z.number().int().nonnegative(),
      }),
    )
    .min(1),
});

export type ReorderAdsInput = z.infer<typeof reorderAdsSchema>;
