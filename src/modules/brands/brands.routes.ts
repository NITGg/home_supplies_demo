import { Router } from "express";
import { requireAuth, requireRole, optionalAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import upload from "@/middlewares/upload";
import {
  listBrands,
  getBrand,
  adminCreateBrand,
  adminUpdateBrand,
  adminDeleteBrands,
  adminReorderBrands,
} from "./brands.controller";

const brandRouter = Router();
const adminOnly = [requireAuth, requireRole("Admin")];

brandRouter
  .route("/")
  .get(optionalAuth, asyncHandler(listBrands))
  .post(
    ...adminOnly,
    upload.fields([{ name: "logo_url" }, { name: "cover_url" }]),
    asyncHandler(adminCreateBrand),
  )
  .delete(...adminOnly, asyncHandler(adminDeleteBrands));

brandRouter.post("/reorder", ...adminOnly, asyncHandler(adminReorderBrands));

brandRouter
  .route("/:id")
  .get(optionalAuth, asyncHandler(getBrand))
  .put(
    ...adminOnly,
    upload.fields([{ name: "logo_url" }, { name: "cover_url" }]),
    asyncHandler(adminUpdateBrand),
  );

export default brandRouter;
