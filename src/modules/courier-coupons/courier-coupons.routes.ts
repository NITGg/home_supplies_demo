import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import {
  adminCreateCourierCoupon,
  adminDeleteCourierCoupon,
  adminDeleteManyCourierCoupons,
  adminGetCourierCoupon,
  adminListCourierCoupons,
  adminUpdateCourierCoupon,
  listPublicCourierCoupons,
  adminUserCourierCouponUsages,
  adminCourierCouponUsages,
} from "./courier-coupons.controller";

export const courierCouponsRouter = Router();
export const adminCourierCouponsRouter = Router();

courierCouponsRouter.get("/", asyncHandler(listPublicCourierCoupons));

adminCourierCouponsRouter.use(requireAuth);
adminCourierCouponsRouter.use(requireRole("Admin"));

adminCourierCouponsRouter.get("/", asyncHandler(adminListCourierCoupons));
adminCourierCouponsRouter.get(
  "/usages",
  asyncHandler(adminCourierCouponUsages),
);
adminCourierCouponsRouter.get("/:id", asyncHandler(adminGetCourierCoupon));
adminCourierCouponsRouter.post("/", asyncHandler(adminCreateCourierCoupon));
adminCourierCouponsRouter.put("/:id", asyncHandler(adminUpdateCourierCoupon));
adminCourierCouponsRouter.delete(
  "/",
  asyncHandler(adminDeleteManyCourierCoupons),
);
adminCourierCouponsRouter.delete(
  "/:id",
  asyncHandler(adminDeleteCourierCoupon),
);
adminCourierCouponsRouter.get(
  "/user/:userId/usages",
  asyncHandler(adminUserCourierCouponUsages),
);
