import { prisma } from "../../DB/lib/prisma";
import { webhookQueue } from "./webhook.queue";
import type { WebhookJobData, WebhookPayloadBase } from "./webhook.types";

export async function sendWebhookEvent<T extends WebhookPayloadBase>(
  externalAppId: number,
  data: WebhookJobData<T>,
): Promise<void> {
  // 1. Persist the event row first — survives Redis restarts
  const event = await prisma.webhookEvent.create({
    data: {
      external_app_id: externalAppId,
      event_type: data.eventType,
      payload: data.payload as object,
      delivery_status: "PENDING",
    },
    select: { id: true },
  });

  // 2. Enqueue — jobId ties queue job to DB row
  await webhookQueue.add(
    data.eventType,
    { ...data, webhookEventId: event.id },
    {
      jobId: event.id,
    },
  );
}
