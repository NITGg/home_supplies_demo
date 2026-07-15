import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  createOfferSchema,
  updateOfferSchema,
  offerIdParamSchema,
  deleteOffersSchema,
} from "./offers.schema";
import {
  listOffersService,
  getOfferByIdService,
  createOfferService,
  updateOfferService,
  deleteOfferService,
  deleteOffersService,
} from "./offers.service";

// ─── List ─────────────────────────────────────────────────────────────────────

export async function listOffers(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const api = new FeatureApi(req);
  if (isAdmin) {
    api.filter();
  } else {
    api.filter({ deleted_at: null, is_active: true }, { allowKeys: [] });
  }
  const data = api
    .fields()
    .skip()
    .sort()
    .limit(10)
    .includes()
    .keyword(
      [
        "supplierProduct.product.name",
        "supplierProduct.product.name_ar",
        "supplierProduct.product.sku",
        "supplierProduct.product.barcode",
        "supplierProduct.product.slug",
        "supplierProduct.product.synonyms",
      ],
      "OR",
    ).data;

  const result = await listOffersService(data);

  return res.json(result);
}

// ─── Get one ──────────────────────────────────────────────────────────────────

export async function getOffer(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const { id } = offerIdParamSchema.parse(req.sanitized.params);
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter({ id });
  } else {
    api.filter({ id, deleted_at: null, is_active: true }, { allowKeys: [] });
  }

  const data = api.fields().includes().data;

  const offer = await getOfferByIdService(data);

  return res.json({
    message: req.t("offers:messages.success"),
    offer,
  });
}

// ─── Create ───────────────────────────────────────────────────────────────────

export async function adminCreateOffer(req: AuthedRequest, res: Response) {
  console.log(req.sanitized.body);
  const data = createOfferSchema.parse(req.sanitized.body);
  const offer = await createOfferService(data);

  return res.status(201).json({
    message: req.t("offers:messages.created"),
    offer,
  });
}

// ─── Update ───────────────────────────────────────────────────────────────────

export async function adminUpdateOffer(req: AuthedRequest, res: Response) {
  const { id } = offerIdParamSchema.parse(req.sanitized.params);
  const data = updateOfferSchema.parse(req.sanitized.body);
  const offer = await updateOfferService(id, data);

  return res.json({
    message: req.t("offers:messages.updated"),
    offer,
  });
}

// ─── Soft delete single ───────────────────────────────────────────────────────

export async function adminDeleteOffer(req: AuthedRequest, res: Response) {
  const { id } = offerIdParamSchema.parse(req.sanitized.params);
  await deleteOfferService(id);

  return res.json({ message: req.t("offers:messages.deleted") });
}

// ─── Bulk delete ──────────────────────────────────────────────────────────────

export async function adminBulkDeleteOffers(req: AuthedRequest, res: Response) {
  const data = deleteOffersSchema.parse(req.sanitized.body);
  await deleteOffersService(data);

  return res.json({ message: req.t("offers:messages.deleted") });
}
