import z from "zod";
import {
  earningsHistoryQuerySchema,
  performanceQuerySchema,
} from "./stat.validation";

export type EarningsHistoryQueryDTO = z.infer<
  typeof earningsHistoryQuerySchema
>;
export type PerformanceQueryDTO = z.infer<typeof performanceQuerySchema>;
