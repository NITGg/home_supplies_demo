import { prisma } from "@/config/prisma";
import { webhookQueue } from "@/queues/webhook/webhook.queue";
import { isRedisEnabled } from "@/config/redis";
import type { WebhookJobData, WebhookPayloadBase } from "./webhook.types";

export async function sendWebhookEvent<T extends WebhookPayloadBase>(
  externalAppId: number,
  data: WebhookJobData<T>,
): Promise<void> {
  // 1. Always persist to DB
  const event = await prisma.webhookEvent.create({
    data: {
      external_app_id: externalAppId,
      event_type: data.eventType,
      payload: data.payload as object,
      delivery_status: "PENDING",
    },
    select: { id: true },
  });

  // 2. Only add to queue if Redis/BullMQ is active
  if (isRedisEnabled && webhookQueue) {
    await webhookQueue.add(
      data.eventType,
      { ...data, webhookEventId: event.id },
      { jobId: event.id },
    );
  } else {
    console.log(
      `[Dev] Redis disabled. Webhook ${event.id} saved to DB but not enqueued.`,
    );
  }
}
