import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { OrderService } from "./order.service";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  cancellationReasonDetailsSchema,
  notifyOrderReadySchema,
  orderDetailsSchema,
} from "./order.validation";

const router = Router();
const orderService = new OrderService();

router.get("/app-settings", auth, orderService.appSettings);
router.get("/list-orders", auth, orderService.listOrders);
router.get("/order-details/:orderId",auth,validation(orderDetailsSchema),orderService.orderDetails);
router.get("/all-cancellation-reasons",auth,orderService.allCancellationReasons);
router.get("/cancellation-reason-details/:reasonId",auth,validation(cancellationReasonDetailsSchema),orderService.cancellationReasonDetails);
router.post("/notify-order-ready/:orderId",auth,validation(notifyOrderReadySchema),orderService.notifyOrderReady);

export default router;
