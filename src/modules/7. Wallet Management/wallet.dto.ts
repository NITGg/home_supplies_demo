import z from "zod";
import {
  topupSchema,
  listTransactionQuerySchema,
} from "./wallet.validation";

export type TopupDTO = z.infer<typeof topupSchema>;
export type ListTransactionQueryDTO = z.infer<
  typeof listTransactionQuerySchema
>;