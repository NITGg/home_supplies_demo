import type { Response } from "express";
import {
  createUnavailableAreaRequestSchema,
  unavailableAreaRequestIdParamSchema,
} from "./unavailable-area-request.schema";
import {
  createUnavailableAreaRequestService,
  listUnavailableAreaRequestsService,
  getUnavailableAreaRequestStatsService,
  deleteUnavailableAreaRequestService,
} from "./unavailable-area-request.service";
import FeatureApi from "@/lib/featureApi";
import { AuthedRequest } from "@/types/authedRequest";

// POST /api/v1/unavailable-area-request
export async function createUnavailableAreaRequest(
  req: AuthedRequest,
  res: Response,
) {
  const data = createUnavailableAreaRequestSchema.parse(req.sanitized.body);

  const customerId = req.user.id ?? null;

  const record = await createUnavailableAreaRequestService(customerId, data);

  return res.status(201).json({
    message: req.t("unavailable-area-request:messages.created"),
    record,
  });
}

// GET /api/v1/admin/unavailable-area-request
export async function listUnavailableAreaRequests(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .sort("-created_at")
    .limit(20)
    .skip(0)
    .fields()
    .filter()
    .keyword()
    .includes().data;

  const result = await listUnavailableAreaRequestsService(data);

  return res.status(200).json(result);
}

// GET /api/v1/admin/unavailable-area-request/stats
export async function getUnavailableAreaRequestStats(
  _req: AuthedRequest,
  res: Response,
) {
  const result = await getUnavailableAreaRequestStatsService();

  return res.status(200).json({ data: result });
}

// DELETE /api/v1/admin/unavailable-area-request/:id
export async function deleteUnavailableAreaRequest(
  req: AuthedRequest,
  res: Response,
) {
  const data = unavailableAreaRequestIdParamSchema.parse(req.sanitized.params);

  await deleteUnavailableAreaRequestService(data.id);

  return res.status(200).json({
    message: req.t("unavailable-area-request:messages.deleted"),
  });
}
