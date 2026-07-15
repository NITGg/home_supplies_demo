import { Router } from "express";
import { requireAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";

import {
  adminCreateArea,
  adminDeleteArea,
  adminGetArea,
  adminListAreas,
  adminUpdateArea,
  deleteManyAreas,
  getPublicArea,
  listPublicAreas,
} from "./areas.controller.js";

export const areasRouter = Router();
export const adminAreasRouter = Router();

// Public
areasRouter.get("/", asyncHandler(listPublicAreas));
areasRouter.get("/:id", asyncHandler(getPublicArea));

// Admin
adminAreasRouter.use(requireAuth);

adminAreasRouter.get("/", asyncHandler(adminListAreas));
adminAreasRouter.post("/", asyncHandler(adminCreateArea));
adminAreasRouter.delete("/", asyncHandler(deleteManyAreas));

adminAreasRouter.get("/:id", asyncHandler(adminGetArea));
adminAreasRouter.put("/:id", asyncHandler(adminUpdateArea));
adminAreasRouter.delete("/:id", asyncHandler(adminDeleteArea));
