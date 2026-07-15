import type { Response } from "express";
import { sendNotificationSchema } from "./notifications.schema";
import {
  sendAdminNotificationService,
  sendAdminNotificationStreamService,
} from "./notifications.service";
import { AuthedRequest } from "@/types/authedRequest";

export async function sendNotificationController(
  req: AuthedRequest,
  res: Response,
) {
  const parsed = sendNotificationSchema.parse(req.sanitized.body);
  const result = await sendAdminNotificationService(parsed);

  return res.status(200).json({
    message: req.t("notification:messages.sent_successfully"),
    data: result,
  });
}

export async function sendNotificationStreamController(
  req: AuthedRequest,
  res: Response,
) {
  const parsed = sendNotificationSchema.parse(req.sanitized.body);

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders?.();

  const sendEvent = (event: string, data: unknown) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  try {
    sendEvent("started", {
      message: req.t("notification:messages.stream_started"),
    });

    const result = await sendAdminNotificationStreamService(
      parsed,
      (progress) => {
        sendEvent("progress", progress);
      },
    );

    sendEvent("done", {
      message: req.t("notification:messages.sent_successfully"),
      data: result,
    });
  } catch (error) {
    console.log(error);
    sendEvent("error", {
      message: req.t("notification:errors.send_failed"),
    });
  } finally {
    res.end();
  }
}
