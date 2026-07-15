import "dotenv/config";
import { PrismaMariaDb } from "@prisma/adapter-mariadb";
import { PrismaClient } from "@prisma/client";
import logger from "../../config/logger.config";
import { env } from "../../config/env";

const adapter = new PrismaMariaDb({
  host: env.DATABASE_HOST,
  user: env.DATABASE_USER,
  port: env.DATABASE_PORT,
  password: env.DATABASE_PASSWORD,
  database: env.DATABASE_NAME,
  connectionLimit: 5,
});

const prisma = new PrismaClient({
  errorFormat: "minimal",
  adapter,
  transactionOptions: {
    maxWait: 10000, //  10 seconds
    timeout: 15000, //  15s
  },
  log: [
    { level: "error", emit: "event" },
    { level: "warn", emit: "event" },
  ],
});

// Pipe Prisma events into Pino
prisma.$on("error", (e) =>
  logger.error({ target: e.target, message: e.message }, "[Prisma] Error"),
);
prisma.$on("warn", (e) =>
  logger.warn({ target: e.target, message: e.message }, "[Prisma] Warning"),
);

export { prisma };
