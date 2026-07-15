import { Router } from "express";
import { requireAuth, requireRole, optionalAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import upload from "@/middlewares/upload.js";

import {
  adminDeleteCategory,
  getCategory,
  listCategories,
  adminUpdateCategory,
  adminCreateCategory,
  adminReorderCategories,
} from "./categories.controller";

const categoryRouter = Router();

// Define Admin-only middleware stack
const adminOnly = [requireAuth, requireRole("Admin")];

categoryRouter
  .route("/")
  // GET is public (optional auth)
  .get(optionalAuth, asyncHandler(listCategories))
  // POST is Admin only
  .post(
    ...adminOnly,
    upload.fields([{ name: "image_url" }, { name: "icon_url" }]),
    asyncHandler(adminCreateCategory),
  );

// Reordering is Admin only
categoryRouter.post(
  "/reorder",
  ...adminOnly,
  asyncHandler(adminReorderCategories),
);

categoryRouter
  .route("/:id")
  // Individual GET is public (optional auth)
  .get(optionalAuth, asyncHandler(getCategory))
  // PUT is Admin only
  .put(
    ...adminOnly,
    upload.fields([{ name: "image_url" }, { name: "icon_url" }]),
    asyncHandler(adminUpdateCategory),
  )
  // DELETE is Admin only
  .delete(...adminOnly, asyncHandler(adminDeleteCategory));

export default categoryRouter;
