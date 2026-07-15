/**
 * Webhook Queue Module Entry Point
 *
 * Importing this file ensures that:
 * 1. The Queue is initialized.
 * 2. The Worker starts listening for jobs.
 * 3. Event listeners (completed/failed) are attached.
 */

import { logger } from "@/config/logger";

export * from "./webhook.queue";
export * from "./webhook.worker";
export * from "./webhook.events";
export * from "./webhook.types";
export * from "./webhook.service";

logger.info("Webhook Queue Module initialized and ready to process jobs.");
