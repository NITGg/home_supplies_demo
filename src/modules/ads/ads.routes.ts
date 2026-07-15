import { Router } from "express";
import { requireAuth, requireRole, optionalAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import upload from "@/middlewares/upload";

import {
  listAds,
  getAd,
  adminCreateAd,
  adminUpdateAd,
  adminDeleteAd,
  adminReorderAds,
} from "./ads.controller";

const adRouter = Router();

const adminOnly = [requireAuth, requireRole("Admin")];

adRouter
  .route("/")
  .get(optionalAuth, asyncHandler(listAds))
  .post(
    ...adminOnly,
    upload.fields([{ name: "image_url" }]),
    asyncHandler(adminCreateAd),
  );

adRouter.post("/reorder", ...adminOnly, asyncHandler(adminReorderAds));

adRouter
  .route("/:id")
  .get(optionalAuth, asyncHandler(getAd))
  .put(
    ...adminOnly,
    upload.fields([{ name: "image_url" }]),
    asyncHandler(adminUpdateAd),
  )
  .delete(...adminOnly, asyncHandler(adminDeleteAd));

export default adRouter;
