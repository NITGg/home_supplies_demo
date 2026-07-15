import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import {
  adminListPeakTimes,
  adminGetPeakTime,
  adminCreatePeakTime,
  adminUpdatePeakTime,
  adminDeletePeakTime,
} from "./peak-time.controller";

export const adminPeakTimeRouter = Router();

// Admin — all routes require auth + Admin role
adminPeakTimeRouter.use(requireAuth);
adminPeakTimeRouter.use(requireRole("Admin"));

adminPeakTimeRouter.get("/list-peak-times", asyncHandler(adminListPeakTimes));
adminPeakTimeRouter.get("/peak-time-details/:id", asyncHandler(adminGetPeakTime));
adminPeakTimeRouter.post("/create-peak-time", asyncHandler(adminCreatePeakTime));
adminPeakTimeRouter.put("/update-peak-time/:id", asyncHandler(adminUpdatePeakTime));
adminPeakTimeRouter.delete("/delete-peak-time/:id", asyncHandler(adminDeletePeakTime));
