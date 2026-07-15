export interface CourierCoupon {
  id: number;
  title: string;
  title_ar: string;
  description: string;
  description_ar: string;
  price: string;
  bonus_courier_fee: string;
  duration_days: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CourierCouponFilter {
  id?: string;
  title?: string;
  title_ar?: string;
  priceFrom?: string;
  priceTo?: string;
  bonus_courier_feeFrom?: string;
  bonus_courier_feeTo?: string;
  duration_daysFrom?: string;
  duration_daysTo?: string;
  is_active?: string;
  created_atFrom?: string;
  created_atTo?: string;
  updated_atFrom?: string;
  updated_atTo?: string;
  deleted_atFrom?: string;
  deleted_atTo?: string;
}

export interface PaginatedCourierCouponsResponse {
  totalCoupons: number;
  totalPages: number;
  coupons: CourierCoupon[];
}

export interface CreateCourierCouponPayload {
  title: string;
  title_ar: string;
  description: string;
  description_ar: string;
  price: number;
  bonus_courier_fee: number;
  duration_days: number;
  is_active: boolean;
}

export interface UpdateCourierCouponPayload {
  title?: string;
  title_ar?: string;
  description?: string;
  description_ar?: string;
  price?: number;
  bonus_courier_fee?: number;
  duration_days?: number;
  is_active?: boolean;
}

export interface CourierCouponUsage {
  id: number;
  user_id: number;
  coupon_id: number;
  start_date: string;
  end_date: string;
  snapshot_price: string;
  snapshot_bonus_courier_fee: string;
  created_at: string;
  expiry_reminder_3d_sent_at: string | null;
  expiry_reminder_1d_sent_at: string | null;
  user?: {
    id: number;
    full_name: string;
    email: string;
    phone: string;
  };
}

export interface CourierCouponUsageFilter {
  id?: string;
  user_id?: string;
  coupon_id?: string;
  user_full_name?: string;
  snapshot_priceFrom?: string;
  snapshot_priceTo?: string;
  snapshot_bonus_courier_feeFrom?: string;
  snapshot_bonus_courier_feeTo?: string;
  created_atFrom?: string;
  created_atTo?: string;
  start_dateFrom?: string;
  start_dateTo?: string;
  end_dateFrom?: string;
  end_dateTo?: string;
  expiry_reminder_3d_sent_atFrom?: string;
  expiry_reminder_3d_sent_atTo?: string;
}

export interface PaginatedCourierCouponUsagesResponse {
  totalUsages: number;
  totalPages: number;
  usages: CourierCouponUsage[];
}

export type CustomerCouponType = "WALLET_CREDIT" | "ORDER_DISCOUNT";
export type CustomerCouponDiscountType = "PERCENT" | "FIXED_CENTS";
export type CouponScope =
  | "ORDER_TOTAL"
  | "DELIVERY_FEE"
  | "PRODUCTS_ONLY"
  | "NOT_APPLICABLE";

export interface CustomerCoupon {
  id: number;
  code: string;
  title: string;
  title_ar: string | null;
  description: string | null;
  description_ar: string | null;
  type: CustomerCouponType;
  start_at: string | null;
  end_at: string | null;
  is_active: boolean;
  deleted_at: string | null;
  max_total_uses: number | null;
  max_user_uses: number | null;
  min_orders_count: number;
  discount_type: CustomerCouponDiscountType | "null";
  discount_value: number;
  max_discount_cents: number;
  min_order_total_cents: number | null;
  wallet_amount_cents: number;
  wallet_points: number;
  is_purchasable: boolean;
  purchase_price_cents: number | null;
  scope: CouponScope;
  is_first: boolean;
  image: string | null;
  button_text: string | null;
  button_text_ar: string | null;
  created_at: string;
  updated_at: string;
}

export interface CustomerCouponFilter {
  id?: string;
  code?: string;
  title?: string;
  title_ar?: string;
  description?: string | null;
  description_ar?: string | null;
  type?: string;
  start_atFrom?: string;
  start_atTo?: string;
  end_atFrom?: string;
  end_atTo?: string;
  is_active?: string;
  max_total_usesFrom?: string;
  max_total_usesTo?: string;
  max_user_usesFrom?: string;
  max_user_usesTo?: string;
  min_orders_countFrom?: string;
  min_orders_countTo?: string;
  discount_type?: string;
  discount_valueFrom?: string;
  discount_valueTo?: string;
  max_discount_centsFrom?: string;
  max_discount_centsTo?: string;
  min_order_total_centsFrom?: string;
  min_order_total_centsTo?: string;
  wallet_amount_centsFrom?: string;
  wallet_amount_centsTo?: string;
  wallet_pointsFrom?: string;
  wallet_pointsTo?: string;
  is_purchasable?: string;
  scope?: string;
  is_first?: string;
  purchase_price_centsFrom?: string;
  purchase_price_centsTo?: string;
  created_atFrom?: string;
  created_atTo?: string;
  updated_atFrom?: string;
  updated_atTo?: string;
  deleted_atFrom?: string;
  deleted_atTo?: string;
}

export interface PaginatedCustomerCouponsResponse {
  totalCoupons: number;
  totalPages: number;
  coupons: CustomerCoupon[];
}

export interface CreateCustomerDiscountCouponPayload {
  title: string;
  type: "ORDER_DISCOUNT";
  discount_type: CustomerCouponDiscountType;
  discount_value: number;
  max_discount_cents: number;
  min_orders_count: number;
  is_active: boolean;
  code?: string;
  title_ar?: string;
  description?: string;
  description_ar?: string;
  start_at?: string;
  end_at?: string;
  max_total_uses?: number;
  max_user_uses?: number;
  min_order_total_cents?: number;
  scope?: CouponScope;
  is_first?: boolean;
  image?: string;
  button_text?: string;
  button_text_ar?: string;
}

export interface CreateCustomerWalletCouponPayload {
  title: string;
  type: "WALLET_CREDIT";
  wallet_amount_cents: number;
  wallet_points: number;
  max_user_uses: number;
  is_active: boolean;
  code?: string;
  title_ar?: string;
  description?: string;
  description_ar?: string;
  start_at?: string;
  end_at?: string;
  max_total_uses?: number;
  min_orders_count?: number;
  is_first?: boolean;
  image?: string;
  button_text?: string;
  button_text_ar?: string;
}

export type CreateCustomerCouponPayload =
  | CreateCustomerDiscountCouponPayload
  | CreateCustomerWalletCouponPayload;

export interface UpdateCustomerCouponPayload {
  title?: string;
  type?: CustomerCouponType;
  is_active?: boolean;
  code?: string;
  title_ar?: string | null;
  description?: string | null;
  description_ar?: string | null;
  start_at?: string | null;
  end_at?: string | null;
  max_total_uses?: number | null;
  max_user_uses?: number | null;
  min_orders_count?: number;
  // ORDER_DISCOUNT fields
  discount_type?: CustomerCouponDiscountType | null;
  discount_value?: number | null;
  max_discount_cents?: number | null;
  min_order_total_cents?: number | null;
  scope?: CouponScope;
  // WALLET_CREDIT fields
  wallet_amount_cents?: number;
  wallet_points?: number;
  // purchasable
  is_purchasable?: boolean;
  purchase_price_cents?: number | null;
  // misc
  is_first?: boolean;
  image?: string | null;
  button_text?: string | null;
  button_text_ar?: string | null;
  // restore: sending null undeletes the record
  deleted_at?: string | null;
}

export interface CustomerCouponUsage {
  id: number;
  user_id: number;
  coupon_id: number;
  context: string;
  order_id: number;
  discount_cents: number;
  created_at: string;
}

export interface CustomerCouponUsageFilter {
  id?: string;
  user_id?: string;
  coupon_id?: string;
  user_full_name?: string;
  context?: string;
  order_id?: string;
  discount_centsFrom?: string;
  discount_centsTo?: string;
  created_atFrom?: string;
  created_atTo?: string;
}

export interface PaginatedCustomerCouponUsagesResponse {
  totalUsages: number;
  totalPages: number;
  usages: CustomerCouponUsage[];
}
