// webhook.worker.ts
import { Worker, Job } from "bullmq";
import crypto from "node:crypto";
import type { WebhookJobData, WebhookJobResponse } from "./webhook.types";
import { prisma } from "../../DB/lib/prisma";
import { redis } from "../../DB/redis";

export const webhookWorker = new Worker<WebhookJobData, WebhookJobResponse>(
  "webhooks",
  async (job: Job<WebhookJobData>) => {
    const { webhookUrl, webhookSecret, payload, eventType } = job.data;

    // Track attempt
    await prisma.webhookEvent.update({
      where: { id: job.id! },
      data: {
        attempts: { increment: 1 },
        last_attempt_at: new Date(),
      },
    });

    const rawBody = JSON.stringify(payload);
    const signature = crypto
      .createHmac("sha256", webhookSecret)
      .update(rawBody)
      .digest("hex");

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const response = await fetch(webhookUrl, {
        method: "POST",
        signal: controller.signal,
        headers: {
          "Content-Type": "application/json",
          Tawreedat_Signature: signature,
          "X-CA-Event": eventType,
        },
        body: rawBody,
      });

      clearTimeout(timeout);

      if (!response.ok) {
        const body = await response.text().catch(() => "");        
        // Update row but still throw so BullMQ retries
        await prisma.webhookEvent.update({
          where: { id: job.id! },
          data: {
            last_error: `HTTP ${response.status}`,
            response_status: response.status,
            response_body: body.slice(0, 500),
          },
        });
        throw new Error(`Webhook responded with status: ${response.status}`);
      }

      // Success — mark delivered
      await prisma.webhookEvent.update({
        where: { id: job.id! },
        data: {
          delivery_status: "DELIVERED",
          delivered_at: new Date(),
          response_status: response.status,
          last_error: null,
        },
      });

      return { status: response.status, statusText: response.statusText };
    } catch (error: any) {
      clearTimeout(timeout);
      const message =
        error.name === "AbortError"
          ? "Webhook request timed out after 10000ms"
          : error.message;
      throw new Error(message);
    }
  },
  { connection: redis, concurrency: 20 },
);
