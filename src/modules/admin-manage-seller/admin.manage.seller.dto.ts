import z from "zod";
import {
  getSellerStatSchema,
  referralCodeSchema,
} from "./admin.manage.seller.validation";

export type referralCodeDTO = z.infer<typeof referralCodeSchema>;
export type getSellerStatDTO = z.infer<typeof getSellerStatSchema>;
