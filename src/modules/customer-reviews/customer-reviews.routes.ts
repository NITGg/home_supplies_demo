import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import {
  adminDeleteCustomerReview,
  adminDeleteManyCustomerReviews,
  adminDeleteSupplierReview,
  adminGetCustomerReview,
  adminGetSupplierReview,
  adminListCourierReviews,
  adminListCustomerReviews,
  adminListCustomerReviewsFromCourier,
  adminListSupplierReviews,
  courierGetReceivedReviewById,
  courierListReceivedReviews,
  customerCreateCourierReview,
  customerCreateSupplierReview,
  customerGetMyGivenReviewById,
  customerListMyGivenReviews,
} from "./customer-reviews.controller";

export const customerReviewsRouter = Router();
export const adminCustomerReviewsRouter = Router();
export const adminSupplierReviewsRouter = Router();

customerReviewsRouter.use(requireAuth);

// Customer creates/list own given reviews
customerReviewsRouter.post(
  "/",
  requireRole("Customer", "Admin", "Seller", "CustomerSupport", "Supplier"),
  asyncHandler(customerCreateCourierReview),
);
customerReviewsRouter.post(
  "/supplier",
  requireRole("Customer", "Admin", "Seller", "CustomerSupport", "Supplier"),
  asyncHandler(customerCreateSupplierReview),
);
customerReviewsRouter.get(
  "/customer/me",
  requireRole("Customer", "Admin", "Seller", "CustomerSupport", "Supplier"),
  asyncHandler(customerListMyGivenReviews),
);
customerReviewsRouter.get(
  "/customer/:id",
  requireRole("Customer", "Admin", "Seller", "CustomerSupport", "Supplier"),
  asyncHandler(customerGetMyGivenReviewById),
);

// Courier reads reviews received about him
customerReviewsRouter.get(
  "/courier/me",
  requireRole("Courier", "Admin", "Seller", "CustomerSupport"),
  asyncHandler(courierListReceivedReviews),
);
customerReviewsRouter.get(
  "/courier/:id",
  requireRole("Courier", "Admin", "Seller", "CustomerSupport"),
  asyncHandler(courierGetReceivedReviewById),
);

// Admin
adminCustomerReviewsRouter.use(requireAuth);
// adminCustomerReviewsRouter.use(requireRole("Admin"));

adminCustomerReviewsRouter.get(
  "/",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminListCustomerReviews),
);
adminCustomerReviewsRouter.get(
  "/:id",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminGetCustomerReview),
);
adminCustomerReviewsRouter.delete(
  "/",
  requireRole("Admin"),
  asyncHandler(adminDeleteManyCustomerReviews),
);
adminCustomerReviewsRouter.delete(
  "/:id",
  requireRole("Admin"),
  asyncHandler(adminDeleteCustomerReview),
);

// Admin – Supplier reviews from customers
adminSupplierReviewsRouter.use(requireAuth);

adminSupplierReviewsRouter.get(
  "/list-supplier-reviews",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminListSupplierReviews),
);
adminSupplierReviewsRouter.get(
  "/get-supplier-review/:id",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminGetSupplierReview),
);
adminSupplierReviewsRouter.delete(
  "/delete-supplier-review/:id",
  requireRole("Admin"),
  asyncHandler(adminDeleteSupplierReview),
);

adminSupplierReviewsRouter.get(
  "/list-courier-reviews",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminListCourierReviews),
);

adminSupplierReviewsRouter.get(
  "/list-customer-reviews",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminListCustomerReviewsFromCourier),
);
