import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import { Router } from "express";
import {
  getAppSettings,
  upsertAppSettings,
  getPublicAppSettings,
} from "./app-settings.controller";

const appSettingsRouter = Router();

// Admin/authed
appSettingsRouter.get(
  "/",
  requireAuth,
  requireRole("Admin"),
  asyncHandler(getAppSettings),
);
appSettingsRouter.put(
  "/",
  requireAuth,
  requireRole("Admin"),
  asyncHandler(upsertAppSettings),
);

// Public (selected fields only)
appSettingsRouter.get("/public", asyncHandler(getPublicAppSettings));

export default appSettingsRouter;
