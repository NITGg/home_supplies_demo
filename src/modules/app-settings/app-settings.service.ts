import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type { UpsertAppSettingsInput } from "./app-settings.schema";

export async function getAppSettingsService() {
  const settings = await prisma.applicationSetting.findUnique({
    where: { id: 1 },
  });
  if (!settings) throw new HttpError(404, "settings:errors.not_found");
  return settings;
}

export async function upsertAppSettingsService(data: UpsertAppSettingsInput) {
  if (!data || Object.keys(data).length === 0) {
    throw new HttpError(400, "settings:errors.empty_payload");
  }

  // At least one payment gateway must stay enabled — only check when one of
  // the toggles is part of this update.
  if (
    "paymob_enabled" in data ||
    "kashier_enabled" in data ||
    "easykash_enabled" in data
  ) {
    const current = await prisma.applicationSetting.findUnique({
      where: { id: 1 },
      select: {
        paymob_enabled: true,
        kashier_enabled: true,
        easykash_enabled: true,
      },
    });
    const paymobEnabled = data.paymob_enabled ?? current?.paymob_enabled ?? true;
    const kashierEnabled = data.kashier_enabled ?? current?.kashier_enabled ?? false;
    const easykashEnabled =
      data.easykash_enabled ?? current?.easykash_enabled ?? false;

    if (!paymobEnabled && !kashierEnabled && !easykashEnabled) {
      throw new HttpError(400, "settings:errors.at_least_one_gateway_enabled");
    }
  }

  return prisma.applicationSetting.upsert({
    where: { id: 1 },
    create: {
      ...(data as any),
    },
    update: data,
  });
}

export async function getPublicAppSettingsService() {
  return prisma.applicationSetting.findUnique({
    where: { id: 1 },
    select: {
      app_android_url: true,
      app_android_version: true,
      app_ios_url: true,
      app_ios_version: true,
      min_delivery_distance: true,
      min_delivery_fee: true,
      delivery_price_for_each_1km: true,
      delivery_fee_ratio: true,
      order_expiration_time_minutes: true,
      customer_budget_cash_on_delivery_limit: true,
      customer_catalog_cod_limit: true,
      platform_supplier_id: true,
      min_platform_fee: true,
      chat_enable_send_images: true,
      paymob_enabled: true,
      kashier_enabled: true,
      easykash_enabled: true,
      home_categories_grid_limit: true,
      customer_shopping_min_price_for_one_order: true,
      customer_shopping_max_price_for_one_order: true,
      otp_length: true,
      otp_resend_duration_seconds: true,
    },
  });
}
