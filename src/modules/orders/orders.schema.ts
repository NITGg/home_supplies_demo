import { z } from "zod";

export const OrderStatusEnum = z.enum([
  "PENDING",
  "IN_PROGRESS",
  "DELIVERED",
  "CANCELLED",
]);

export const PaymentMethodStatusEnum = z.enum(["WALLET", "CASH", "CARD"]);

export const cardPaymentProviderSchema = z.object({
  provider: z.enum(["paymob", "kashier"]).default("paymob"),
  redirection_url: z.string().trim().url().optional(),
});

// ─── CUSTOM_PICKUP (existing flow) ───────────────────────────────────────────

export const createCustomOrderSchema = z
  .object({
    type: z.literal("CUSTOM_PICKUP"),
    product_description: z.string().min(2).max(255),
    product_image: z.url().max(255).optional().nullable(),
    budget: z.coerce.number().nonnegative(),
    payment_method: PaymentMethodStatusEnum.default("CASH"),
    coupon_code: z.string().trim().min(1).optional(),
    pickup_area_id: z.coerce.number().int().positive(),
    pickup_address_description: z.string().min(2).max(200),
    pickup_lat: z.coerce.number(),
    pickup_long: z.coerce.number(),
    delivery_area_id: z.coerce.number().positive(),
    delivery_address_description: z.string().min(2).max(200),
    delivery_lat: z.coerce.number(),
    delivery_long: z.coerce.number(),
    vehicle_id: z.number().int().positive().optional(), // external app picks this
    // TODO: Order delivery date and time
    is_order_scheduled: z.coerce.boolean().optional(),
    order_schedule_at: z.coerce.date().optional(),
    // Card payment options (only used when payment_method === "CARD")
    card_provider: z.enum(["paymob", "kashier", "easykash"]).default("paymob"),
    card_redirection_url: z.string().trim().url().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.is_order_scheduled === true) {
      if (data.order_schedule_at == null) {
        ctx.addIssue({
          code: "custom",
          message: "Scheduled datetime is required when order is scheduled",
          path: ["order_schedule_at"],
        });
      }
    }
  });

// ─── CATALOG_PURCHASE (new flow) ─────────────────────────────────────────────

export const createCatalogOrderSchema = z
  .object({
    type: z.literal("CATALOG_PURCHASE"),
    payment_method: PaymentMethodStatusEnum.default("CASH"),
    coupon_code: z.string().trim().min(1).optional(),
    // Delivery location only — pickup is the supplier's location
    customer_address_id: z.coerce.number().positive().optional(),
    // TODO: Order delivery date and time
    is_order_scheduled: z.coerce.boolean().optional(),
    order_schedule_at: z.coerce.date().optional(),
    supplier_store_address_id: z.number().int().positive().optional(),
    // Card payment options (only used when payment_method === "CARD")
    card_provider: z.enum(["paymob", "kashier", "easykash"]).default("paymob"),
    card_redirection_url: z.string().trim().url().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.is_order_scheduled === true) {
      if (data.order_schedule_at == null) {
        ctx.addIssue({
          code: "custom",
          message: "Scheduled datetime is required when order is scheduled",
          path: ["order_schedule_at"],
        });
      }
      if (data.supplier_store_address_id == null) {
        ctx.addIssue({
          code: "custom",
          message:
            "Supplier store address id is required when order is scheduled",
          path: ["supplier_store_address_id"],
        });
      }
    }
  });

export const createOrderSchema = z.discriminatedUnion("type", [
  createCustomOrderSchema,
  createCatalogOrderSchema,
]);

export type CreateCustomOrderInput = z.infer<typeof createCustomOrderSchema>;
export type CreateCatalogOrderInput = z.infer<typeof createCatalogOrderSchema>;
export type CreateOrderInput = z.infer<typeof createOrderSchema>;
export type CardPaymentProviderInput = z.infer<typeof cardPaymentProviderSchema>;

// ─── Shared schemas (unchanged) ───────────────────────────────────────────────

export const orderIdParamsSchema = z.object({
  id: z.coerce.number().int().positive(),
});

// step: claude: query for fetching available type-3 delivery slots for the cart on a given date
export const deliverySlotsQuerySchema = z.object({
  date: z.coerce.date(),
});
export type DeliverySlotsQueryInput = z.infer<typeof deliverySlotsQuerySchema>;

export const cancelOrderSchema = z.object({
  cancelled_reason: z.string().min(2).max(1000),
  price_adjustment_status: z.literal("REJECTED").optional(),
  price_adjusted_at: z.date().optional(),
});
export type CancelOrderInput = z.infer<typeof cancelOrderSchema>;

export const acceptProposalParamsSchema = z.object({
  orderId: z.coerce.number().int().positive(),
  proposalId: z.coerce.number().int().positive(),
});

export const orderProposalsParamsSchema = z.object({
  orderId: z.coerce.number().int().positive(),
});

export const proposalDecisionSchema = z.object({
  status: z.enum(["ACCEPTED", "REJECTED"]),
});
export type ProposalDecisionInput = z.infer<typeof proposalDecisionSchema>;

export const confirmDeliverySchema = z.object({
  order_id: z.coerce.number().int().positive(),
  courier_id: z.coerce.number().int().positive(),
});
export type ConfirmDeliveryInput = z.infer<typeof confirmDeliverySchema>;

export const priceAdjustmentSchema = z.object({
  status: z.enum(["ACCEPTED", "REJECTED"]),
  reason: z.string().min(2).max(500).optional(),
});

export const createOrderIssueSchema = z.object({
  order_id: z.number(),
  reason: z.enum([
    "NOT_RESPONDING",
    "LATE_PICKUP",
    "LATE_DELIVERY",
    "WRONG_LOCATION",
    "OTHER",
  ]),
  description: z.string().max(1000).optional(),
});
export type CreateOrderIssueInput = z.infer<typeof createOrderIssueSchema>;
