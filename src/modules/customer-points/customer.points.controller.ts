import { Router } from "express";
import { requireAuth } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { CustomerPointsService } from "./customer.points.service";
import {
  convertPointsToMoneySchema,
  payFinesSchema,
  payFinesUsingPointsSchema,
} from "./customer.points.validation";

const router = Router();
const customerPointsService = new CustomerPointsService();

router.get("/rules", requireAuth, customerPointsService.rules);
router.get("/progress", requireAuth, customerPointsService.progress);
router.post(
  "/give-points-to-courier/:userId",
  requireAuth,
  customerPointsService.givePointsToCourier,
);
router.post(
  "/give-points-to-customer/:userId",
  requireAuth,
  customerPointsService.givePointsToCustomer,
);
router.post(
  "/convert-points-to-money",
  requireAuth,
  validation(convertPointsToMoneySchema),
  customerPointsService.convertPointsToMoney,
);
router.post(
  "/pay-fines",
  requireAuth,
  validation(payFinesSchema),
  customerPointsService.payFines,
);
router.post(
  "/pay-fines-using-points",
  requireAuth,
  validation(payFinesUsingPointsSchema),
  customerPointsService.payFinesUsingPoints,
);

export default router;
