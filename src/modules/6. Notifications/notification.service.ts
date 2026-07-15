import { NextFunction, Request, Response } from "express";
import { responseHandler } from "../../core/handlers/response.handler";
import { prisma } from "../../DB/lib/prisma";
import { UpdateSettingsDTO } from "./notification.dto";

export class NotificationService {
  constructor() {}

  // ============================ getSettings ============================
  getSettings = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get or create notification settings
    let settings = await prisma.notificationSetting.findUnique({
      where: { user_id: user.id },
    });

    // step: if no settings exist, create default settings
    if (!settings) {
      settings = await prisma.notificationSetting.create({
        data: {
          user_id: user.id,
          new_orders: true,
          offer_updates: true,
          badge_updates: true,
          push_enabled: true,
          allow_admin_notification: true,
        },
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.notification_settings_retrieved"),
      data: {
        new_orders: settings.new_orders,
        offer_updates: settings.offer_updates,
        badge_updates: settings.badge_updates,
        push_enabled: settings.push_enabled,
        allow_admin_notification: settings.allow_admin_notification,
      },
    });
  };

  // ============================ updateSettings ============================
  updateSettings = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const data: UpdateSettingsDTO = req.body;

    // step: upsert notification settings
    const settings = await prisma.notificationSetting.upsert({
      where: { user_id: user.id },
      update: {
        ...(data.new_orders !== undefined && { new_orders: data.new_orders }),
        ...(data.offer_updates !== undefined && {
          offer_updates: data.offer_updates,
        }),
        ...(data.badge_updates !== undefined && {
          badge_updates: data.badge_updates,
        }),
        ...(data.push_enabled !== undefined && {
          push_enabled: data.push_enabled,
        }),
        ...(data.allow_admin_notification !== undefined && {
          allow_admin_notification: data.allow_admin_notification,
        }),
      },
      create: {
        user_id: user.id,
        new_orders: data.new_orders ?? true,
        offer_updates: data.offer_updates ?? true,
        badge_updates: data.badge_updates ?? true,
        push_enabled: data.push_enabled ?? true,
        allow_admin_notification: data.allow_admin_notification ?? true,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.notification_settings_updated"),
      data: {
        new_orders: settings.new_orders,
        offer_updates: settings.offer_updates,
        badge_updates: settings.badge_updates,
        push_enabled: settings.push_enabled,
        allow_admin_notification: settings.allow_admin_notification,
      },
    });
  };
}
