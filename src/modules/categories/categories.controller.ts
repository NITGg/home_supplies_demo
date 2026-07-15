import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  categoryIdParamSchema,
  createCategorySchema,
  updateCategorySchema,
  reorderCategoriesSchema,
  deleteCategorySchema,
} from "./categories.schema";
import {
  createCategoryService,
  listCategoriesService,
  getCategoryByIdService,
  updateCategoryService,
  deleteCategoryService,
  reorderCategoriesService,
} from "./categories.service";

export async function listCategories(req: Request, res: Response) {
  const isAdmin = req.user?.role?.name === "Admin";
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter();
  } else {
    api.filter(
      { is_active: true, deleted_at: null },
      { allowKeys: ["parent_id", "sort_id"] },
    );
  }

  const data = api
    .fields()
    .skip()
    .sort()
    .limit()
    .includes()
    .keyword(
      ["name", "name_ar", "synonyms", "description", "description_ar", "slug"],
      "OR",
    ).data;

  const result = await listCategoriesService(data);
  return res.json(result);
}

export async function getCategory(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const { id } = categoryIdParamSchema.parse(req.sanitized.params);
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter({ id });
  } else {
    api.filter({ id, is_active: true, deleted_at: null }, { allowKeys: [] });
  }

  const query = api.fields().data;
  const category = await getCategoryByIdService(query);
  return res.json({ category });
}

export async function adminCreateCategory(req: AuthedRequest, res: Response) {
  const data = createCategorySchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const category = await createCategoryService(data, query, files);

  return res.status(201).json({
    message: req.t("categories:messages.created"),
    category,
  });
}

export async function adminUpdateCategory(req: AuthedRequest, res: Response) {
  const { id } = categoryIdParamSchema.parse(req.sanitized.params);
  const data = updateCategorySchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const category = await updateCategoryService({ id, data, query, files });

  return res.json({
    message: req.t("categories:messages.updated"),
    category,
  });
}

export async function adminReorderCategories(
  req: AuthedRequest,
  res: Response,
) {
  const data = reorderCategoriesSchema.parse(req.sanitized.body);
  await reorderCategoriesService(data);

  return res.json({ message: req.t("categories:messages.reordered") });
}

export async function adminDeleteCategory(req: AuthedRequest, res: Response) {
  // 1. Validate ID from params
  const { id } = categoryIdParamSchema.parse(req.sanitized.params);

  // 2. Validate permanent flag from query
  const { permanent } = deleteCategorySchema.parse(req.sanitized.body);

  // 3. Execute service
  await deleteCategoryService({ id, permanent });

  return res.json({ message: req.t("categories:messages.deleted"), permanent });
}
