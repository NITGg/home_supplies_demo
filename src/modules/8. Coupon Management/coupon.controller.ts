import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { validation } from "../../core/middlewares/validation.middleware";
import { CouponService } from "./coupon.service";
import {
  buyCouponParamsSchema,
  historySchema,
} from "./coupon.validation";

const router = Router();
const couponService = new CouponService();

router.get("/list-available", auth, couponService.listAvalilable);
router.post("/buy-coupon/:id",auth,validation(buyCouponParamsSchema),couponService.buyCoupon);
router.get("/active", auth, couponService.active);
router.get("/history",auth,validation(historySchema),couponService.history);

export default router;
