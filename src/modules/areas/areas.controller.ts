import type { Response } from "express";
import FeatureApi from "@/lib/featureApi.js";
import { AuthedRequest } from "@/types/authedRequest.js";
import {
  areaIdParamSchema,
  createAreaSchema,
  deleteManyAreasSchema,
  updateAreaSchema,
} from "./areas.schema.js";
import {
  createArea,
  deleteArea,
  deleteAreas,
  getAreaById,
  listAreas,
  updateArea,
} from "./areas.service.js";

export async function adminListAreas(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort()
    .limit(10)
    .skip()
    .includes()
    .keyword(["name", "name_ar"], "OR")
    .fields().data;

  const result = await listAreas(data);
  res.json(result);
}

export async function listPublicAreas(req: AuthedRequest, res: Response) {
  // Public should NOT show areas that belong to archived(deleted_at) governorates
  const data = new FeatureApi(req)
    .filter({ governorate: { deleted_at: null } })
    .sort()
    .limit(10)
    .skip()
    .includes()
    .keyword(["name", "name_ar"], "OR")
    .fields().data;

  const result = await listAreas(data);
  res.json(result);
}

export async function adminGetArea(req: AuthedRequest, res: Response) {
  const { id } = areaIdParamSchema.parse(req.sanitized.params);
  const data = new FeatureApi(req).filter({ id }).includes().fields().data;

  const area = await getAreaById(data);
  res.json(area);
}

export async function getPublicArea(req: AuthedRequest, res: Response) {
  const { id } = areaIdParamSchema.parse(req.sanitized.params);

  // block query filters; also make sure its governorate not archived
  const data = new FeatureApi(req)
    .filter(
      { id, governorate: { deleted_at: null } },
      { allowKeys: ["governorate_id"] },
    )
    .includes()
    .fields().data;

  const area = await getAreaById(data);
  res.json(area);
}

export async function adminCreateArea(req: AuthedRequest, res: Response) {
  const body = createAreaSchema.parse(req.sanitized.body);
  const area = await createArea(body);

  res.status(201).json({
    message: req.t("areas:messages.created"),
    area,
  });
}

export async function adminUpdateArea(req: AuthedRequest, res: Response) {
  const { id } = areaIdParamSchema.parse(req.sanitized.params);
  const body = updateAreaSchema.parse(req.sanitized.body);

  const area = await updateArea(id, body);

  res.json({
    message: req.t("areas:messages.updated"),
    area,
  });
}

export async function adminDeleteArea(req: AuthedRequest, res: Response) {
  const { id } = areaIdParamSchema.parse(req.sanitized.params);

  const result = await deleteArea({ id });

  res.json({
    message: req.t("areas:messages.deleted"),
    ...result,
  });
}

export async function deleteManyAreas(req: AuthedRequest, res: Response) {
  const body = deleteManyAreasSchema.parse(req.sanitized.body);
  const result = await deleteAreas(body);

  return res.json({
    message: req.t("areas:messages.deleted"),
    ...result,
  });
}
