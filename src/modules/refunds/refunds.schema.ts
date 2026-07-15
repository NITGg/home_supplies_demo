import { z } from "zod";

const refundItemsSchema = z
  .array(
    z.object({
      order_item_id: z.coerce.number().int(),
      quantity: z.coerce.number().int().positive(),
    }),
  )
  .min(1);

export const requestRefundSchema = z.object({
  order_id: z.coerce.number().int().positive(),
  reason: z.string().min(4).max(500),
  items: z.preprocess((value) => {
    if (typeof value === "string") {
      try {
        return JSON.parse(value);
      } catch {
        return value;
      }
    }

    return value;
  }, refundItemsSchema),
});

export type RequestRefundInput = z.infer<typeof requestRefundSchema>;

export const reviewRefundSchema = z.object({
  status: z.enum(["APPROVED", "REJECTED"]),
  admin_notes: z.string().optional(),
  fault_type: z.enum(["SUPPLIER", "COURIER", "PLATFORM"]).default("PLATFORM"),
  penalty_amount: z.number().nonnegative().optional().default(0),
});

export type ReviewRefundInput = z.infer<typeof reviewRefundSchema>;

export const refundIdParamSchema = z.object({
  id: z.coerce.number().int(),
});
