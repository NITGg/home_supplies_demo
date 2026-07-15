import z from "zod";
import { TransactionType, TransactionStatus } from "@prisma/client";

// Topup Schema
export const topupSchema = z.object({
  amount: z.number(),
});

// List Transaction Query Schema
export const listTransactionQuerySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
  order_id: z.string().regex(/^\d+$/).transform(Number).optional(),
  processed_by: z.string().regex(/^\d+$/).transform(Number).optional(),
  type: z.nativeEnum(TransactionType).optional(),
  status: z.nativeEnum(TransactionStatus).optional(),
  amount: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number)
    .optional(),
  created_atFrom: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  created_atTo: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  updated_atFrom: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  updated_atTo: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});
