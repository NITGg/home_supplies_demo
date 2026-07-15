import { Router } from "express";
import { requireAuth, requireRole, optionalAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import upload from "@/middlewares/upload";
import {
  listProducts,
  getProduct,
  adminCreateProduct,
  adminUpdateProduct,
  adminDeleteSingleProduct,
  adminBulkDeleteProducts,
  adminReorderProducts,
  adminCreateSupplierProduct,
  adminUpdateSupplierProduct,
  adminDeleteSupplierProduct,
  adminGetProductSuppliers,
  adminResetSupplierProductPrice,
  getProductReviews,
  listBaseProducts,
} from "./products.controller";

const productRouter = Router();
const adminOnly = [requireAuth, requireRole("Admin")];

// ─── Collection routes ────────────────────────────────────────────────────────

productRouter.get("/list-products", optionalAuth, asyncHandler(listBaseProducts));

productRouter
  .route("/")
  .get(optionalAuth, asyncHandler(listProducts))
  .post(
    ...adminOnly,
    upload.array("images", 5),
    asyncHandler(adminCreateProduct),
  )
  .delete(...adminOnly, asyncHandler(adminBulkDeleteProducts));

productRouter.post(
  "/reorder",
  ...adminOnly,
  asyncHandler(adminReorderProducts),
);

// ─── Single product routes ────────────────────────────────────────────────────

productRouter
  .route("/:id")
  .get(optionalAuth, asyncHandler(getProduct))
  .put(
    ...adminOnly,
    upload.array("images", 5),
    asyncHandler(adminUpdateProduct),
  )
  .delete(...adminOnly, asyncHandler(adminDeleteSingleProduct));

// ─── SupplierProduct routes ───────────────────────────────────────────────────

productRouter
  .route("/:id/suppliers")
  .get(...adminOnly, asyncHandler(adminGetProductSuppliers))
  .post(...adminOnly, asyncHandler(adminCreateSupplierProduct));

productRouter
  .route("/:id/suppliers/:spId")
  .put(...adminOnly, asyncHandler(adminUpdateSupplierProduct))
  .delete(...adminOnly, asyncHandler(adminDeleteSupplierProduct));

productRouter.patch(
  "/:id/suppliers/:spId/reset-price",
  ...adminOnly,
  asyncHandler(adminResetSupplierProductPrice),
);

// ─── Reviews ──────────────────────────────────────────────────────────────────

productRouter.get(
  "/:id/reviews",
  optionalAuth,
  asyncHandler(getProductReviews),
);

export default productRouter;
