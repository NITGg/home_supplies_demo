import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole } from "@/middlewares/auth";
import upload from "@/middlewares/upload";
import { Router } from "express";
import {
  adminCreateCustomerCoupon,
  adminCustomerCouponUsages,
  adminDeleteCustomerCoupon,
  adminDeleteManyCustomerCoupons,
  adminGetCustomerCoupon,
  adminListCustomerCoupons,
  adminUpdateCustomerCoupon,
  adminUserCustomerCouponUsages,
  listPublicCustomerCoupons,
  myCustomerCouponUsages,
  validateCustomerCoupon,
} from "./customer-coupons.controller";

export const customerCouponsRouter = Router();
export const adminCustomerCouponsRouter = Router();

// Public (no auth)
customerCouponsRouter.get("/", asyncHandler(listPublicCustomerCoupons));

// Customer (auth)
customerCouponsRouter.use(requireAuth);
customerCouponsRouter.post("/validate", asyncHandler(validateCustomerCoupon));
customerCouponsRouter.get("/me/usages", asyncHandler(myCustomerCouponUsages));

// Admin
adminCustomerCouponsRouter.use(requireAuth);
adminCustomerCouponsRouter.use(requireRole("Admin"));

adminCustomerCouponsRouter.get("/", asyncHandler(adminListCustomerCoupons));
adminCustomerCouponsRouter.get(
  "/usages",
  asyncHandler(adminCustomerCouponUsages),
);
adminCustomerCouponsRouter.get("/:id", asyncHandler(adminGetCustomerCoupon));
adminCustomerCouponsRouter.post(
  "/",
  upload.single("image"),
  asyncHandler(adminCreateCustomerCoupon),
);
adminCustomerCouponsRouter.put(
  "/:id",
  upload.single("image"),
  asyncHandler(adminUpdateCustomerCoupon),
);
adminCustomerCouponsRouter.delete(
  "/",
  asyncHandler(adminDeleteManyCustomerCoupons),
);
adminCustomerCouponsRouter.delete(
  "/:id",
  asyncHandler(adminDeleteCustomerCoupon),
);

// Extra admin route: usages for a specific user
adminCustomerCouponsRouter.get(
  "/user/:userId/usages",
  asyncHandler(adminUserCustomerCouponUsages),
);
