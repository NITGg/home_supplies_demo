import z from "zod";
import {
  topupSchema,
  listTransactionQuerySchema,
  listPenaltyQuerySchema,
  listUnpaidCommissionQuerySchema,
} from "./wallet.validation";

export type TopupDTO = z.infer<typeof topupSchema>;
export type ListTransactionQueryDTO = z.infer<
  typeof listTransactionQuerySchema
>;
export type ListPenaltyQueryDTO = z.infer<typeof listPenaltyQuerySchema>;
export type ListUnpaidCommissionQueryDTO = z.infer<
  typeof listUnpaidCommissionQuerySchema
>;
