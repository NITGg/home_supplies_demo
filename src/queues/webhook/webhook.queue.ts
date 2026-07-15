import { Queue } from "bullmq";
import { redis } from "../../DB/redis";

export const webhookQueue = new Queue("webhooks", {
  connection: redis,
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: "exponential",
      delay: 5000,
    },
    removeOnComplete: 1000,
    removeOnFail: 5000,
  },
});
