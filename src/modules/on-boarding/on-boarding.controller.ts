import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  onBoardingIdParamSchema,
  createOnBoardingSchema,
  updateOnBoardingSchema,
  deleteOnBoardingSchema,
  deleteManyOnBoardingSchema,
} from "./on-boarding.schema";
import {
  listOnBoardingService,
  getOnBoardingByIdService,
  createOnBoardingService,
  updateOnBoardingService,
  deleteOnBoardingService,
  deleteManyOnBoardingService,
} from "./on-boarding.service";

export async function adminListOnBoarding(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("sort_id")
    .limit(20)
    .skip()
    .includes()
    .keyword(["title", "title_ar", "subtitle", "subtitle_ar"], "OR")
    .fields().data;

  const result = await listOnBoardingService(data);
  return res.json(result);
}

export async function listPublicOnBoarding(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter(
      { deleted_at: null },
      {
        allowKeys: [
          "title",
          "title_ar",
          "subtitle",
          "subtitle_ar",
          "target_user",
        ],
      },
    )
    .sort("sort_id")
    .limit(20)
    .skip()
    .includes()
    .keyword(["title", "title_ar", "subtitle", "subtitle_ar"], "OR")
    .fields().data;

  const result = await listOnBoardingService(data);
  return res.json(result);
}

export async function adminGetOnBoarding(req: AuthedRequest, res: Response) {
  const { id } = onBoardingIdParamSchema.parse(req.sanitized.params);
  const item = await getOnBoardingByIdService({ id });
  return res.json({ item });
}

export async function adminCreateOnBoarding(req: AuthedRequest, res: Response) {
  const data = createOnBoardingSchema.parse(req.sanitized.body);

  const item = await createOnBoardingService({
    data,
    file: req.file,
  });

  return res.status(201).json({
    message: req.t?.("on-boarding:messages.created") ?? "On-boarding created",
    item,
  });
}

export async function adminUpdateOnBoarding(req: AuthedRequest, res: Response) {
  const { id } = onBoardingIdParamSchema.parse(req.sanitized.params);
  const data = updateOnBoardingSchema.parse(req.sanitized.body);

  const item = await updateOnBoardingService({
    id,
    data,
    file: req.file,
  });

  return res.json({
    message: req.t?.("on-boarding:messages.updated") ?? "On-boarding updated",
    item,
  });
}

export async function deleteManyOnBoarding(req: AuthedRequest, res: Response) {
  const data = deleteManyOnBoardingSchema.parse(req.sanitized.body);
  const result = await deleteManyOnBoardingService(data);
  return res.json({
    message: req.t?.("on-boarding:messages.deleted") ?? "On-boarding deleted",
    ...result,
  });
}

export async function adminDeleteOnBoarding(req: AuthedRequest, res: Response) {
  const { id, archived } = deleteOnBoardingSchema.parse({
    ...req.sanitized.body,
    id: req.sanitized.params.id,
  });
  const result = await deleteOnBoardingService({ id, archived });
  return res.json({
    message: req.t?.("on-boarding:messages.deleted") ?? "On-boarding deleted",
    ...result,
  });
}
