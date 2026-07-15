import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import {
  articleIdParamSchema,
  articleSlugParamSchema,
  createArticleSchema,
  updateArticleSchema,
  deleteArticlesSchema,
} from "./articles.schema";
import {
  listArticlesService,
  getArticleByIdService,
  getArticleBySlugService,
  createArticleService,
  updateArticleService,
  deleteArticlesService,
  deleteArticleService,
} from "./articles.service";
import type { AuthedRequest } from "@/types/authedRequest";

const articleKeywordFields = [
  "title",
  "summary",
  "content",
  "keywords",
  "author",
];

export async function adminListArticles(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-published_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(articleKeywordFields, "OR")
    .fields().data;

  const result = await listArticlesService(data);
  return res.json(result);
}

export async function listPublicArticles(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter(
      { is_active: true, published_at: { lte: new Date() } },
      { allowKeys: [] },
    )
    .sort("-published_at")
    .limit(10)
    .skip()
    .includes()
    .keyword(articleKeywordFields, "OR")
    .fields().data;

  const result = await listArticlesService(data);
  return res.json(result);
}

export async function adminGetArticle(req: AuthedRequest, res: Response) {
  const { id } = articleIdParamSchema.parse(req.sanitized.params);
  const article = await getArticleByIdService({ id });
  return res.json({ article });
}

export async function getPublicArticleBySlug(req: Request, res: Response) {
  const { slug } = articleSlugParamSchema.parse(req.sanitized.params);
  const article = await getArticleBySlugService({ slug });
  return res.json({ article });
}

export async function adminCreateArticle(req: AuthedRequest, res: Response) {
  const data = createArticleSchema.parse(req.sanitized.body);

  const article = await createArticleService({
    data,
    file: req.file,
  });

  return res.status(201).json({
    message: req.t?.("articles:messages.created") ?? "Article created",
    article,
  });
}

export async function adminUpdateArticle(req: AuthedRequest, res: Response) {
  const { id } = articleIdParamSchema.parse(req.sanitized.params);
  const data = updateArticleSchema.parse(req.sanitized.body);

  const article = await updateArticleService({
    id,
    data,
    file: req.file,
  });

  return res.json({
    message: req.t?.("articles:messages.updated") ?? "Article updated",
    article,
  });
}

export async function deleteArticles(req: AuthedRequest, res: Response) {
  const data = deleteArticlesSchema.parse(req.sanitized.body);
  const result = await deleteArticlesService(data);

  return res.json({
    message: req.t?.("articles:messages.deleted") ?? "Articles deleted",
    ...result,
  });
}

export async function adminDeleteArticle(req: AuthedRequest, res: Response) {
  const { id } = articleIdParamSchema.parse(req.sanitized.params);
  await deleteArticleService({ id });
  return res.json({
    message: req.t?.("articles:messages.deleted") ?? "Article deleted",
  });
}
