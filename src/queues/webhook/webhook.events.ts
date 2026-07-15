// webhook.events.ts — mark FAILED only after all retries exhausted
import { logger } from "@/config/logger";
import { prisma } from "@/config/prisma";
import { redis, isRedisEnabled } from "@/config/redis";
import { QueueEvents } from "bullmq";

const events = isRedisEnabled
  ? new QueueEvents("webhooks", { connection: redis as any })
  : null;
// Define your interface to match what the worker returns
interface WebhookResult {
  status: number;
  statusText: string;
}

events?.on("completed", ({ jobId, returnvalue }) => {
  // Cast the returnvalue to your interface since it's already an object
  const result = returnvalue as unknown as WebhookResult;
  // Use the properties directly
  logger.info(
    `Webhook completed: ${jobId} | Status: ${result.status} ${result.statusText}`,
  );
});

events?.on("failed", async ({ jobId, failedReason }) => {
  logger.error(`Webhook failed: ${jobId} | Reason: ${failedReason}`);

  // QueueEvents does not expose getJob; update by jobId directly
  if (jobId) {
    await prisma.webhookEvent
      .update({
        where: { id: jobId },
        data: {
          delivery_status: "FAILED",
          last_error: failedReason,
        },
      })
      .catch(() => {}); // don't crash the events listener
  }
});
