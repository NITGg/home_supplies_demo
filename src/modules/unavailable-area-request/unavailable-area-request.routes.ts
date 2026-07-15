import { Router } from "express";
import {
  createUnavailableAreaRequest,
  listUnavailableAreaRequests,
  getUnavailableAreaRequestStats,
  deleteUnavailableAreaRequest,
} from "./unavailable-area-request.controller";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole } from "@/middlewares/auth";

// ── Customer (public) ──────────────────────────────────────────────────────
export const unavailableAreaRequestRouter = Router();

unavailableAreaRequestRouter.post(
  "/",
  requireAuth,
  asyncHandler(createUnavailableAreaRequest),
);

// ── Admin ──────────────────────────────────────────────────────────────────

// stats must be registered before /:id to avoid being swallowed by param route
unavailableAreaRequestRouter.get(
  "/stats",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(getUnavailableAreaRequestStats),
);

unavailableAreaRequestRouter.get(
  "/",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(listUnavailableAreaRequests),
);

unavailableAreaRequestRouter.delete(
  "/:id",
  requireAuth,
  requireRole("Admin"),
  asyncHandler(deleteUnavailableAreaRequest),
);
