import z from "zod";

const positiveIntIdSchema = z.coerce.number().int("Invalid ID").min(1, "Invalid ID");

// Route params schemas (each route has its own schema)
export const orderDetailsSchema = z.object({
  orderId: positiveIntIdSchema,
});

export const cancellationReasonDetailsSchema = z.object({
  reasonId: positiveIntIdSchema,
});

export const notifyOrderReadySchema = z.object({
  orderId: positiveIntIdSchema,
});
