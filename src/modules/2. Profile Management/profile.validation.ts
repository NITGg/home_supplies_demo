import z from "zod";
import { GenderEnum } from "../../types/global.types";

const positiveIntIdSchema = z.coerce
  .number()
  .int("Invalid ID")
  .min(1, "Invalid ID");

// Route params schemas (each route has its own schema)
export const getProfileSchema = z.object({
  userId: positiveIntIdSchema,
});

export const badgeProgressSchema = z.object({
  userId: positiveIntIdSchema,
});

export const updateProfileSchema = z.object({
  userId: positiveIntIdSchema,
  // user fields
  full_name: z.string().min(3).max(50).optional(),
  phone: z.string().optional(),
  gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
  language: z.enum(["AR", "EN"]).optional(),
  badge_id: z.string().optional(),
  // supplier fields
  type_id: z.string().optional(),
  synonyms: z.string().optional(),
  tax_card: z.string().optional(),
  commercial_register: z.string().optional(),
  min_price_for_one_order: z.number().optional(),
  max_price_for_one_order: z.number().optional(),
  shopping_min_price_for_one_order: z.number().optional(),
  shopping_max_price_for_one_order: z.number().optional(),
  shopping_budget_fee: z.number().optional(),
  // SupplierStoreAddress fields
  area_id: z.number().optional(),
  address_line_1: z.string().optional(),
  address_line_2: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  country: z.string().optional(),
  google_map_link: z.string().optional(),
  latitude: z.string().optional(),
  longitude: z.string().optional(),
  contact_name: z.string().optional(),
  contact_phone: z.string().optional(),
  working_hours: z
    .object({
      timezone: z.string().min(1, "Timezone is required"),
      days: z.record(
        z.string().regex(/^[0-6]$/),
        z.object({
          is_closed: z.boolean(),
          slots: z.array(
            z.object({
              open: z
                .string()
                .regex(
                  /^([01]\d|2[0-3]):([0-5]\d)$/,
                  "Time must be in HH:MM format",
                ),
              close: z
                .string()
                .regex(
                  /^([01]\d|2[0-3]):([0-5]\d)$/,
                  "Time must be in HH:MM format",
                ),
            }),
          ),
        }),
      ),
    })
    .optional(),
});

export const updateDocumentsSchema = z.object({
  userId: positiveIntIdSchema,
  national_id_number: z
    .string()
    .regex(/^\d{14}$/, "National ID must be exactly 14 digits")
    .optional(),
});

export const updateSelectedAreasSchema = z.object({
  userId: positiveIntIdSchema,
  areas: z.array(
    z.object({
      area_id: z.number(),
    }),
  ),
});

export const locationGovernoratesSchema = z.object({
  is_active: z.boolean().optional(),
});

export const locationGovernoratesAreasSchema = z.object({
  is_active: z.boolean().optional(),
});

export const softDeleteSchema = z.object({
  userId: positiveIntIdSchema,
});

export const hardDeleteSchema = z.object({
  userId: positiveIntIdSchema,
});

export const cancelSoftDeleteSchema = z.object({
  userId: positiveIntIdSchema,
});

export const createSupplierSlotMaxOrderSchema = z.object({
  store_address_id: z.coerce.number().int("Invalid ID").min(1, "Invalid ID"),
  day_of_week: z.coerce
    .number()
    .int("Invalid Day")
    .min(0, "Invalid Day")
    .max(6, "Invalid Day"),
  time_from: z.coerce
    .string()
    .regex(/^([01]\d|2[0-3]):([0-5]\d)$/, "Invalid Time"),
  time_to: z.coerce
    .string()
    .regex(/^([01]\d|2[0-3]):([0-5]\d)$/, "Invalid Time"),
  max_orders: z.coerce
    .number()
    .int("Invalid Max Orders")
    .min(1, "Invalid Max Orders")
    .optional(),
});

export const updateSupplierSlotMaxOrderSchema = z.object({
  supplierSlotMaxOrderId: z.coerce
    .number()
    .int("Invalid ID")
    .min(1, "Invalid ID"),
  time_from: z.coerce
    .string()
    .regex(/^([01]\d|2[0-3]):([0-5]\d)$/, "Invalid Time")
    .optional(),
  time_to: z.coerce
    .string()
    .regex(/^([01]\d|2[0-3]):([0-5]\d)$/, "Invalid Time")
    .optional(),
  max_orders: z.coerce
    .number()
    .int("Invalid Max Orders")
    .min(1, "Invalid Max Orders")
    .optional(),
});

export const listSupplierSlotMaxOrderSchema = z.object({
  supplierStoreAddressId: z.coerce
    .number()
    .int("Invalid ID")
    .min(1, "Invalid ID"),
});

export const deleteSupplierSlotMaxOrderSchema = z.object({
  supplierSlotMaxOrderId: z.coerce
    .number()
    .int("Invalid ID")
    .min(1, "Invalid ID"),
});

export const supplierSlotMaxOrderStatusSchema = z.object({
  supplierStoreAddressId: z.coerce
    .number()
    .int("Invalid ID")
    .min(1, "Invalid ID"),
});
