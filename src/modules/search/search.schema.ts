import { z } from "zod";

export const SearchQuerySchema = z.object({
  q: z.string().min(1, "query_required").trim(),

  // Optional customer location. When provided (or when ApplicationSetting
  // forces same-governorate / cheapest-per-product), supplier products are
  // filtered and sorted by proximity exactly like the /products catalog.
  //
  // Note on case-sensitivity: Prisma's `contains` maps to SQL LIKE.
  // On MySQL with a _ci collation (utf8mb4_unicode_ci is the default) this is
  // already case-insensitive without any extra option.  `mode: "insensitive"`
  // is PostgreSQL-only and would throw an error on MySQL.
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

export type SearchQueryInput = z.infer<typeof SearchQuerySchema>;
