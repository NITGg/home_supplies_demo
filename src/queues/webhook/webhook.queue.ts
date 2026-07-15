import { redis, isRedisEnabled } from "@/config/redis";
import { Queue } from "bullmq";

export const webhookQueue = isRedisEnabled
  ? new Queue("webhooks", {
      connection: redis as any,
      defaultJobOptions: {
        attempts: 5,
        backoff: { type: "exponential", delay: 5000 },
        removeOnComplete: 1000,
        removeOnFail: 5000,
      },
    })
  : null;