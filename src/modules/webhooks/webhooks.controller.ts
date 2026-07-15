import type { Request, Response } from "express";
import { logger } from "@/config/logger";
import {
  handlePaymobWebhook,
  handleKashierWebhook,
  handleEasykashWebhook,
} from "./webhooks.service";
import {
  walletRechargeConfirmCallbackSchema,
  walletRechargeConfirmHmacSchema,
  kashierWebhookBodySchema,
} from "@/modules/profile/schemas/wallet.schema";
import type { EasykashCallbackPayload } from "@/types/easykash.types";

// ─── EasyKash payment result page ─────────────────────────────────────────────

function easykashResultHtml(success: boolean, deepLink?: string): string {
  const color = success ? "#22c55e" : "#ef4444";
  const icon = success ? "✓" : "✗";
  const title = success ? "Payment Successful" : "Payment Failed";
  const subtitle = success
    ? "Your payment was processed successfully."
    : "Your payment could not be completed. Please try again.";

  // Auto-redirect to the mobile deep-link after 2 s if one is provided.
  const redirectScript = deepLink
    ? `<script>setTimeout(function(){window.location.href=${JSON.stringify(deepLink)};},2000);</script>`
    : "";
  const redirectButton = deepLink
    ? `<a class="btn" href="${deepLink}">Return to App</a>`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>${title}</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
         display:flex;align-items:center;justify-content:center;
         min-height:100vh;background:#f9fafb}
    .card{background:#fff;border-radius:16px;padding:48px 32px;
          text-align:center;max-width:360px;width:90%;
          box-shadow:0 4px 24px rgba(0,0,0,.08)}
    .icon{width:72px;height:72px;border-radius:50%;
          background:${color};color:#fff;
          font-size:36px;line-height:72px;margin:0 auto 20px}
    h1{font-size:22px;color:#111;margin-bottom:8px}
    p{font-size:15px;color:#6b7280;margin-bottom:28px}
    .btn{display:inline-block;padding:12px 28px;
         background:${color};color:#fff;border-radius:8px;
         text-decoration:none;font-size:15px;font-weight:600}
  </style>
  ${redirectScript}
</head>
<body>
  <div class="card">
    <div class="icon">${icon}</div>
    <h1>${title}</h1>
    <p>${subtitle}</p>
    ${redirectButton}
  </div>
</body>
</html>`;
}

export async function paymobWebhook(req: Request, res: Response) {
  const body = walletRechargeConfirmCallbackSchema.parse(req.sanitized.body);
  const { hmac } = walletRechargeConfirmHmacSchema.parse(req.query);

  const result = await handlePaymobWebhook(body, hmac);

  return res.status(200).json({
    message: result.alreadyApplied ? "Already applied" : "Payment processed",
    ...result,
  });
}

export async function easykashWebhook(req: Request, res: Response) {
  // EasyKash sends the callback as a GET with query params.
  // We encode the mobile deep-link as ?redirect= when creating the session
  // (see payment-gateway.service.ts) so we can retrieve it here.
  const { redirect: mobileRedirect, ...easykashParams } = req.query as Record<
    string,
    string
  >;
  const payload = easykashParams as unknown as EasykashCallbackPayload;

  logger.debug({ payload, mobileRedirect }, "[Webhook/EasyKash] received");

  let success = false;
  try {
    await handleEasykashWebhook(payload);
    success = true;
  } catch (err) {
    logger.error({ err }, "[Webhook/EasyKash] processing failed");
  }

  // Build the mobile deep-link with a paymentStatus param matching the
  // Kashier (?paymentStatus=SUCCESS) convention the app already listens for.
  const deepLink = mobileRedirect
    ? `${mobileRedirect}${mobileRedirect.includes("?") ? "&" : "?"}paymentStatus=${success ? "SUCCESS" : "FAILED"}`
    : undefined;

  return res
    .status(200)
    .set("Content-Type", "text/html")
    .send(easykashResultHtml(success, deepLink));
}

export async function kashierWebhook(req: Request, res: Response) {
  const body = kashierWebhookBodySchema.parse(req.sanitized.body);

  const headerSig =
    (req.headers["x-kashier-signature"] as string | undefined) ?? "";
  const querySig = (req.query?.signature as string | undefined) ?? "";
  const signature = headerSig || querySig;

  if (!signature) {
    logger.warn("[Webhook/Kashier] received without signature — rejecting");
    return res.status(401).json({ message: "Missing Kashier signature" });
  }

  const result = await handleKashierWebhook(body, signature);

  return res.status(200).json({
    message: result.alreadyApplied ? "Already applied" : "Payment processed",
    ...result,
  });
}
