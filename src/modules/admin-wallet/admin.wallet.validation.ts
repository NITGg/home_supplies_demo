import { TransactionStatus, TransactionType } from "@prisma/client";
import z from "zod";

// ========== walletsSchema ==========
export const walletsSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    user_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    owner_type: z.enum(["CUSTOMER", "COURIER", "PLATFORM", "SUPPLIER"]).optional(),
    balanceFrom: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    balanceTo: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    status: z.enum(["ACTIVE", "FROZEN"]).optional(),
    freeze_reason: z.string().optional(),
    frozen_atFrom: z.string().optional(),
    frozen_atTo: z.string().optional(),
    frozen_by: z.string().regex(/^\d+$/).transform(Number).optional(),
    created_atFrom: z.string().optional(),
    created_atTo: z.string().optional(),
    updated_atFrom: z.string().optional(),
    updated_atTo: z.string().optional(),
    deleted_atFrom: z.string().optional(),
    deleted_atTo: z.string().optional(),
  })
  .passthrough(); // FeatureApi params (includes, fields, sort, keyword, skip) pass through untouched

// ========== unpaidCommissionSchema ==========
export const unpaidCommissionSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    order_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    user_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    amountFrom: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    amountTo: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    is_paid: z
      .enum(["true", "false"])
      .transform((v) => v === "true")
      .optional(),
    created_atFrom: z.string().optional(),
    created_atTo: z.string().optional(),
    paid_atFrom: z.string().optional(),
    paid_atTo: z.string().optional(),
  })
  .passthrough();

// ========== penaltiesSchema ==========
export const penaltiesSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    user_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    created_by: z.string().regex(/^\d+$/).transform(Number).optional(),
    amountFrom: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    amountTo: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    reason: z.string().optional(),
    is_paid: z
      .enum(["true", "false"])
      .transform((v) => v === "true")
      .optional(),
    paid_atFrom: z.string().optional(),
    paid_atTo: z.string().optional(),
    is_waived: z
      .enum(["true", "false"])
      .transform((v) => v === "true")
      .optional(),
    waived_atFrom: z.string().optional(),
    waived_atTo: z.string().optional(),
    waived_by: z.string().regex(/^\d+$/).transform(Number).optional(),
    created_atFrom: z.string().optional(),
    created_atTo: z.string().optional(),
  })
  .passthrough();

// ========== escrowsSchema ==========
export const escrowsSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    order_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    wallet_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    held_amountFrom: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    held_amountTo: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    created_atFrom: z.string().optional(),
    created_atTo: z.string().optional(),
    updated_atFrom: z.string().optional(),
    updated_atTo: z.string().optional(),
  })
  .passthrough();

// ========== paymentMethodsSchema ==========
export const paymentMethodsSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    user_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    method_type: z
      .enum(["BANK_ACCOUNT", "INSTAPAY", "MOBILE_WALLET"])
      .optional(),
    provider: z.enum(["PAYMOB", "MANUAL"]).optional(),
    instapay_number: z.string().optional(),
    mobile_wallet_number: z.string().optional(),
    provider_customer_id: z.string().optional(),
    provider_payment_method_id: z.string().optional(),
    display_name: z.string().optional(),
    is_default: z
      .enum(["true", "false"])
      .transform((v) => v === "true")
      .optional(),
    created_atFrom: z.string().optional(),
    created_atTo: z.string().optional(),
    updated_atFrom: z.string().optional(),
    updated_atTo: z.string().optional(),
    deleted_atFrom: z.string().optional(),
    deleted_atTo: z.string().optional(),
  })
  .passthrough();

// ========== transactionsSchema ==========
export const transactionsSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    wallet_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    order_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    escrow_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    payment_method_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    processed_by: z.string().regex(/^\d+$/).transform(Number).optional(),
    type: z.nativeEnum(TransactionType).optional(),
    status: z.nativeEnum(TransactionStatus).optional(),
    reject_reason: z.string().optional(),
    amountFrom: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    amountTo: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    description: z.string().optional(),
    paymob_order_id: z.string().optional(),
    created_atFrom: z.string().optional(),
    created_atTo: z.string().optional(),
    updated_atFrom: z.string().optional(),
    updated_atTo: z.string().optional(),
  })
  .passthrough();

// ========== adjustBalanceSchema ========== (mutation — stays strict)
export const adjustBalanceSchema = z.object({
  wallet_id: z.number().int(),
  related_order_id: z.number().int().optional(),
  type: z.enum(["MANUAL_INCREASE", "MANUAL_DECREASE"]),
  amount: z.number(),
  description: z
    .string({ message: "Adjustment description is required" })
    .min(1, "Adjustment description must be at least 1 character")
    .max(500, "Adjustment description must not exceed 500 characters"),
});

// ========== freezeSchema ==========
export const freezeSchema = z.object({
  freeze_reason: z
    .string({ message: "Freeze reason is required" })
    .min(1, "Freeze reason must be at least 1 character")
    .max(255, "Freeze reason must not exceed 255 characters"),
});

// ========== applyPenaltySchema ==========
export const applyPenaltySchema = z.object({
  amount: z.number().int(),
  reason: z
    .string({ message: "Penalty reason is required" })
    .min(1, "Penalty reason must be at least 1 character")
    .max(255, "Penalty reason must not exceed 255 characters"),
});

// ========== CPWRSchema ==========
export const CPWRSchema = z.object({
  user_id: z.number().int(),
});

// ========== TPWRSchema ==========
export const TPWRSchema = z.object({
  amount: z.number().positive(),
  description: z
    .string({ message: "Topup description is required" })
    .min(1, "Topup description must be at least 1 character")
    .max(255, "Topup description must not exceed 255 characters"),
});

// ========== changeUserIdPWRSchema ==========
export const changeUserIdPWRSchema = z.object({
  user_id: z.number().int(),
});

// ========== incBalancePWRSchema ==========
export const incBalancePWRSchema = z.object({
  amount: z.number().min(0),
  description: z
    .string({ message: "Description is required" })
    .min(1, "Description must be at least 1 character")
    .max(255, "Description must not exceed 255 characters"),
});

// ========== decBalancePWRSchema ==========
export const decBalancePWRSchema = z.object({
  amount: z.number().min(0),
  description: z
    .string({ message: "Description is required" })
    .min(1, "Description must be at least 1 character")
    .max(255, "Description must not exceed 255 characters"),
});

// ========== settlingBalanceSchema ==========
export const settlingBalanceSchema = z.object({
  target_user_id: z.number().int().optional(),
  target_owner_type: z
    .enum(["PLATFORM", "COURIER", "CUSTOMER", "SUPPLIER"])
    .optional(),
  period_from: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, {
      message: "period_from must be a valid date in YYYY-MM-DD format",
    })
    .optional(),
  period_to: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, {
      message: "period_to must be a valid date in YYYY-MM-DD format",
    })
    .optional(),
  note: z.string().max(500, "Note must not exceed 500 characters").optional(),
});

// ========== settlementReportSchema ==========
export const settlementReportSchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
  limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
  user_id: z.coerce.number().int().optional(),
  period_from: z
    .string()
    .datetime({ message: "period_from must be a valid ISO datetime" })
    .optional(),
  period_to: z
    .string()
    .datetime({ message: "period_to must be a valid ISO datetime" })
    .optional(),
});
