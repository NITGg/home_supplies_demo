import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireAnyAuth } from "@/middlewares/auth";
import {
  createOrder,
  listMyOrders,
  getOrderById,
  cancelOrder,
  acceptProposal,
  listOrderProposals,
  confirmDelivery,
  priceAdjustment,
  retryOrder,
  createOrderIssue,
  getCompletedOrdersCount,
  previewOrder,
  getCourierLocation,
  getOrderFeeBounds,
  getCartDeliverySlots,
} from "./orders.controller";
import upload from "@/middlewares/upload";

const router = Router();

// ── External-app-accessible routes (requireAnyAuth) ───────────────────────────
router.post(
  "/",
  requireAnyAuth, // accepts user JWT or external-app JWT
  upload.single("product_image"),
  asyncHandler(createOrder),
);
router.get(
  "/:orderId/proposals",
  requireAnyAuth,
  asyncHandler(listOrderProposals),
);
router.put(
  "/:orderId/proposals/:proposalId",
  requireAnyAuth,
  asyncHandler(acceptProposal),
);
router.get("/", requireAnyAuth, asyncHandler(listMyOrders));
router.get("/:id", requireAnyAuth, asyncHandler(getOrderById));
router.post("/:id/cancel", requireAnyAuth, asyncHandler(cancelOrder));
router.put(
  "/:orderId/price-adjustment",
  requireAnyAuth,
  asyncHandler(priceAdjustment),
);
router.post("/preview", requireAnyAuth, asyncHandler(previewOrder));

// ── User-only routes ──────────────────────────────────────────────────────────
router.use(requireAuth);

// step: claude: available type-3 delivery slots for the customer's cart on a given date
router.get("/cart/delivery-slots", asyncHandler(getCartDeliverySlots));

router.get("/:id/fee-bounds", asyncHandler(getOrderFeeBounds));
router.get("/stats/completed-count", asyncHandler(getCompletedOrdersCount));
router.post("/:id/retry", asyncHandler(retryOrder));

router.put("/:orderId/price-adjustment", asyncHandler(priceAdjustment));
router.post("/confirm-delivery", asyncHandler(confirmDelivery));
router.post("/:orderId/issues", asyncHandler(createOrderIssue));
router.get("/:orderId/courier-location", asyncHandler(getCourierLocation));

export default router;
