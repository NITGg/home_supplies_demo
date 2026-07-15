import { z } from "zod";

export const customerCouponIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const userIdParamSchema = z.object({
  userId: z.coerce.number().int().positive(),
});

export const customerCouponTypeEnum = z.enum([
  "ORDER_DISCOUNT",
  "WALLET_CREDIT",
]);
export const discountTypeEnum = z.enum(["PERCENT", "FIXED_CENTS"]);

export const couponScopeEnum = z.enum([
  "ORDER_TOTAL",
  "DELIVERY_FEE",
  "PRODUCTS_ONLY",
  "NOT_APPLICABLE",
]);

// ✅ Base schema
const customerCouponBaseSchema = z.object({
  code: z.string().trim().min(1).max(50).optional(),

  title: z.string().trim().min(1).max(255),
  title_ar: z.string().trim().max(255).optional().nullable(),
  description: z.string().optional().nullable(),
  description_ar: z.string().optional().nullable(),

  type: customerCouponTypeEnum,

  is_first: z.coerce.boolean().optional().default(false),
  button_text: z.string().trim().max(50).optional().nullable(),
  button_text_ar: z.string().trim().max(50).optional().nullable(),
  deleteImage: z.coerce.boolean().optional(),

  start_at: z.coerce.date().optional().nullable(),
  end_at: z.coerce.date().optional().nullable(),

  is_active: z.coerce.boolean().optional().default(true),
  max_total_uses: z.coerce.number().int().positive().optional().nullable(),
  max_user_uses: z.coerce.number().int().positive().optional().nullable(),
  min_orders_count: z.coerce.number().int().min(0).optional().default(0),

  // ORDER_DISCOUNT fields
  discount_type: discountTypeEnum.optional().nullable(),
  discount_value: z.coerce.number().int().positive().optional().nullable(),

  // ✅ Changed: scope is now optional/nullable in the base
  scope: couponScopeEnum.default("NOT_APPLICABLE"),

  max_discount_cents: z.coerce.number().int().positive().optional().nullable(),
  min_order_total_cents: z.coerce
    .number()
    .int()
    .positive()
    .optional()
    .nullable(),

  // WALLET_CREDIT fields
  wallet_amount_cents: z.coerce.number().int().min(0).optional().default(0),
  wallet_points: z.coerce.number().int().min(0).optional().default(0),
});

function refineCustomerCoupon(val: any, ctx: z.RefinementCtx) {
  // validity window
  if (val.start_at && val.end_at && val.end_at < val.start_at) {
    ctx.addIssue({
      code: "custom",
      message: "customer-coupons:errors.invalid_period",
      path: ["end_at"],
    });
  }

  // conditional requirements based on type
  if (val.type === "ORDER_DISCOUNT") {
    // ✅ Ensure scope is provided for discounts
    if (!val.scope || val.scope === "NOT_APPLICABLE") {
      ctx.addIssue({
        code: "custom",
        message: "customer-coupons:errors.scope_required_for_discount",
        path: ["scope"],
      });
    }

    if (!val.discount_type) {
      ctx.addIssue({
        code: "custom",
        message: "customer-coupons:errors.discount_type_required",
        path: ["discount_type"],
      });
    }

    if (!val.discount_value || val.discount_value <= 0) {
      ctx.addIssue({
        code: "custom",
        message: "customer-coupons:errors.discount_value_required",
        path: ["discount_value"],
      });
    }

    // percent bounds
    if (val.discount_type === "PERCENT" && val.discount_value != null) {
      if (val.discount_value < 1 || val.discount_value > 100) {
        ctx.addIssue({
          code: "custom",
          message: "customer-coupons:errors.percent_out_of_range",
          path: ["discount_value"],
        });
      }
    }
  }

  if (val.type === "WALLET_CREDIT") {
    const amount = val.wallet_amount_cents ?? 0;
    const points = val.wallet_points ?? 0;

    // If it's a fixed wallet credit (not a percentage cashback), scope can stay null.
    // But we must have some reward value.
    if (amount <= 0 && points <= 0) {
      ctx.addIssue({
        code: "custom",
        message: "customer-coupons:errors.wallet_reward_required",
        path: ["wallet_amount_cents"],
      });
    }
  }
}

// ✅ Create schema
export const createCustomerCouponSchema =
  customerCouponBaseSchema.superRefine(refineCustomerCoupon);

// ✅ Update schema
export const updateCustomerCouponSchema = customerCouponBaseSchema
  .partial()
  .superRefine((val, ctx) => {
    if (val.start_at && val.end_at && val.end_at < val.start_at) {
      ctx.addIssue({
        code: "custom",
        message: "customer-coupons:errors.invalid_period",
        path: ["end_at"],
      });
    }

    if (val.type === "ORDER_DISCOUNT") {
      // ✅ Require scope if changing type to discount
      if (!val.scope || val.scope === "NOT_APPLICABLE") {
        ctx.addIssue({
          code: "custom",
          message: "customer-coupons:errors.scope_required_for_discount",
          path: ["scope"],
        });
      }

      if (!val.discount_type) {
        ctx.addIssue({
          code: "custom",
          message: "customer-coupons:errors.discount_type_required",
          path: ["discount_type"],
        });
      }

      if (val.discount_value == null || val.discount_value <= 0) {
        ctx.addIssue({
          code: "custom",
          message: "customer-coupons:errors.discount_value_required",
          path: ["discount_value"],
        });
      }

      if (val.discount_type === "PERCENT" && val.discount_value != null) {
        if (val.discount_value < 1 || val.discount_value > 100) {
          ctx.addIssue({
            code: "custom",
            message: "customer-coupons:errors.percent_out_of_range",
            path: ["discount_value"],
          });
        }
      }
    }

    if (val.type === "WALLET_CREDIT") {
      const amount = val.wallet_amount_cents ?? 0;
      const points = val.wallet_points ?? 0;

      if (amount <= 0 && points <= 0) {
        ctx.addIssue({
          code: "custom",
          message: "customer-coupons:errors.wallet_reward_required",
          path: ["wallet_amount_cents"],
        });
      }
    }
  });

export const deleteManyCustomerCouponsSchema = z.object({
  ids: z.array(z.coerce.number().int().positive()).min(1),
  archived: z.boolean().optional(),
});
export const deleteCustomerCouponsSchema = z.object({
  id: z.coerce.number().int().positive(),
  archived: z.boolean().optional(),
});

export const validateCustomerCouponSchema = z.object({
  code: z.string().trim().min(1).max(50),
  orderType: z.enum(["CUSTOM_PICKUP", "CATALOG_PURCHASE"]).optional().default("CUSTOM_PICKUP"),
});

export type CreateCustomerCouponInput = z.infer<
  typeof createCustomerCouponSchema
>;
export type UpdateCustomerCouponInput = z.infer<
  typeof updateCustomerCouponSchema
>;
export type DeleteManyCustomerCouponsInput = z.infer<
  typeof deleteManyCustomerCouponsSchema
>;
export type ValidateCustomerCouponInput = z.infer<
  typeof validateCustomerCouponSchema
>;
