import { z } from "zod";

export const articleIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const articleSlugParamSchema = z.object({
  slug: z.string().trim().min(1).max(255),
});

export const createArticleSchema = z.object({
  title: z.string().trim().min(1).max(255),
  slug: z.string().trim().min(1).max(255).optional(),
  summary: z.string().trim().max(500).optional().nullable(),
  content: z.string().trim().min(1),
  cover_image: z.string().optional().nullable(),
  keywords: z.string().trim().max(255).optional().nullable(),
  published_at: z.coerce.date(),
  author: z.string().trim().min(1).max(255),
  is_active: z.boolean().optional(),
  sort_id: z.coerce.number().int().optional(),
});

export const updateArticleSchema = createArticleSchema.partial();

export const deleteArticlesSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
});

export type ArticleIdParamInput = z.infer<typeof articleIdParamSchema>;
export type ArticleSlugParamInput = z.infer<typeof articleSlugParamSchema>;
export type CreateArticleInput = z.infer<typeof createArticleSchema>;
export type UpdateArticleInput = z.infer<typeof updateArticleSchema>;
export type DeleteArticlesInput = z.infer<typeof deleteArticlesSchema>;
