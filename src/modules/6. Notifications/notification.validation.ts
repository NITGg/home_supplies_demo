import z from "zod";

// Update Notification Settings Schema
export const updateSettingsSchema = z.object({
  new_orders: z.boolean().optional(),
  offer_updates: z.boolean().optional(),
  badge_updates: z.boolean().optional(),
  push_enabled: z.boolean().optional(),
  allow_admin_notification: z.boolean().optional(),
});
