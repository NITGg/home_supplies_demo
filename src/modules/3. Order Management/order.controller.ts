import { Router } from "express";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  orderIdParamSchema,
  submitOfferSchema,
  reportUnavailableOrderSchema,
  cancelOtherSchema,
  reportOrderHighPriceSchema,
  completeDeliverySchema,
  availableOrdersSchema,
  historySchema,
  acceptFixedFeeOfferSchema,
  updateLocationSchema,
  rejectAssignedOrderSchema,
  acceptAssignedOrderSchema,
} from "./order.validation";
import { auth } from "../../core/middlewares/auth.middleware";
import { requireCriminalRecord } from "../../core/middlewares/requireCriminalRecord.middleware";
import { OrderService } from "./order.service";

const router = Router();
const orderService = new OrderService();

router.get("/app-settings", orderService.appSettings);

// All order-module routes below require a valid (or in-grace-period) criminal record
router.use(auth);

router.get(
  "/available-orders",
  requireCriminalRecord,
  validation(availableOrdersSchema),
  orderService.availableOrders,
);
router.get(
  "/order-details/:id",
  requireCriminalRecord,
  orderService.orderDetails,
);
router.post(
  "/submit-offer/:orderId",
  requireCriminalRecord,
  validation(submitOfferSchema),
  orderService.submitOffer,
);
router.get("/active-order", orderService.activeOrder);
router.post("/order-collected/:orderId", orderService.orderCollected);
router.post(
  "/complete-delivery/:orderId",
  validation(completeDeliverySchema),
  orderService.completeDelivery,
);
router.post(
  "/cancel-unavailable/:orderId",
  validation(reportUnavailableOrderSchema),
  orderService.cancelUnavailable,
);
router.post(
  "/cancel-other/:orderId",
  validation(cancelOtherSchema),
  orderService.cancelOther,
);
router.post(
  "/accept-assigned-order/:orderId",
  requireCriminalRecord,
  validation(acceptAssignedOrderSchema),
  orderService.acceptAssignedOrder,
);
router.post(
  "/reject-assigned-order/:orderId",
  requireCriminalRecord,
  validation(rejectAssignedOrderSchema),
  orderService.rejectAssignedOrder,
);
router.post(
  "/report-order-high-price/:orderId",
  validation(reportOrderHighPriceSchema),
  orderService.reportOrderHighPrice,
);
router.get("/history", validation(historySchema), orderService.history);
router.get("/all-cancellation-reasons", orderService.allCancellationReasons);
router.get(
  "/cancellation-reason-details/:reasonId",
  orderService.cancellationReasonDetails,
);
router.post(
  "/fixed-fee-response/:orderId",
  requireCriminalRecord,
  validation(acceptFixedFeeOfferSchema),
  orderService.acceptFixedFeeOffer,
);
router.patch(
  "/:orderId/location",
  validation(updateLocationSchema),
  orderService.updateLocation,
);

export default router;
