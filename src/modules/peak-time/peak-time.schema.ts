import { z } from "zod";

export const peakTimeIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createPeakTimeSchema = z.object({
  day: z.coerce.number().int().min(0).max(6), // 0=Sunday … 6=Saturday
  start_time: z
    .string()
    .trim()
    .regex(/^\d{2}:\d{2}$/, "Must be HH:mm format"),
  end_time: z
    .string()
    .trim()
    .regex(/^\d{2}:\d{2}$/, "Must be HH:mm format"),
  is_active: z.boolean().optional(),
});

export const updatePeakTimeSchema = createPeakTimeSchema.partial();

export type CreatePeakTimeInput = z.infer<typeof createPeakTimeSchema>;
export type UpdatePeakTimeInput = z.infer<typeof updatePeakTimeSchema>;
