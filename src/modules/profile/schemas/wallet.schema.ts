import { z } from "zod";

export const walletCouponCodeSchema = z.object({
  code: z
    .string()
    .trim()
    .min(1, "customer-coupons:errors.code_required")
    .max(64, "customer-coupons:errors.code_invalid"),
});

export type WalletCouponCodeInput = z.infer<typeof walletCouponCodeSchema>;

export const walletRechargeInitSchema = z.object({
  amount_cents: z.coerce
    .number()
    .int("profile:errors.recharge_amount_invalid")
    .positive("profile:errors.recharge_amount_invalid"),
  redirection_url: z.string().trim().url().optional(),
  /** Which payment gateway to use. Defaults to "paymob" for backwards compat */
  provider: z.enum(["paymob", "kashier", "easykash"]).default("paymob"),
});

export const walletRechargeConfirmHmacSchema = z.object({
  hmac: z.string().trim().min(1, "profile:errors.recharge_invalid_hmac"),
});

export const walletRechargeConfirmCallbackSchema = z.object({
  obj: z.object({
    id: z.coerce
      .number()
      .int("profile:errors.recharge_invalid_transaction")
      .positive("profile:errors.recharge_invalid_transaction"),
    success: z.boolean(),
    pending: z.boolean(),
    amount_cents: z.coerce
      .number()
      .int("profile:errors.recharge_amount_invalid")
      .positive("profile:errors.recharge_amount_invalid"),
    currency: z.string(),
    order: z.object({
      id: z.coerce
        .number()
        .int("profile:errors.recharge_invalid_transaction")
        .positive("profile:errors.recharge_invalid_transaction"),
    }),
    is_voided: z.boolean(),
    is_refunded: z.boolean(),
    is_3d_secure: z.boolean(),
    integration_id: z.coerce.number().int(),
    created_at: z.string(),
    error_occured: z.boolean(),
    has_parent_transaction: z.boolean(),
    is_auth: z.boolean(),
    is_capture: z.boolean(),
    is_standalone_payment: z.boolean(),
    owner: z.coerce.number().int(),
    source_data: z.object({
      type: z.string(),
      pan: z.string(),
      sub_type: z.string(),
    }),
  }),
  hmac: z
    .string()
    .trim()
    .optional(),
});

export const kashierWebhookHeaderSchema = z.object({
  "x-kashier-signature": z.string().min(1),
});

export const kashierWebhookBodySchema = z.object({
  event: z.string(),
  data: z.object({
    merchantOrderId:  z.string(),
    kashierOrderId:   z.string(),
    orderReference:   z.string().optional(),
    transactionId:    z.string().optional(),
    status:           z.enum(["SUCCESS", "FAILED", "PENDING"]),
    amount:           z.number(),
    currency:         z.string(),
    signatureKeys:    z.array(z.string()),
  }).passthrough(),
});

export type KashierWebhookBodyInput = z.infer<typeof kashierWebhookBodySchema>;
export type WalletRechargeInitInput = z.infer<typeof walletRechargeInitSchema>;
export type WalletRechargeConfirmHmacInput = z.infer<
  typeof walletRechargeConfirmHmacSchema
>;
export type WalletRechargeConfirmCallbackInput = z.infer<
  typeof walletRechargeConfirmCallbackSchema
>;
