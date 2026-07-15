import { requireAuth, requireRole } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminApprovalService } from "./admin.approval.service";
import {
  allCouriersSchema,
  approveCourierSchema,
  courierDetailsSchema,
  rejectCourierSchema,
  listProfileUpdateRequestsSchema,
  profileUpdateRequestIdSchema,
  rejectProfileUpdateRequestSchema,
} from "./admin.approval.validation";

const router = Router();
const adminApprovalService = new AdminApprovalService();

router.get(
  "/all-couriers",
  requireAuth,
  requireRole("Admin"),
  validation(allCouriersSchema),
  adminApprovalService.allCouriers,
);
router.get(
  "/courier-details/:courierId",
  requireAuth,
  requireRole("Admin"),
  validation(courierDetailsSchema),
  adminApprovalService.courierDetails,
);
router.post(
  "/approve-courier/:courierId",
  requireAuth,
  requireRole("Admin"),
  validation(approveCourierSchema),
  adminApprovalService.approveCourier,
);
router.post(
  "/reject-courier/:courierId",
  requireAuth,
  requireRole("Admin"),
  validation(rejectCourierSchema),
  adminApprovalService.rejectCourier,
);

// ─── Courier document update requests ──────────────────────────────────────
router.get(
  "/profile-update-requests",
  requireAuth,
  requireRole("Admin"),
  validation(listProfileUpdateRequestsSchema),
  adminApprovalService.listProfileUpdateRequests,
);
router.get(
  "/profile-update-requests/:requestId",
  requireAuth,
  requireRole("Admin"),
  validation(profileUpdateRequestIdSchema),
  adminApprovalService.profileUpdateRequestDetails,
);
router.post(
  "/profile-update-requests/:requestId/approve",
  requireAuth,
  requireRole("Admin"),
  validation(profileUpdateRequestIdSchema),
  adminApprovalService.approveProfileUpdateRequest,
);
router.post(
  "/profile-update-requests/:requestId/reject",
  requireAuth,
  requireRole("Admin"),
  validation(rejectProfileUpdateRequestSchema),
  adminApprovalService.rejectProfileUpdateRequest,
);

export default router;
