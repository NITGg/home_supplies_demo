import z from "zod";
import { Language, TargetUser } from "@prisma/client";

export const faqsQuerySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),

  question: z.string().optional(),
  language: z.nativeEnum(Language).optional(),
  is_active: z
    .string()
    .transform((val) => val === "true")
    .optional(),
  sort_id: z.string().regex(/^\d+$/).transform(Number).optional(),
  target_user: z.nativeEnum(TargetUser).optional(),
  sort_id_sorting: z.enum(["ASC", "DESC"]).optional().default("ASC"),
});

export const onBoardingQuerySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),

  title: z.string().optional(),
  title_ar: z.string().optional(),
  subtitle: z.string().optional(),
  subtitle_ar: z.string().optional(),
  sort_id: z.string().regex(/^\d+$/).transform(Number).optional(),
  target_user: z.nativeEnum(TargetUser).optional(),
  sort_id_sorting: z.enum(["ASC", "DESC"]).optional().default("ASC"),
});
