import type { Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import { upsertAboutAppSchema } from "./about-app.schema";
import { getAboutAppService, upsertAboutAppService } from "./about-app.service";
import { sanitizeWithHtmlFields } from "@/lib/sanitize";

/** Keys that store rich-text HTML content — sanitized with allowed tags. */
const HTML_FIELDS = new Set([
  "terms", "terms_ar",
  "courier_terms", "courier_terms_ar",
  "about", "about_ar",
  "privacy_policy", "privacy_policy_ar",
  "courier_privacy_policy", "courier_privacy_policy_ar",
  "mission", "mission_ar",
  "vision", "vision_ar",
  "digital_card", "digital_card_ar",
  "delete_account", "delete_account_ar",
]);

export async function getAboutApp(_req: AuthedRequest, res: Response) {
  const aboutApp = await getAboutAppService();
  return res.json({ about_app: aboutApp });
}

export async function upsertAboutApp(req: AuthedRequest, res: Response) {
  // Use rawBody (preserved before the global sanitizer strips all HTML),
  // then sanitize with safe HTML tags allowed for rich-text fields.
  const rawBody = (req as any).rawBody ?? req.body ?? {};
  const sanitized = sanitizeWithHtmlFields(rawBody, HTML_FIELDS);
  const data = upsertAboutAppSchema.parse(sanitized);
  const aboutApp = await upsertAboutAppService(data);

  return res.json({
    message: req.t?.("about-app:messages.updated") ?? "About app updated",
    about_app: aboutApp,
  });
}

