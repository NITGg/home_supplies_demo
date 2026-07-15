import cron from "node-cron";
import { prisma } from "../../DB/lib/prisma";
import logger from "../../config/logger.config";
import { notifyUser } from "../firebase-notification/notification.service";

export const pointsNodeCron = () => {
  // Run on the 1st of every month at midnight
  cron.schedule("0 0 1 * *", async () => {
    logger.info("[Cron] Starting low completed orders...");
    try {
      // step: get all couriers
      const couriers = await prisma.courier.findMany({});

      // step: calculate number 
    } catch (error) {
      logger.error({ err: error }, "[Cron] Error running low completed orders");
    }
  });
};
