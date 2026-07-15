import { z } from "zod";
import { AppEnvironment } from "@prisma/client";

// ─── Reusable Sub-schemas ─────────────────────────────────────────────────────

const splitSchema = z
  .object({
    badge_id: z.number().int().positive(),
    app_ratio: z.number().nonnegative(),
    courier_ratio: z.number().nonnegative(),
    partner_ratio: z.number().nonnegative(),
  })
  .refine(
    (s) =>
      Math.abs(s.app_ratio + s.courier_ratio + s.partner_ratio - 1) < 0.0001,
    { message: "split ratios must sum to 1.0" },
  );

const vehicleSchema = z.object({
  vehicle_id: z.number().int().positive(),
  min_fee: z.number().nonnegative(),
  m_min: z.number().nonnegative().default(0),
  m_max: z.number().positive(),
  extra_m_price: z.number().nonnegative(),
  fee_per_m: z.number().nonnegative(),
  splits: z
    .array(splitSchema)
    .min(1, "at least one badge split is required per vehicle")
    .refine(
      (splits) => new Set(splits.map((s) => s.badge_id)).size === splits.length,
      { message: "duplicate badge_id within the same vehicle" },
    ),
});

const contractSchema = z
  .object({
    start_date: z.coerce.date(),
    end_date: z.coerce.date(),
    can_receive_courier_offers: z.boolean().default(true),
    vehicles: z
      .array(vehicleSchema)
      .min(1, "at least one vehicle is required")
      .refine(
        (vehicles) =>
          new Set(vehicles.map((v) => v.vehicle_id)).size === vehicles.length,
        { message: "duplicate vehicle_id within the same contract" },
      )
      .optional(),
  })
  .refine((c) => c.end_date > c.start_date, {
    message: "end_date must be after start_date",
    path: ["end_date"],
  });

// ─── Base Shape ───────────────────────────────────────────────────────────────

const externalAppShape = z.object({
  name: z.string().min(3).max(100),
  webhook_url: z.url().max(255).optional().nullable(),
  environment: z.enum(AppEnvironment).default("SANDBOX"),
  is_active: z.boolean().default(true),
  partner_id: z.coerce.number().int().positive().optional().nullable(),
  contract: contractSchema.optional(),
  webhook_version: z.number().int().positive().default(1),
  webhook_retry_count: z.number().int().nonnegative().default(3),
});

// ─── Create ───────────────────────────────────────────────────────────────────

export const createExternalAppSchema = externalAppShape;

export type CreateExternalAppInput = z.output<typeof createExternalAppSchema>;

// ─── Update ───────────────────────────────────────────────────────────────────

export const updateExternalAppSchema = externalAppShape.partial().extend({
  regenerate_client_id: z.boolean().optional(),
  regenerate_client_secret: z.boolean().optional(),
  regenerate_webhook_secret: z.boolean().optional(),
});

export type UpdateExternalAppInput = z.output<typeof updateExternalAppSchema>;

// ─── Params ───────────────────────────────────────────────────────────────────

export const externalAppIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});
