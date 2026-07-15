import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import {
  adminListLogs,
  adminGetLog,
  adminDeleteOldLogs,
} from "./logs.controller";

export const logsRouter = Router();

logsRouter.use(requireAuth);

// Both roles can list and view
logsRouter.get(
  "/",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminListLogs),
);
logsRouter.get(
  "/:id",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminGetLog),
);

// Only Admin can trigger manual cleanup
logsRouter.delete(
  "/cleanup",
  requireRole("Admin"),
  asyncHandler(adminDeleteOldLogs),
);
