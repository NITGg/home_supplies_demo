import z from "zod";
import {
  buyCouponParamsSchema,
  historySchema,
} from "./coupon.validation";

export type BuyCouponParamsDTO = z.infer<typeof buyCouponParamsSchema>;
export type CouponHistoryQueryDTO = z.infer<typeof historySchema>;
