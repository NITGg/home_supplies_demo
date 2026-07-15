import { requireAuth } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminCourierStatService } from "./admin.courier.stat.service";
import {
  courierStatSchema,
  allCourierStatSchema,
} from "./admin.courier.stat.validation";

const router = Router();
const adminCourierStatService = new AdminCourierStatService();

router.get(
  "/courier-stat/:courierId",
  requireAuth,
  validation(courierStatSchema),
  adminCourierStatService.courierStat,
);
router.get(
  "/all-courier-stat",
  requireAuth,
  validation(allCourierStatSchema),
  adminCourierStatService.allCourierStat,
);

export default router;
