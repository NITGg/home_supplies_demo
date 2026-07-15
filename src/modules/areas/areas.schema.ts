import { z } from "zod";

export const areaIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export type AreaIdParam = z.infer<typeof areaIdParamSchema>;

// --- boundaries validation ---
// each point must have lat/lng numbers
export const boundaryPointSchema = z.object({
  lat: z.number(),
  lng: z.number(), // (you wrote "lont" but conventionally it's lng)
});

export type BoundaryPoint = z.infer<typeof boundaryPointSchema>;

/**
 * boundaries shape:
 * {
 *   point1: { lat: 30.0, lng: 31.0 },
 *   point2: { lat: 30.1, lng: 31.2 },
 *   point3: { lat: 30.2, lng: 31.3 }
 * }
 */
export const boundariesSchema = z
  .record(z.string(), boundaryPointSchema)
  .superRefine((obj, ctx) => {
    // must have at least 2 points
    if (Object.keys(obj).length < 2) {
      ctx.addIssue({
        code: "custom",
        message: "areas:errors.boundaries_min_points",
      });
    }

    // enforce key format: point1, point2, point3...
    for (const k of Object.keys(obj)) {
      if (!/^point\d+$/.test(k)) {
        ctx.addIssue({
          code: "custom",
          path: [k],
          message: "areas:errors.boundaries_invalid_key",
        });
      }
    }
  });

export type Boundaries = z.infer<typeof boundariesSchema>;

// --- create/update schemas ---
export const createAreaSchema = z.object({
  governorate_id: z.coerce.number().int().positive(),
  name: z.string().trim().min(1).max(100),
  name_ar: z.string().trim().min(1).max(100),
  is_active: z.boolean().optional(),
  boundaries: boundariesSchema, // ✅ validated JSON
});

export type CreateAreaInput = z.infer<typeof createAreaSchema>;

// update = partial(create) (everything optional)
export const updateAreaSchema = createAreaSchema.partial();

export type UpdateAreaInput = z.infer<typeof updateAreaSchema>;
export const deleteManyAreasSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type DeleteManyAreasInput = z.infer<typeof deleteManyAreasSchema>;
