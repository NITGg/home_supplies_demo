import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";

import {
  adminCreateGovernorate,
  adminDeleteGovernorate,
  adminGetGovernorate,
  adminListGovernorates,
  adminUpdateGovernorate,
  deleteManyGovernorates,
  getPublicGovernorate,
  listPublicGovernorates,
} from "./governorates.controller.js";

export const governoratesRouter = Router();
export const adminGovernoratesRouter = Router();

// Public
governoratesRouter.get("/", asyncHandler(listPublicGovernorates));
governoratesRouter.get("/:id", asyncHandler(getPublicGovernorate));

adminGovernoratesRouter.use(requireAuth);
// adminGovernoratesRouter.use(requireRole("Admin"));

adminGovernoratesRouter.get(
  "/",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminListGovernorates),
);
adminGovernoratesRouter.get(
  "/:id",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminGetGovernorate),
);

adminGovernoratesRouter.post(
  "/",
  requireRole("Admin"),
  asyncHandler(adminCreateGovernorate),
);
adminGovernoratesRouter.put(
  "/:id",
  requireRole("Admin"),
  asyncHandler(adminUpdateGovernorate),
);

adminGovernoratesRouter.delete(
  "/",
  requireRole("Admin"),
  asyncHandler(deleteManyGovernorates),
);
adminGovernoratesRouter.delete(
  "/:id",
  requireRole("Admin"),
  asyncHandler(adminDeleteGovernorate),
);
