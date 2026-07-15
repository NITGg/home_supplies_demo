import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";

import {
  adminListOrders,
  adminGetOrder,
  adminUpdateOrder,
  adminCancelOrder,
  adminListOrderProposals,
  adminUpdateProposal,
  adminManualAssignController,
  adminRetryOrderController,
  adminSoftCancelController,
  adminBroadcastFixedController,
  adminManualAssignFixedController,
  adminManualAssignControllerV2,
  adminDeleteOrderChat,
} from "./orders.admin.controller";

const router = Router();

// Protect everything under this router
router.use(requireAuth);

// Orders
router.get(
  "/",
  requireRole("Admin", "CustomerSupport", "CourierOffice"),
  asyncHandler(adminListOrders),
);
router.get(
  "/:id",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminGetOrder),
);
router.put("/:id", requireRole("Admin"), asyncHandler(adminUpdateOrder));
router.post(
  "/:id/cancel",
  requireRole("Admin"),
  asyncHandler(adminCancelOrder),
);

// Proposals
router.get(
  "/:id/proposals",
  requireRole("Admin"),
  asyncHandler(adminListOrderProposals),
);
router.patch(
  "/proposals/:proposalId",
  requireRole("Admin"),
  asyncHandler(adminUpdateProposal),
);

/**
 * POST /admin/orders/:orderId/assign
 * Playbook A — force-assign a courier
 */
router.post(
  "/:orderId/assign",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminManualAssignController),
);

router.post(
  "/:orderId/assignV2",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminManualAssignControllerV2),
);

/**
 * POST /admin/orders/:orderId/retry
 * Playbook B — re-open bidding with optional fee bump
 */
router.post(
  "/:orderId/retry",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminRetryOrderController),
);

/**
 * POST /admin/orders/:orderId/soft-cancel
 * Playbook C — cancel with NO_COURIERS_AVAILABLE + refund
 */
router.post(
  "/:orderId/soft-cancel",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminSoftCancelController),
);

/**
 * POST /admin/orders/:orderId/assign-fixed
 * Playbook D — force-assign a courier to a fixed fee offer
 */
router.post(
  "/:orderId/assign-fixed",
  requireRole("Admin"),
  asyncHandler(adminManualAssignFixedController),
);

/**
 * POST /admin/orders/:orderId/broadcast-fixed-offer
 * Playbook E — broadcast a fixed fee offer to available couriers
 */
router.post(
  "/:orderId/broadcast-fixed-offer",
  requireRole("Admin"),
  asyncHandler(adminBroadcastFixedController),
);

/**
 * DELETE /admin/orders/:orderId/chat
 * step: claude: "9- delete order user chat notifications" — hard-delete the chat
 * linked to an order (cascades to all messages + participants) and emit `chat:deleted`
 * socket event to every participant so they dismiss the chat view immediately.
 */
router.delete(
  "/:orderId/chat",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(adminDeleteOrderChat),
);

export default router;
