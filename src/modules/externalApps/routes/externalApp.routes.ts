import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { Router } from "express";
import {
  adminCreateExternalApp,
  adminDeleteExternalApp,
  adminUpdateExternalApp,
  getExternalApp,
  listExternalApps,
} from "../controllers/externalApp.controller";

const externalAppRouter = Router();
const adminOnly = [requireAuth, requireRole("Admin")];

externalAppRouter
  .route("/")
  .get(...adminOnly, asyncHandler(listExternalApps))
  .post(...adminOnly, asyncHandler(adminCreateExternalApp));

externalAppRouter
  .route("/:id")
  .get(...adminOnly, asyncHandler(getExternalApp))
  .put(...adminOnly, asyncHandler(adminUpdateExternalApp))
  .delete(...adminOnly, asyncHandler(adminDeleteExternalApp));

export default externalAppRouter;
