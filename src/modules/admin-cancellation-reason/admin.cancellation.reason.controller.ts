import { requireAuth, requireRole } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminCancellationReasonService } from "./admin.cancellation.reason.service";
import {
  reasonSchema,
  updateReasonSchema,
} from "./admin.cancellation.reason.validation";

const router = Router();
const adminCancellationReasonService = new AdminCancellationReasonService();

router.post(
  "/reason",
  requireAuth,
  requireRole("Admin"),
  validation(reasonSchema),
  adminCancellationReasonService.reason,
);
router.put(
  "/update-reason/:reason_id",
  requireAuth,
  requireRole("Admin"),
  validation(updateReasonSchema),
  adminCancellationReasonService.updateReason,
);
router.get(
  "/reason-details/:reason_id",
  requireAuth,
  requireRole("Admin"),
  adminCancellationReasonService.reasonDetails,
);
router.get(
  "/all-reasons",
  requireAuth,
  requireRole("Admin", "Customer", "Seller", "Supplier"),
  adminCancellationReasonService.allReasons,
);
router.delete(
  "/delete-reason/:reason_id",
  requireAuth,
  requireRole("Admin"),
  adminCancellationReasonService.deleteReason,
);

export default router;
