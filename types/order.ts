export type OrderStatus =
  | "PENDING"
  | "IN_PROGRESS"
  | "DELIVERED"
  | "CANCELLED"
  | "SEARCHING_FAILED"
  | "EXPIRED";
export type PaymentMethodStatus = "WALLET" | "CASH";
export type PriceAdjustmentStatus =
  | "NONE"
  | "PENDING"
  | "ACCEPTED"
  | "REJECTED";

export interface OrderUserSummary {
  id: number;
  role_id?: number;
  badge_id?: number | null;
  full_name?: string | null;
  email?: string | null;
  phone?: string | null;
  personal_photo?: string | null;
  is_active?: boolean;
  lang?: string | null;
  login_type?: string | null;
  gender?: string | null;
  created_at?: string;
  updated_at?: string;
  deleted_at?: string | null;
}

export interface OrderCourierSummary {
  id: number;
  user_id?: number;
  vehicle_id?: number | null;
  vehicle_plate?: string | null;
  is_approved?: boolean;
  created_at?: string;
  updated_at?: string;
  deleted_at?: string | null;
}

export interface OrderAreaSummary {
  id: number;
  governorate_id?: number;
  name?: string;
  name_ar?: string;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface OrderCouponSummary {
  id: number;
  code?: string;
  title?: string;
  title_ar?: string;
  type?: string;
  discount_type?: string;
  discount_value?: number;
  is_active?: boolean;
}

export interface OrderProposal {
  id: number;
  order_id?: number;
  courier_id?: number;
  total_fee?: string | null;
  status?: string;
  courier_lat?: string | null;
  courier_long?: string | null;
  courier_location_address?: string | null;
  distance_to_pickup?: string | null;
  estimated_arrival_at_pickup?: number | null;
  vehicle_id?: number | null;
  created_at?: string;
  confirmed_at?: string | null;
}

export interface OrderReview {
  id: number;
  courier_id?: number;
  customer_id?: number;
  order_id?: number;
  rating?: number;
  comment?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface OrderUnpaidCommission {
  id: number;
  order_id?: number;
  user_id?: number;
  amount?: string | null;
  is_paid?: boolean;
  created_at?: string;
  paid_at?: string | null;
}

export interface OrderEscrow {
  id: number;
  order_id?: number;
  wallet_id?: number;
  held_amount?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface OrderTransaction {
  id: number;
  wallet_id?: number;
  order_id?: number;
  escrow_id?: number | null;
  payment_method_id?: number | null;
  processed_by?: number | null;
  type?: string;
  status?: string;
  reject_reason?: string | null;
  amount?: string | null;
  description?: string | null;
  paymob_order_id?: string | null;
  customer_coupon_id?: number | null;
  created_at?: string;
  updated_at?: string | null;
}

export type OrderType = "CUSTOM_PICKUP" | "CATALOG_PURCHASE";

export interface Order {
  id: number;
  type: OrderType; // Added
  customer_id: number | null;
  courier_id: number | null;
  supplier_id: number | null; // Added
  order_number: string;
  product_description?: string | null;
  product_image?: string | null;
  pickup_area_id: number | null;
  pickup_address_description?: string | null;
  pickup_lat?: string | null;
  pickup_long?: string | null;
  delivery_area_id: number | null;
  delivery_address_description?: string | null;
  delivery_lat?: string | null;
  delivery_long?: string | null;
  budget?: string | null;
  products_total?: string | null; // Added
  actual_price?: string | null;
  min_delivery_fee?: string | null;
  max_delivery_fee?: string | null;
  total_fee?: string | null;
  courier_fee?: string | null;
  platform_fee?: string | null;
  vat_amount?: string | null; // Added
  coupon_id?: number | null;
  discount_amount?: string | null;
  payable_amount?: string | null;
  price_adjustment_status?: PriceAdjustmentStatus | null;
  proposed_at?: string | null;
  price_adjusted_at?: string | null;
  payment_method?: PaymentMethodStatus | null;
  status?: OrderStatus | null;
  cancelled_reason?: string | null;
  cancellation_fee?: string | null;
  cancelled_by?: number | null;
  created_at?: string;
  update_at?: string | null;
  offer_accepted_at?: string | null;
  estemated_delivery_fee?: string | null;
  vehicle_id?: number | null; // Added
  order_collected_at?: string | null;
  delivered_at?: string | null;
  canceled_at?: string | null;
  customer?: OrderUserSummary | null;
  courier?: OrderCourierSummary | null;
  pickup_area?: OrderAreaSummary | null;
  delivery_area?: OrderAreaSummary | null;
  coupon?: OrderCouponSummary | null;
  proposals?: OrderProposal[];
  courierReviews?: OrderReview[];
  customerReviews?: OrderReview[];
  unpaidCommission?: OrderUnpaidCommission | null;
  escrows?: OrderEscrow[];
  transactions?: OrderTransaction[];
  // supplier?: OrderSupplierSummary | null; // Add this summary interface
  cart_id?: number | null; // Added
}

export interface UpdateOrderPayload {
  status?: OrderStatus;
  courier_id?: number;
  actual_price?: number;
  min_delivery_fee?: number;
  max_delivery_fee?: number;
  total_fee?: number;
  courier_fee?: number;
  platform_fee?: number;
  product_description?: string;
  product_image?: string;
  canceled_at?: string | null;
  cancellation_fee?: number | null;
}

export type CreatedByRole = "1" | "3" | "4";

export interface OrderFilter {
  id: string;
  customer_id: string;
  courier_id: string;
  order_number: string;
  pickup_area_id: string;
  delivery_area_id: string;
  coupon_id: string;
  price_adjustment_status: string;
  payment_method: string;
  status: string;
  budgetFrom: string;
  budgetTo: string;
  actual_priceFrom: string;
  actual_priceTo: string;
  total_feeFrom: string;
  total_feeTo: string;
  courier_feeFrom: string;
  courier_feeTo: string;
  platform_feeFrom: string;
  platform_feeTo: string;
  discount_amountFrom: string;
  discount_amountTo: string;
  payable_amountFrom: string;
  payable_amountTo: string;
  cancellation_feeFrom: string;
  cancellation_feeTo: string;
  estemated_delivery_feeFrom: string;
  estemated_delivery_feeTo: string;
  proposed_atFrom: string;
  proposed_atTo: string;
  price_adjusted_atFrom: string;
  price_adjusted_atTo: string;
  created_atFrom: string;
  created_atTo: string;
  update_atFrom: string;
  update_atTo: string;
  offer_accepted_atFrom: string;
  offer_accepted_atTo: string;
  delivered_atFrom: string;
  delivered_atTo: string;
  canceled_atFrom: string;
  canceled_atTo: string;
  order_collected_atFrom: string;
  order_collected_atTo: string;
  cancelled_by: string;
  created_by_role_id: string;
  has_proposals: string;
  vat_amountFrom: string;
  vat_amountTo: string;
  supplier_id: string;
  type: string;
  sort: string;
  customer_name: string;
  pickup_area_name: string;
  delivery_area_name: string;
  coupon_title: string;
}

export interface PaginatedOrdersResponse {
  totalOrders: number;
  totalPages: number;
  orders: Order[];
}

export interface CourierLocation {
  courierId: number;
  orderId: number;
  lat: number;
  lng: number;
  timestamp: string;
}
