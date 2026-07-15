// src/modules/app-settings/app-settings.controller.ts
import type { Request, Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import { upsertAppSettingsSchema } from "./app-settings.schema";
import {
  getAppSettingsService,
  upsertAppSettingsService,
  getPublicAppSettingsService,
} from "./app-settings.service";

export async function getAppSettings(req: AuthedRequest, res: Response) {
  const settings = await getAppSettingsService();
  return res.json({ settings });
}

export async function upsertAppSettings(req: AuthedRequest, res: Response) {
  const data = upsertAppSettingsSchema.parse(req.sanitized.body);
  const settings = await upsertAppSettingsService(data);

  return res.json({
    message: req.t?.("settings:messages.updated") ?? "Settings updated",
    settings,
  });
}

export async function getPublicAppSettings(req: Request, res: Response) {
  const settings = await getPublicAppSettingsService();
  return res.json({ settings });
}
