import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  brandIdParamSchema,
  createBrandSchema,
  updateBrandSchema,
  reorderBrandsSchema,
  deleteBrandsSchema,
} from "./brands.schema";
import {
  createBrandService,
  listBrandsService,
  getBrandByIdService,
  updateBrandService,
  reorderBrandsService,
  bulkDeleteBrandsService,
} from "./brands.service";

export async function listBrands(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter();
  } else {
    api.filter({ is_active: true, deleted_at: null }, { allowKeys: [] });
  }

  const data = api
    .fields()
    .skip()
    .sort()
    .limit(10)
    .keyword(["name", "name_ar", "slug", "description"], "OR").data;

  const result = await listBrandsService(data);
  return res.json(result);
}

export async function getBrand(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const { id } = brandIdParamSchema.parse(req.sanitized.params);
  const api = new FeatureApi(req);

  isAdmin
    ? api.filter({ id })
    : api.filter({ id, is_active: true, deleted_at: null }, { allowKeys: [] });

  const data = api.fields().data;
  const brand = await getBrandByIdService(data);
  return res.json(brand);
}

export async function adminCreateBrand(req: AuthedRequest, res: Response) {
  const data = createBrandSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };
  const brand = await createBrandService(data, query, files);

  return res.status(201).json({
    message: req.t("brands:messages.created"),
    brand,
    data
  });
}

export async function adminUpdateBrand(req: AuthedRequest, res: Response) {
  const { id } = brandIdParamSchema.parse(req.sanitized.params);
  const data = updateBrandSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const brand = await updateBrandService({ id, data, query, files });

  return res.json({
    message: req.t("brands:messages.updated"),
    brand,
  });
}

export async function adminDeleteBrands(req: AuthedRequest, res: Response) {
  const data = deleteBrandsSchema.parse(req.sanitized.body);
  const result = await bulkDeleteBrandsService(data);
  return res.json({
    message: req.t("brands:messages.deleted"),
    result,
  });
}

export async function adminReorderBrands(req: AuthedRequest, res: Response) {
  const data = reorderBrandsSchema.parse(req.sanitized.body);
  await reorderBrandsService(data);
  return res.json({ message: req.t("brands:messages.reordered") });
}
