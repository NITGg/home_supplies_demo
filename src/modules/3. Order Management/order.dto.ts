import z from "zod";
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

export type OrderIdParamDTO = z.infer<typeof orderIdParamSchema>;
export type AvailableOrdersQueryDTO = z.infer<typeof availableOrdersSchema>;
export type SubmitOfferDTO = z.infer<typeof submitOfferSchema>;
export type ReportUnavailableOrderDTO = z.infer<
  typeof reportUnavailableOrderSchema
>;
export type CancelOtherDTO = z.infer<typeof cancelOtherSchema>;
export type AcceptAssignedOrderDTO = z.infer<typeof acceptAssignedOrderSchema>;
export type RejectAssignedOrderDTO = z.infer<typeof rejectAssignedOrderSchema>;
export type ReportOrderHighPriceDTO = z.infer<
  typeof reportOrderHighPriceSchema
>;
export type CompleteDeliveryDTO = z.infer<typeof completeDeliverySchema>;
export type HistoryQueryDTO = z.infer<typeof historySchema>;

export type AcceptFixedFeeOfferDTO = z.infer<typeof acceptFixedFeeOfferSchema>;
export type UpdateLocationDTO = z.infer<typeof updateLocationSchema>;