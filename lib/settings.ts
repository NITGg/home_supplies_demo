import api from "./api";

export interface AppSettings {
  id?: number;
  // Financial
  vat?: number | null;
  cancellation_fee_ratio?: number | null;
  courier_cancellation_fee_ratio?: number | null;
  min_delivery_distance?: string | null;
  min_delivery_fee?: number | null;
  delivery_price_for_each_1km?: number | null;
  delivery_fee_ratio?: number | null;
  // Security
  login_attempt_duration_minutes?: number | null;
  login_attempts?: number | null;
  register_attempt_duration_minutes?: number | null;
  register_attempts?: number | null;
  update_password_attempt_duration_minutes?: number | null;
  update_password_attempts?: number | null;
  forget_password_attempt_duration_minutes?: number | null;
  forget_password_attempts?: number | null;
  verify_account_attempt_duration_minutes?: number | null;
  verify_account_attempts?: number | null;
  change_account_attempt_duration_minutes?: number | null;
  change_account_attempts?: number | null;
  change_account_freeze_threshold?: number | null;
  change_account_freeze_window_days?: number | null;
  global_api_duration_minutes?: number | null;
  global_api_attempts?: number | null;
  // Features
  skip_otp?: boolean | null;
  login_as_guest?: boolean | null;
  permanent_delete?: boolean | null;
  live_payment?: boolean | null;
  chat_enable_send_images?: boolean | null;
  courier_max_selected_areas?: number | null;
  // Commission
  seller_commission_per_order?: number | null;
  seller_commission_per_courier_download?: number | null;
  seller_commission_per_customer_download?: number | null;
  // Points courier
  courier_number_of_points_required_per_1egp?: number | null;
  courier_number_of_delivered_orders_required_per_reward_batch?: number | null;
  courier_number_of_points_awarded_per_completed_order_batch?: number | null;
  courier_points_validity_days?: number | null;
  courier_points_minimum_rating_threshold?: number | null;
  courier_points_expiration_notification_days?: number | null;
  // Points customer
  customer_number_of_points_required_per_1egp?: number | null;
  customer_number_of_delivered_orders_required_per_reward_batch?: number | null;
  customer_number_of_points_awarded_per_completed_order_batch?: number | null;
  customer_points_validity_days?: number | null;
  customer_points_minimum_rating_threshold?: number | null;
  customer_points_expiration_notification_days?: number | null;
  customer_points_cashback_percentage_per_orders_batch?: number | null;
  // App URLs
  app_android_url?: string | null;
  app_android_version?: string | null;
  app_ios_url?: string | null;
  app_ios_version?: string | null;
  courier_app_url_android?: string | null;
  courier_app_version_android?: string | null;
  courier_app_url_ios?: string | null;
  courier_app_version_ios?: string | null;
  // Order timing
  proposal_waiting_time_minutes?: number | null;
  order_expiration_time_minutes?: number | null;
  max_order_retry_count?: number | null;
  customer_budget_cash_on_delivery_limit?: number | null;
  // New fields
  fee_base_distance_km?: number | null;
  fee_base_platform_cents?: number | null;
  fee_base_courier_cents?: number | null;
  fee_extra_platform_per_km?: number | null;
  fee_extra_courier_per_km?: number | null;
  peak_time_fee_ratio?: number | null;
  max_orders_per_trip?: number | null;
  min_platform_fee?: number | null;
  // ── Payment gateway toggles ──
  paymob_enabled: boolean;
  kashier_enabled: boolean;
  easykash_enabled: boolean;
  // Token expiration settings
  courier_access_token_expires_in?: string | null;
  courier_refresh_token_expires_in?: string | null;
  supplier_access_token_expires_in?: string | null;
  supplier_refresh_token_expires_in?: string | null;
  // Customer home products
  customer_home_products_radius_km?: number | null;
  customer_home_products_same_governorate?: boolean | null;
  customer_home_products_cheapest_per_product?: boolean | null;
  home_categories_grid_limit?: number | null;
  // Customer shopping
  customer_shopping_min_price_for_one_order?: number | null;
  customer_shopping_max_price_for_one_order?: number | null;
  // OTP
  otp_resend_duration_seconds?: number | null;
  otp_length?: number | null;
  otp_validity_duration_minutes?: number | null;
}

export async function fetchSettings(): Promise<AppSettings> {
  const res = await api.get<{ settings: AppSettings }>("/app-settings");
  return res.data.settings;
}

export async function updateSettings(
  data: Partial<AppSettings>,
): Promise<void> {
  await api.put("/app-settings", data);
}
