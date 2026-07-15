import http from "node:http";
import env from "@/config/env";
import app from "@/app";
import { logger } from "@/config/logger";
import { prisma } from "@/config/prisma";
import { initI18n } from "@/i18n";
import { registerEvents } from "./events/register";
import { initSocket } from "@/socket";
import { initJobs } from "./jobs";
import "@/queues/webhook";

async function bootstrap() {
  try {
    await initI18n();
    logger.info("i18n initialized");

    // DB health check (fail fast)
    await prisma.$queryRaw`SELECT 1`;
    logger.info("Database connected");

    // ✅ Create HTTP server from express app
    const server = http.createServer(app);

    // ✅ Init socket and attach to same HTTP server
    initSocket(server);
    logger.info(
      `Socket.IO path:${env.PROD ? "/admin_apis/socket.io" : "/socket.io"}`,
    );
    // ✅ Register events AFTER socket init (so io exists)
    registerEvents();

    // corn jobs
    initJobs();

    // ✅ Listen using HTTP server (not app.listen)
    server.listen(env.PORT, () => {
      logger.info(
        `API + Socket running on http://localhost:${env.PORT}/api/v1/health`,
      );
    });

    // Graceful shutdown
    const shutdown = async (signal: string) => {
      logger.info(`${signal} received, shutting down...`);
      server.close(async () => {
        try {
          await prisma.$disconnect();
          logger.info("Database disconnected");
        } finally {
          process.exit(0);
        }
      });
    };

    process.on("SIGINT", shutdown);
    process.on("SIGTERM", shutdown);
  } catch (err) {
    logger.error({ err }, "Failed to start server");
    process.exit(1);
  }
}

bootstrap();
