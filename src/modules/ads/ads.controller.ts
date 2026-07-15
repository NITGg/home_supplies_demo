import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  adIdParamSchema,
  createAdSchema,
  updateAdSchema,
  reorderAdsSchema,
  deleteAdSchema,
} from "./ads.schema";
import {
  listAdsService,
  getAdByIdService,
  createAdService,
  updateAdService,
  deleteAdService,
  reorderAdsService,
} from "./ads.service";

// ─── Public / shared ──────────────────────────────────────────────────────────

export async function listAds(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const api = new FeatureApi(req);
  const now = new Date();

  if (isAdmin) {
    api.filter();
  } else {
    api.filter(
      {
        status: "ACTIVE",
        deleted_at: null,
        start_date: {
          lte: now,
        },
        end_date: {
          gte: now,
        },
      },
      { allowKeys: ["placement", "ad_type", "sort_id", "adType"] },
    );
  }

  const data = api
    .fields()
    .skip()
    .sort()
    .limit()
    .includes()
    .keyword(["title", "title_ar", "description", "description_ar"], "OR").data;

  const result = await listAdsService(data);
  return res.json(result);
}

export async function getAd(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const { id } = adIdParamSchema.parse(req.sanitized.params);
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter({ id });
  } else {
    api.filter({ id, status: "ACTIVE", deleted_at: null }, { allowKeys: [] });
  }

  const query = api.fields().data;
  const ad = await getAdByIdService(query);
  return res.json({ ad });
}

// ─── Admin ────────────────────────────────────────────────────────────────────

export async function adminCreateAd(req: AuthedRequest, res: Response) {
  console.log(req.sanitized.body);
  console.log(req.body);

  const data = createAdSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const ad = await createAdService(data, query, files);

  return res.status(201).json({
    message: req.t("ads:messages.created"),
    ad,
  });
}

export async function adminUpdateAd(req: AuthedRequest, res: Response) {
  const { id } = adIdParamSchema.parse(req.sanitized.params);
  const data = updateAdSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const ad = await updateAdService({ id, data, query, files });

  return res.json({
    message: req.t("ads:messages.updated"),
    ad,
  });
}

export async function adminReorderAds(req: AuthedRequest, res: Response) {
  const data = reorderAdsSchema.parse(req.sanitized.body);
  await reorderAdsService(data);

  return res.json({ message: req.t("ads:messages.reordered") });
}

export async function adminDeleteAd(req: AuthedRequest, res: Response) {
  const { id } = adIdParamSchema.parse(req.sanitized.params);
  const { permanent } = deleteAdSchema.parse(req.sanitized.body);

  await deleteAdService({ id, permanent });

  return res.json({
    message: req.t("ads:messages.deleted"),
    permanent,
  });
}
