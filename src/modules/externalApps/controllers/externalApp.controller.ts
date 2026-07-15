import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  createExternalAppSchema,
  updateExternalAppSchema,
  externalAppIdParamSchema,
} from "../schemas/externalApp.schema";
import {
  listExternalAppsService,
  getExternalAppByIdService,
  createExternalAppService,
  updateExternalAppService,
  deleteExternalAppService,
} from "../services/externalApp.service";

export async function listExternalApps(req: Request, res: Response) {
  const api = new FeatureApi(req);
  const data = api
    .fields()
    .skip()
    .sort()
    .limit()
    .includes()
    .keyword(["name", "client_id"]).data;

  const result = await listExternalAppsService(data);
  return res.json(result);
}

export async function getExternalApp(req: Request, res: Response) {
  const { id } = externalAppIdParamSchema.parse(req.sanitized.params);
  const query = new FeatureApi(req).fields().includes().data;
  query.where = { id };

  const app = await getExternalAppByIdService(query);
  return res.json({ app });
}

export async function adminCreateExternalApp(
  req: AuthedRequest,
  res: Response,
) {
  const data = createExternalAppSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;

  const { app, rawSecret } = await createExternalAppService(data, query);

  return res.status(201).json({
    message: req.t("external_apps:messages.created"),
    app,
    client_secret_raw: rawSecret, // Important: Partner needs to copy this now
  });
}

export async function adminUpdateExternalApp(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = externalAppIdParamSchema.parse(req.sanitized.params);
  const data = updateExternalAppSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;

  const app = await updateExternalAppService(id, data, query);
  return res.json({ message: req.t("external_apps:messages.updated"), ...app });
}

export async function adminDeleteExternalApp(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = externalAppIdParamSchema.parse(req.sanitized.params);
  await deleteExternalAppService(id);
  return res.json({ message: req.t("external_apps:messages.deleted") });
}
