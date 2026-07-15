import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole } from "@/middlewares/auth";
import {
  requestRefund,
  listMyRefunds,
  getRefundById,
  cancelRefundRequest,
  reviewRefundRequest, // Usually for Admin but keeping here for logic flow
} from "./refunds.controller";
import upload from "@/middlewares/upload";

const refundRouter = Router();

refundRouter.use(requireAuth);

// Customer Routes
refundRouter.post(
  "/",
  upload.array("evidence_images", 5), // Allow up to 5 images
  asyncHandler(requestRefund),
);
refundRouter.get("/", asyncHandler(listMyRefunds));
refundRouter.get("/:id", asyncHandler(getRefundById));
refundRouter.post("/:id/cancel", asyncHandler(cancelRefundRequest));

// Admin/System Routes (Could be moved to an admin refundRouter)
refundRouter.put(
  "/:id/review",
  requireRole("Admin"),
  asyncHandler(reviewRefundRequest),
);

export default refundRouter;
