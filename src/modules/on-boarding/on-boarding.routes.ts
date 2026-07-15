import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import upload from "@/middlewares/upload";

import {
  adminCreateOnBoarding,
  adminDeleteOnBoarding,
  adminGetOnBoarding,
  adminListOnBoarding,
  adminUpdateOnBoarding,
  deleteManyOnBoarding,
  listPublicOnBoarding,
} from "./on-boarding.controller";

export const onBoardingRouter = Router();
export const adminOnBoardingRouter = Router();

// Public
onBoardingRouter.get("/", asyncHandler(listPublicOnBoarding));

// Admin
adminOnBoardingRouter.use(requireAuth);
adminOnBoardingRouter.use(requireRole("Admin"));
adminOnBoardingRouter.get("/", asyncHandler(adminListOnBoarding));
adminOnBoardingRouter.get("/:id", asyncHandler(adminGetOnBoarding));

// 👇 accept optional file field "image"
adminOnBoardingRouter.post(
  "/",
  upload.single("image"),
  asyncHandler(adminCreateOnBoarding),
);
adminOnBoardingRouter.put(
  "/:id",
  upload.single("image"),
  asyncHandler(adminUpdateOnBoarding),
);

adminOnBoardingRouter.delete("/", asyncHandler(deleteManyOnBoarding));
adminOnBoardingRouter.delete("/:id", asyncHandler(adminDeleteOnBoarding));
