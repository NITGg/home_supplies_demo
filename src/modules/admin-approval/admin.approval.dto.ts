import z from "zod";
import {
  allCouriersSchema,
  approveCourierSchema,
  courierDetailsSchema,
  rejectCourierSchema,
  listProfileUpdateRequestsSchema,
  profileUpdateRequestIdSchema,
  rejectProfileUpdateRequestSchema,
} from "./admin.approval.validation";

export type WalletDTO = z.infer<typeof allCouriersSchema>;
export type courierDetailsDTO = z.infer<typeof courierDetailsSchema>;
export type approveCourier = z.infer<typeof approveCourierSchema>;
export type rejectCourier = z.infer<typeof rejectCourierSchema>;
export type listProfileUpdateRequestsDTO = z.infer<
  typeof listProfileUpdateRequestsSchema
>;
export type profileUpdateRequestIdDTO = z.infer<
  typeof profileUpdateRequestIdSchema
>;
export type rejectProfileUpdateRequestDTO = z.infer<
  typeof rejectProfileUpdateRequestSchema
>;