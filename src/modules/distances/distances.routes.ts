import { Router } from "express";
import { requireAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { calculateDistanceController } from "./distances.controller";

export const distancesRouter = Router();
// Admin
distancesRouter.use(requireAuth);
distancesRouter.post("/", asyncHandler(calculateDistanceController));
