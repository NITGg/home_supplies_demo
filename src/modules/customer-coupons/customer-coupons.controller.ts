import type { Request, Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import FeatureApi from "@/lib/featureApi";

import {
  customerCouponIdParamSchema,
  createCustomerCouponSchema,
  updateCustomerCouponSchema,
  deleteManyCustomerCouponsSchema,
  validateCustomerCouponSchema,
  userIdParamSchema,
  deleteCustomerCouponsSchema,
} from "./customer-coupons.schema";

import {
  listCustomerCouponsService,
  getCustomerCouponByIdService,
  createCustomerCouponService,
  updateCustomerCouponService,
  deleteCustomerCouponService,
  deleteManyCustomerCouponsService,
  validateCustomerCouponService,
  listCustomerCouponUsagesService,
} from "./customer-coupons.service";
import { bus } from "@/events/bus";

const keywordFields = ["code", "title", "title_ar"];
const KeywordUsageFields = ["user.full_name", "coupon.code", "context"];

export async function adminListCustomerCoupons(
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

  const result = await listCustomerCouponsService(data);
  return res.json(result);
}

export async function listPublicCustomerCoupons(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter(
      {
        is_active: true,
        deleted_at: null,
      },
      {
        allowKeys: [
          "is_first",
          "type",
          "scope",
          "code",
          "max_total_uses",
          "max_user_uses",
          "min_orders_count",
          "discount_type",
          "discount_value",
          "max_discount_cents",
          "min_order_total_cents",
          "wallet_amount_cents",
          "wallet_points",
          "is_purchasable",
          "purchase_price_cents",
          "created_at",
          "start_at",
          "end_at",
        ],
      },
    )
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(keywordFields, "OR")
    .fields().data;

  const result = await listCustomerCouponsService(data);
  return res.json(result);
}

export async function adminGetCustomerCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerCouponIdParamSchema.parse(req.sanitized.params);
  const coupon = await getCustomerCouponByIdService({ id });
  return res.json({ coupon });
}

export async function adminCreateCustomerCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const input = createCustomerCouponSchema.parse(req.sanitized.body);
  const file = req.file;
  const coupon = await createCustomerCouponService(input, req.user.id, file);

  return res.status(201).json({
    message:
      req.t?.("customer-coupons:messages.created") ?? "Customer coupon created",
    coupon,
  });
}

export async function adminUpdateCustomerCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerCouponIdParamSchema.parse(req.sanitized.params);
  const input = updateCustomerCouponSchema.parse(req.sanitized.body);
  const file = req.file;
  const coupon = await updateCustomerCouponService({ id, data: input }, file);

  bus.emit("customer-coupon.updated", {
    couponId: coupon.id,
    code: coupon.code,
    title: coupon.title,
    titleAr: coupon.title_ar,
    type: coupon.type,
    isActive: coupon.is_active,
    updatedByUserId: req.user.id,
    updatedAt: new Date(),
  });

  return res.json({
    message:
      req.t?.("customer-coupons:messages.updated") ?? "Customer coupon updated",
    coupon,
  });
}

export async function adminDeleteManyCustomerCoupons(
  req: AuthedRequest,
  res: Response,
) {
  const input = deleteManyCustomerCouponsSchema.parse(req.sanitized.body);
  const result = await deleteManyCustomerCouponsService(input);

  return res.json({
    message:
      req.t?.("customer-coupons:messages.deleted") ??
      "Customer coupons deleted",
    ...result,
  });
}

export async function adminDeleteCustomerCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerCouponIdParamSchema.parse(req.sanitized.params);
  const data = deleteCustomerCouponsSchema.parse({
    id,
    archived: req.sanitized.body.archived,
  });
  await deleteCustomerCouponService(data);

  return res.json({
    message:
      req.t?.("customer-coupons:messages.deleted") ?? "Customer coupon deleted",
  });
}

// Customer (authed) validate by code
export async function validateCustomerCoupon(
  req: AuthedRequest,
  res: Response,
) {
  const { code, orderType } = validateCustomerCouponSchema.parse(req.sanitized.body);
  const result = await validateCustomerCouponService({
    userId: req.user.id,
    code,
    orderType,
  });
  return res.json(result);
}

// Customer (authed) list my usages
export async function myCustomerCouponUsages(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter({ user_id: req.user.id }, { allowKeys: [] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .fields().data;

  const result = await listCustomerCouponUsagesService(data);
  return res.json(result);
}

// Admin: list usages for a given user id
export async function adminUserCustomerCouponUsages(
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
    .keyword(KeywordUsageFields, "OR")
    .fields().data;

  const result = await listCustomerCouponUsagesService(data);
  return res.json(result);
}

// Admin: list usages
export async function adminCustomerCouponUsages(
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

  const result = await listCustomerCouponUsagesService(data);
  return res.json(result);
}
