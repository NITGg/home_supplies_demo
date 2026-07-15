import { z } from "zod";

export const upsertAppSettingsSchema = z
  .object({
    vat: z.number().min(0).max(100).optional(),
    live_payment: z.boolean().optional(),

    cancellation_fee_ratio: z.number().int().min(0).max(100).optional(),
    courier_cancellation_fee_ratio: z.number().int().min(0).max(100).optional(),

    app_android_url: z.string().optional().nullable(),
    app_android_version: z.string().optional().nullable(),
    app_ios_url: z.string().optional().nullable(),
    app_ios_version: z.string().optional().nullable(),

    login_attempt_duration_minutes: z.number().int().min(1).optional(),
    login_attempts: z.number().int().min(1).optional(),
    login_as_guest: z.boolean().optional(),
    permanent_delete: z.boolean().optional(),
    points_ratio: z.number().optional(),
    min_delivery_fee: z.number().optional(),
    completed_orders_required_to_earn_points: z.number().optional(),
    points_awarded_for_completed_orders: z.number().optional(),
    four_star_required_to_earn_points: z.number().optional(),
    points_awarded_for_4star: z.number().optional(),
    five_star_required_to_earn_points: z.number().optional(),
    points_awarded_for_5star: z.number().optional(),
    points_reset_days: z.number().optional(),
    point_value_eg: z.number().optional(),
    register_attempt_duration_minutes: z.number().optional(),
    register_attempts: z.number().optional(),
    update_password_attempt_duration_minutes: z.number().optional(),
    update_password_attempts: z.number().optional(),
    forget_password_attempt_duration_minutes: z.number().optional(),
    verify_account_attempt_duration_minutes: z.number().optional(),
    verify_account_attempts: z.number().optional(),
    change_account_attempt_duration_minutes: z.number().optional(),
    change_account_attempts: z.number().optional(),
    change_account_freeze_threshold: z.number().int().min(1).optional(),
    change_account_freeze_window_days: z.number().int().min(1).optional(),
    forget_password_attempts: z.number().optional(),
    global_api_duration_minutes: z.number().optional(),
    global_api_attempts: z.number().optional(),
    min_delivery_distance: z.string().optional(),
    delivery_price_for_each_1km: z.number().optional(),
    delivery_fee_ratio: z.number().optional(),
    max_delivery_fee: z.number().optional(),
    courier_app_url_android: z.string().optional().nullable(),
    courier_app_version_android: z.string().optional().nullable(),
    courier_app_url_ios: z.string().optional().nullable(),
    courier_app_version_ios: z.string().optional().nullable(),
    skip_otp: z.boolean().optional(),
    customer_budget_cash_on_delivery_limit: z.number().optional(),
    max_orders_per_trip: z.number().optional(),

    courier_number_of_points_required_per_1egp: z.number().optional(),
    courier_number_of_delivered_orders_required_per_reward_batch: z
      .number()
      .optional(),
    courier_number_of_points_awarded_per_completed_order_batch: z
      .number()
      .optional(),
    courier_points_validity_days: z.number().optional(),
    courier_points_minimum_rating_threshold: z.number().optional(),
    courier_points_expiration_notification_days: z.number().optional(),

    customer_number_of_points_required_per_1egp: z.number().optional(),
    customer_number_of_delivered_orders_required_per_reward_batch: z
      .number()
      .optional(),
    customer_number_of_points_awarded_per_completed_order_batch: z
      .number()
      .optional(),
    customer_points_validity_days: z.number().optional(),
    customer_points_minimum_rating_threshold: z.number().optional(),
    customer_points_expiration_notification_days: z.number().optional(),
    customer_points_cashback_percentage_per_orders_batch: z.number().optional(),
    min_platform_fee: z.number().optional(),

    fee_base_distance_km: z.number().optional(),
    fee_base_platform_cents: z.number().optional(),
    fee_base_courier_cents: z.number().optional(),
    fee_extra_platform_per_km: z.number().optional(),
    fee_extra_courier_per_km: z.number().optional(),
    peak_time_fee_ratio: z.number().optional(),

    courier_max_selected_areas: z.number().optional(),
    seller_commission_per_order: z.number().optional(),
    seller_commission_per_courier_download: z.number().optional(),
    seller_commission_per_customer_download: z.number().optional(),
    proposal_waiting_time_minutes: z.number().optional(),
    order_expiration_time_minutes: z.number().optional(),
    max_order_retry_count: z.number().optional(),
    chat_enable_send_images: z.boolean().optional(),

    // ── Payment gateway toggles ──
    paymob_enabled: z.boolean().optional(),
    kashier_enabled: z.boolean().optional(),
    easykash_enabled: z.boolean().optional(),

    courier_access_token_expires_in: z.string().optional(),
    courier_refresh_token_expires_in: z.string().optional(),
    supplier_access_token_expires_in: z.string().optional(),
    supplier_refresh_token_expires_in: z.string().optional(),

    customer_home_products_radius_km: z.number().optional(),
    customer_home_products_same_governorate: z.boolean().optional(),
    customer_home_products_cheapest_per_product: z.boolean().optional(),

    home_categories_grid_limit: z.number().optional(),

    customer_shopping_min_price_for_one_order: z.number().optional(),
    customer_shopping_max_price_for_one_order: z.number().optional(),
    otp_resend_duration_seconds: z.number().optional(),
    otp_length: z.number().optional(),
    otp_validity_duration_minutes: z.number().optional(),
  });

export type UpsertAppSettingsInput = z.infer<typeof upsertAppSettingsSchema>;
