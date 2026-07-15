import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import { getAboutApp, upsertAboutApp } from "./about-app.controller";

const aboutAppRouter = Router();

aboutAppRouter.get("/", asyncHandler(getAboutApp));
aboutAppRouter.put(
  "/",
  requireAuth,
  requireRole("Admin"),
  asyncHandler(upsertAboutApp),
);

export default aboutAppRouter;
