import z from "zod";
import { GenderEnum } from "../../core/types/global.types";
import { Language } from "@prisma/client";

export const updateProfileSchema = z.object({
  full_name: z.string().min(3).max(50).optional(),
  gender: z.enum(["MALE", "FEMALE"]).optional(),
  language: z.enum(["AR", "EN"]).optional(),
  vehicle_id: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  vehicle_plate: z.string().optional(),
  badge_id: z.coerce.number().int().positive().optional().nullable(),
  courier_office_id: z.coerce.number().int().positive().optional().nullable(),
  min_order_price: z.number().optional(),
  max_order_price: z.number().optional(),
});

export const updateDocumentsSchema = z.object({});

export const updateSelectedAreasSchema = z.object({
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
export const softDeleteSchema = z.object({});
export const hardDeleteSchema = z.object({});
export const cancelSoftDeleteSchema = z.object({});
