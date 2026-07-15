import z from "zod";

export const i18nAppParamSchema = z.object({
  app: z.string().min(1),
});

export const i18nNamespaceParamSchema = z.object({
  app: z.string().min(1),
  namespace: z.string().min(1),
});

export const updateI18nNamespaceSchema = z.object({
  app: z.string().min(1),
  namespace: z.string().min(1),
  updates: z
    .array(
      z.object({
        key: z.string().min(1),
        en: z.string().max(2000).optional(),
        ar: z.string().max(2000).optional(),
      }),
    )
    .min(1),
});

export type UpdateI18nNamespaceDTO = z.infer<typeof updateI18nNamespaceSchema>;
