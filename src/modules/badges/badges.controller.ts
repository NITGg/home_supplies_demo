import type { Request, Response } from "express";
import { HttpError } from "@/lib/httpError";
import FeatureApi from "@/lib/featureApi";
import {
  createBadgeSchema,
  updateBadgeSchema,
  badgeIdParamSchema,
  deleteBadgesSchema,
} from "./badges.schema";
import {
  createBadgeService,
  listBadgesService,
  getBadgeByIdService,
  updateBadgeService,
  deleteBadgesService,
  deleteBadgeService,
} from "./badges.service";

export async function createBadge(req: Request, res: Response) {
  const parsed = createBadgeSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const badge = await createBadgeService(parsed.data, req.file);

  return res.status(201).json({
    message: req.t("badges:messages.badge_created"),
    badge,
  });
}

export async function listBadges(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(50)
    .skip(0)
    .includes()
    .fields().data;

  const result = await listBadgesService(data);
  return res.status(200).json(result);
}

export async function getBadge(req: Request, res: Response) {
  const params = badgeIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "badges:errors.badge_id_invalid");

  const badge = await getBadgeByIdService({ id: params.data.id });
  return res.status(200).json({ badge });
}

export async function updateBadge(req: Request, res: Response) {
  const params = badgeIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "badges:errors.badge_id_invalid");

  const parsed = updateBadgeSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const badge = await updateBadgeService(
    { id: params.data.id, data: parsed.data },
    req.file,
  );

  return res.status(200).json({
    message: req.t("badges:messages.badge_updated"),
    badge,
  });
}

export async function deleteBadges(req: Request, res: Response) {
  const parsed = deleteBadgesSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await deleteBadgesService(parsed.data);

  return res.status(200).json({
    message: req.t("badges:messages.badges_deleted"),
    count: result.count,
  });
}

export async function deleteBadge(req: Request, res: Response) {
  const params = badgeIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "badges:errors.badge_id_invalid");

  await deleteBadgeService({ id: params.data.id });

  return res.status(200).json({
    message: req.t("badges:messages.badge_deleted"),
  });
}
