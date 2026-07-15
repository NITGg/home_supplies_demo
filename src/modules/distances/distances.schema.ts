import { z } from "zod";

// Helper for coordinate validation
const coordSchema = z.object({
  lat: z.number().min(-90).max(90, "Invalid latitude"),
  lng: z.number().min(-180).max(180, "Invalid longitude"),
});

export const DistanceRequestSchema = z.object({
  pickup: coordSchema,
  delivery: coordSchema,
});
