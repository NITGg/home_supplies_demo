import type { Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  peakTimeIdParamSchema,
  createPeakTimeSchema,
  updatePeakTimeSchema,
} from "./peak-time.schema";
import {
  listPeakTimesService,
  getPeakTimeByIdService,
  createPeakTimeService,
  updatePeakTimeService,
  deletePeakTimeService,
} from "./peak-time.service";

export async function adminListPeakTimes(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .fields().data;

  const result = await listPeakTimesService(data);
  return res.json(result);
}

export async function adminGetPeakTime(req: AuthedRequest, res: Response) {
  const { id } = peakTimeIdParamSchema.parse(req.sanitized.params);
  const peakTime = await getPeakTimeByIdService({ id });
  return res.json({ peakTime });
}

export async function adminCreatePeakTime(req: AuthedRequest, res: Response) {
  const data = createPeakTimeSchema.parse(req.sanitized.body);
  const peakTime = await createPeakTimeService(data);
  return res.status(201).json({
    message: req.t?.("peak-time:messages.created") ?? "Peak time created",
    peakTime,
  });
}

export async function adminUpdatePeakTime(req: AuthedRequest, res: Response) {
  const { id } = peakTimeIdParamSchema.parse(req.sanitized.params);
  const data = updatePeakTimeSchema.parse(req.sanitized.body);
  const peakTime = await updatePeakTimeService({ id, data });
  return res.json({
    message: req.t?.("peak-time:messages.updated") ?? "Peak time updated",
    peakTime,
  });
}

export async function adminDeletePeakTime(req: AuthedRequest, res: Response) {
  const { id } = peakTimeIdParamSchema.parse(req.sanitized.params);
  await deletePeakTimeService({ id });
  return res.json({
    message: req.t?.("peak-time:messages.deleted") ?? "Peak time deleted",
  });
}
