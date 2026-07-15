import { z } from "zod";

export const OrderStatusEnum = z.enum([
  "PENDING",
  "IN_PROGRESS",
  "DELIVERED",
  "CANCELLED",
]);

export const ProposalStatusEnum = z.enum(["PENDING", "ACCEPTED", "REJECTED"]);

export const adminListOrdersQuerySchema = z.object({
  status: OrderStatusEnum.optional(),
  customer_id: z.coerce.number().positive().optional(),
  courier_id: z.coerce.number().positive().optional(),
  pickup_area_id: z.coerce.number().positive().optional(),
  delivery_area_id: z.coerce.number().positive().optional(),
  order_number: z.string().min(1).max(20).optional(),
  take: z.coerce.number().min(1).max(100).optional(),
  skip: z.coerce.number().min(0).optional(),
});

export type AdminListOrdersQuery = z.infer<typeof adminListOrdersQuerySchema>;

export const orderIdParamsSchema = z.object({
  id: z.coerce.number().positive(),
});

export const proposalIdParamsSchema = z.object({
  proposalId: z.coerce.number().positive(),
});

export const adminUpdateOrderSchema = z.object({
  // Admin can move status (use with care)
  status: OrderStatusEnum.optional(),

  courier_id: z.number().positive().nullable().optional(),

  actual_price: z.coerce.number().positive().nullable().optional(),
  min_delivery_fee: z.coerce.number().positive().nullable().optional(),
  max_delivery_fee: z.coerce.number().positive().nullable().optional(),
  total_fee: z.coerce.number().positive().nullable().optional(),
  courier_fee: z.coerce.number().positive().nullable().optional(),
  platform_fee: z.coerce.number().positive().nullable().optional(),

  cancelled_reason: z.string().max(2000).nullable().optional(),
  cancellation_fee: z.coerce.number().positive().nullable().optional(),
  cancelled_by: z.number().positive().nullable().optional(),
  cancelled_at: z.coerce.date().nullable().optional(),

  // allow updating product fields if needed
  product_description: z.string().min(2).max(255).optional(),
  product_image: z.url().max(255).nullable().optional(),
});

export type AdminUpdateOrderInput = z.infer<typeof adminUpdateOrderSchema>;

export const adminCancelOrderSchema = z.object({
  cancelled_reason: z.string().min(2).max(2000),
  cancellation_fee: z.coerce.number().positive().nullable().optional(),
  cancelled_by: z.number().positive().nullable().optional(),
});

export type AdminCancelOrderInput = z.infer<typeof adminCancelOrderSchema>;

export const adminUpdateProposalSchema = z.object({
  status: ProposalStatusEnum,
});

export type AdminUpdateProposalInput = z.infer<
  typeof adminUpdateProposalSchema
>;

export const adminRecoveryUpdateOrderSchema = z.object({
  status: z
    .enum([
      "PENDING",
      "SEARCHING_FAILED",
      "IN_PROGRESS",
      "DELIVERED",
      "CANCELLED",
      "EXPIRED",
    ])
    .optional(),
  cancelled_reason: z.string().optional(),
  cancelled_at: z.coerce.date().optional(),
  admin_notes: z.string().optional(),
});
export type AdminRecoveryUpdateOrderInput = z.infer<
  typeof adminRecoveryUpdateOrderSchema
>;

export const adminRecoveryCancelOrderSchema = z.object({
  cancelled_reason: z.string().min(1),
  cancellation_fee: z.number().optional(),
  cancelled_by: z.number().optional(),
});
export type AdminRecoveryCancelOrderInput = z.infer<
  typeof adminRecoveryCancelOrderSchema
>;

export const adminRecoveryUpdateProposalSchema = z.object({
  status: z.enum(["PENDING", "ACCEPTED", "REJECTED"]),
});
export type AdminRecoveryUpdateProposalInput = z.infer<
  typeof adminRecoveryUpdateProposalSchema
>;

// ── Playbook A: Manual Assignment ──────────────────────────────────────────

export const adminManualAssignSchema = z.object({
  /** The courier to force-assign */
  courier_id: z.number().int().positive(),

  /**
   * Optional override for the agreed total fee.
   * Defaults to the order's current estemated_delivery_fee or budget.
   */
  agreed_total_fee: z.number().positive().optional(),

  /** Admin note documenting the reason for manual assignment */
  admin_notes: z
    .string()
    .min(1, "Admin notes are required for manual assignment"),
});
export type AdminManualAssignInput = z.infer<typeof adminManualAssignSchema>;

// ── Playbook B: Market Re-entry (Retry) ────────────────────────────────────

export const adminRetryOrderSchema = z.object({
  /**
   * New delivery fee to offer couriers (must be >= current estemated_delivery_fee).
   * Leaving it out keeps the existing fee unchanged.
   */
  new_delivery_fee: z.number().positive().optional(),

  /**
   * How many extra minutes to add to the proposals deadline from now.
   * Defaults to 10 minutes if omitted.
   */
  deadline_extension_minutes: z.number().int().min(1).max(120).default(10),

  /**
   * How many extra minutes to extend the order expiry from now.
   * Defaults to 30 minutes if omitted.
   */
  expiry_extension_minutes: z.number().int().min(1).max(1440).default(30),

  /** Admin note documenting why the retry was triggered */
  admin_notes: z.string().min(1, "Admin notes are required for retry"),
});
export type AdminRetryOrderInput = z.infer<typeof adminRetryOrderSchema>;

// ── Playbook C: Soft Cancellation ──────────────────────────────────────────

export const adminSoftCancelSchema = z.object({
  /**
   * Optional flat cancellation fee charged to the customer.
   * If omitted no fee is deducted; the full escrowed amount is refunded.
   */
  cancellation_fee: z.number().min(0).optional(),

  /** Free-text note (e.g. "Contacted customer, agreed to cancel") */
  admin_notes: z.string().optional(),
});
export type AdminSoftCancelInput = z.infer<typeof adminSoftCancelSchema>;

export const resolveOrderIssueSchema = z.object({
  status: z.enum(["RESOLVED", "DISMISSED"]),
  resolution_note: z.string().max(2000).optional(),
});

export type ResolveOrderIssueInput = z.infer<typeof resolveOrderIssueSchema>;

export const adminSendFixedOfferSchema = z.object({
  courier_id: z.coerce.number().int().positive(),

  admin_notes: z
    .string()
    .max(500, "orders:errors.admin_notes_too_long")
    .optional(),
});

export const adminBroadcastFixedOfferSchema = z.object({
  admin_notes: z
    .string()
    .max(500, "orders:errors.admin_notes_too_long")
    .optional(),
});

export type AdminSendFixedOfferInput = z.infer<
  typeof adminSendFixedOfferSchema
>;

export type AdminBroadcastFixedOfferInput = z.infer<
  typeof adminBroadcastFixedOfferSchema
>;
