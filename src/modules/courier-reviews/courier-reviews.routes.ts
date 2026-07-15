import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import {
  adminCreateCourierReview,
  adminDeleteCourierReview,
  adminDeleteManyCourierReviews,
  adminGetCourierReview,
  adminListCourierReviews,
  adminUpdateCourierReview,
  customerGetReceivedCourierReviewById,
  customerListReceivedCourierReviews,
} from "./courier-reviews.controller";

export const courierReviewsRouter = Router();
export const adminCourierReviewsRouter = Router();

courierReviewsRouter.use(requireAuth);

// Customer reads reviews received about him
courierReviewsRouter.get(
  "/",
  requireRole("Customer", "Admin", "Seller", "Supplier"),
  asyncHandler(customerListReceivedCourierReviews),
);
courierReviewsRouter.get(
  "/:id",
  requireRole("Customer", "Admin", "Seller"),
  asyncHandler(customerGetReceivedCourierReviewById),
);

// Admin
adminCourierReviewsRouter.use(requireAuth);
adminCourierReviewsRouter.use(requireRole("Admin"));

adminCourierReviewsRouter.get("/", asyncHandler(adminListCourierReviews));
adminCourierReviewsRouter.get("/:id", asyncHandler(adminGetCourierReview));
adminCourierReviewsRouter.post("/", asyncHandler(adminCreateCourierReview));
adminCourierReviewsRouter.put("/:id", asyncHandler(adminUpdateCourierReview));
adminCourierReviewsRouter.delete(
  "/",
  asyncHandler(adminDeleteManyCourierReviews),
);
adminCourierReviewsRouter.delete(
  "/:id",
  asyncHandler(adminDeleteCourierReview),
);
