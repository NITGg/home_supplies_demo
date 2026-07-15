import cron from "node-cron";
import { logger } from "@/config/logger";
import {
  handleExpiredOrders,
  handleNoProposalOrders,
  handleStalePendingPaymentOrders,
} from "@/modules/orders/admin/orders.admin.service";
import { handleScheduledOrders } from "./handle.scheduled.orders";

// Use flags to prevent concurrent execution of the same job
let isHandlingNoProposals = false;
let isHandlingExpiredOrders = false;
let isHandlingScheduledOrders = false;
let isHandlingStalePendingPayments = false;

export function registerOrderJobs() {
  // 🔹 Every minute → handleNoProposalOrders
  cron.schedule("* * * * *", async () => {
    if (isHandlingNoProposals) {
      logger.warn(
        "Job 'handleNoProposalOrders' is already running, skipping this tick.",
      );
      return;
    }

    isHandlingNoProposals = true;
    try {
      await handleNoProposalOrders();
    } catch (error) {
      logger.error({ error }, "Job failed: no proposal orders");
    } finally {
      isHandlingNoProposals = false; // Always release the lock
    }
  });

  // 🔹 Every minute → handleExpiredOrders
  cron.schedule("* * * * *", async () => {
    if (isHandlingExpiredOrders) {
      logger.warn(
        "Job 'handleExpiredOrders' is already running, skipping this tick.",
      );
      return;
    }

    isHandlingExpiredOrders = true;
    try {
      await handleExpiredOrders();
    } catch (error) {
      logger.error({ error }, "Job failed: expired orders");
    } finally {
      isHandlingExpiredOrders = false; // Always release the lock
    }
  });

  // 🔹 Every minute → handleScheduledOrders (SCHEDULED → PENDING when time arrives)
  cron.schedule("* * * * *", async () => {
    if (isHandlingScheduledOrders) {
      logger.warn(
        "Job 'handleScheduledOrders' is already running, skipping this tick.",
      );
      return;
    }

    isHandlingScheduledOrders = true;
    try {
      await handleScheduledOrders();
    } catch (error) {
      logger.error({ error }, "Job failed: scheduled orders");
    } finally {
      isHandlingScheduledOrders = false;
    }
  });

  // 🔹 Every minute → handleStalePendingPaymentOrders (abandoned CARD checkouts)
  cron.schedule("* * * * *", async () => {
    if (isHandlingStalePendingPayments) {
      logger.warn(
        "Job 'handleStalePendingPaymentOrders' is already running, skipping this tick.",
      );
      return;
    }

    isHandlingStalePendingPayments = true;
    try {
      await handleStalePendingPaymentOrders();
    } catch (error) {
      logger.error({ error }, "Job failed: stale pending payment orders");
    } finally {
      isHandlingStalePendingPayments = false;
    }
  });
}
