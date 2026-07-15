import type { Request, Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import FeatureApi from "@/lib/featureApi";

import {
  courierCouponIdParamSchema,
  createCourierCouponSchema,
  updateCourierCouponSchema,
  deleteManyCourierCouponsSchema,
  validateCourierCouponSchema,
  userIdParamSchema,
  deleteCourierCouponsSchema,
} from "./courier-coupons.schema";

import {
  listCourierCouponsService,
  getCourierCouponByIdService,
  createCourierCouponService,
  updateCourierCouponService,
  deleteCourierCouponService,
  deleteManyCourierCouponsService,
  validateCourierCouponService,
  listCourierCouponUsagesService,
} from "./courier-coupons.service";
import { bus } from "@/events/bus";

const keywordFields = ["title", "title_ar", "description", "description_ar"];
const KeywordUsageFields = [
  "user.full_name",
  "coupon.title",
  "coupon.title_ar",
  "coupon.description",
  "coupon.description_ar",
];

export async function adminListCourierCoupons(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(keywordFields, "OR")
    .fields().data;

  const result = await listCourierCouponsService(data);
  return res.json(result);
}

export async function listPublicCourierCoupons(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter({ is_active: true, deleted_at: null }, { allowKeys: [] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(keywordFields, "OR")
    .fields().data;

  const result = await listCourierCouponsService(data);
  return res.json(result);
}

export async function adminGetCourierCoupon(req: AuthedRequest, res: Response) {
  const { id } = courierCouponIdParamSchema.parse(req.sanitized.params);
  const coupon = await getCourierCouponByIdService({ id });
  return res.json({ coupon });
}

export async function adminCreateCourierCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const input = createCourierCouponSchema.parse(req.sanitized.body);
  const coupon = await createCourierCouponService(input);
  bus.emit("courier-coupon.created", {
    couponId: coupon.id,
    title: coupon.title,
    titleAr: coupon.title_ar,
    price: coupon.price,
    bonusCourierFee: coupon.bonus_courier_fee,
    durationDays: coupon.duration_days,
    isActive: coupon.is_active,
    createdByUserId: req.user.id,
    createdAt: new Date(),
  });

  return res.status(201).json({
    message:
      req.t?.("courier-coupons:messages.created") ?? "Courier coupon created",
    coupon,
  });
}

export async function adminUpdateCourierCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = courierCouponIdParamSchema.parse(req.sanitized.params);
  const input = updateCourierCouponSchema.parse(req.sanitized.body);
  const coupon = await updateCourierCouponService({ id, data: input });
  bus.emit("courier-coupon.updated", {
    couponId: coupon.id,
    title: coupon.title,
    titleAr: coupon.title_ar,
    price: coupon.price,
    bonusCourierFee: coupon.bonus_courier_fee,
    durationDays: coupon.duration_days,
    isActive: coupon.is_active,
    updatedByUserId: req.user.id,
    updatedAt: new Date(),
  });
  return res.json({
    message:
      req.t?.("courier-coupons:messages.updated") ?? "Courier coupon updated",
    coupon,
  });
}

export async function adminDeleteManyCourierCoupons(
  req: AuthedRequest,
  res: Response,
) {
  const input = deleteManyCourierCouponsSchema.parse(req.sanitized.body);
  const result = await deleteManyCourierCouponsService(input);

  return res.json({
    message:
      req.t?.("courier-coupons:messages.deleted") ?? "Courier coupons deleted",
    ...result,
  });
}

export async function adminDeleteCourierCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = courierCouponIdParamSchema.parse(req.sanitized.params);
  const data = deleteCourierCouponsSchema.parse({
    id,
    archived: req.sanitized.body.archived,
  });
  await deleteCourierCouponService(data);

  return res.json({
    message:
      req.t?.("courier-coupons:messages.deleted") ?? "Courier coupon deleted",
  });
}

export async function validateCourierCoupon(req: AuthedRequest, res: Response) {
  const { coupon_id } = validateCourierCouponSchema.parse(req.sanitized.body);

  const result = await validateCourierCouponService({
    userId: req.user.id,
    couponId: coupon_id,
  });

  return res.json(result);
}

export async function myCourierCouponUsages(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter({ user_id: req.user.id }, { allowKeys: [] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .fields().data;

  const result = await listCourierCouponUsagesService(data);
  return res.json(result);
}

export async function adminUserCourierCouponUsages(
  req: AuthedRequest,
  res: Response,
) {
  const { userId } = userIdParamSchema.parse(req.sanitized.params);

  const data = new FeatureApi(req)
    .filter({ user_id: userId }, { allowKeys: [] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .fields().data;

  const result = await listCourierCouponUsagesService(data);
  return res.json(result);
}

export async function adminCourierCouponUsages(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(KeywordUsageFields, "OR")
    .fields().data;

  const result = await listCourierCouponUsagesService(data);
  return res.json(result);
}
