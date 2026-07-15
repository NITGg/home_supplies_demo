import cron from "node-cron";
import { logger } from "@/config/logger";
import { deleteOldLogsService } from "@/modules/logs/logs.service";

export function registerLogJobs() {
  // 🔹 Every day at 00:00 (Midnight)
  cron.schedule("0 0 * * *", async () => {
    try {
      logger.info("Starting log cleanup job...");
      const result = await deleteOldLogsService();
      logger.info(`Log cleanup successful: Deleted ${result.count} records.`);
    } catch (error) {
      logger.error({ error }, "job failed: log cleanup");
    }
  });
}
