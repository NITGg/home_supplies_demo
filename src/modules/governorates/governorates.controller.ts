import type { Response } from "express";
import {
  createGovtSchema,
  deleteGovtSchema,
  deleteManyGovtSchema,
  govtIdParamSchema,
  updateGovtSchema,
} from "./governorates.schema.js";
import {
  createGovernorate,
  getGovernorateById,
  listGovernorates,
  deleteGovernorate,
  deleteGovernorates,
  updateGovernorate,
} from "./governorates.service.js";
import FeatureApi from "@/lib/featureApi.js";
import { AuthedRequest } from "@/types/authedRequest.js";

export async function adminListGovernorates(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort()
    .limit(10)
    .skip()
    .includes()
    .keyword(["name", "name_ar"], "OR")
    .fields().data;

  const result = await listGovernorates(data);

  res.json(result);
}

export async function listPublicGovernorates(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter()
    .sort()
    .limit(10)
    .skip()
    .includes()
    .keyword(["name", "name_ar"], "OR")
    .fields().data;

  // Move areas filter from where into include.areas.where
  if (data.where?.areas && data.include?.areas) {
    const areasFilter = data.where.areas as Record<string, unknown>;
    delete data.where.areas;
    data.include.areas = { where: areasFilter } as any;
  }

  const result = await listGovernorates(data);

  res.json(result);
}

export async function adminGetGovernorate(req: AuthedRequest, res: Response) {
  const { id } = govtIdParamSchema.parse(req.sanitized.params);
  const data = new FeatureApi(req).filter({ id }).includes().fields().data;
  const governorate = await getGovernorateById(data);
  res.json(governorate);
}

export async function getPublicGovernorate(req: AuthedRequest, res: Response) {
  const { id } = govtIdParamSchema.parse(req.sanitized.params);
  const data = new FeatureApi(req)
    .filter({ id, deleted_at: null }, { allowKeys: [] })
    .includes()
    .fields().data;
  const governorate = await getGovernorateById(data);
  res.json(governorate);
}

export async function adminCreateGovernorate(
  req: AuthedRequest,
  res: Response,
) {
  const body = createGovtSchema.parse(req.sanitized.body);
  const governorate = await createGovernorate(body);

  res
    .status(201)
    .json({ message: req.t("governorates:messages.created"), governorate });
}

export async function adminUpdateGovernorate(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = govtIdParamSchema.parse(req.sanitized.params);
  const body = updateGovtSchema.parse(req.sanitized.body);

  const governorate = await updateGovernorate(id, body);
  res.json({ message: req.t("governorates:messages.updated"), governorate });
}

export async function adminDeleteGovernorate(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = govtIdParamSchema.parse(req.sanitized.params);
  const { archived } = deleteGovtSchema.parse({ ...req.sanitized.body, id });

  const result = await deleteGovernorate({ id, archived });
  res.json({ message: req.t("governorates:messages.deleted"), ...result });
}

export async function deleteManyGovernorates(
  req: AuthedRequest,
  res: Response,
) {
  const body = deleteManyGovtSchema.parse(req.sanitized.body);
  const result = await deleteGovernorates(body);

  return res.json({
    message: req.t("governorates:messages.deleted"),
    ...result,
  });
}
