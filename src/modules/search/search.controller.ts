import type { Request, Response } from "express";
import { searchGlobalService } from "./search.service";
import { SearchQuerySchema } from "./search.schema";

export async function globalSearch(req: Request, res: Response) {
  const input = {
    ...(req.sanitized?.query ?? {}),
    ...(req.sanitized?.body ?? {}),
  };

  const { q, lat, lng } = SearchQuerySchema.parse(input);

  const result = await searchGlobalService(q, {
    lat,
    lng,
  });

  return res.status(200).json({
    message: req.t("search.messages.success"),
    ...result,
  });
}
