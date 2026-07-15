import z from "zod";
import {
  buyCouponUsingPointsSchema,
  payFinesSchema,
  convertPointsToMoneySchema,
  payFinesUsingPointsSchema,
} from "./customer.points.validation";

export type BuyCouponUsingPointsDTO = z.infer<
  typeof buyCouponUsingPointsSchema
>;
export type ConvertPointsToMoneyDTO = z.infer<
  typeof convertPointsToMoneySchema
>;
export type PayFinesDTO = z.infer<typeof payFinesSchema>;
export type PayFinesUsingPointsDTO = z.infer<typeof payFinesUsingPointsSchema>;
