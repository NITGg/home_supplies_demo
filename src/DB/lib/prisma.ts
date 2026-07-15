import "dotenv/config";
import { PrismaMariaDb } from "@prisma/adapter-mariadb";
import { PrismaClient } from "@prisma/client";
import path from "path";
import dotenv from "dotenv";
import logger from "../../config/logger.config";
dotenv.config({
  path: path.resolve("./.env"),
});
import { env } from "../../config/env";

const adapter = new PrismaMariaDb({
  host: env.DATABASE_HOST || "test",
  user: env.DATABASE_USER || "test",
  port: parseInt(env.DATABASE_PORT || "test"),
  password: env.DATABASE_PASSWORD || "test",
  database: env.DATABASE_NAME || "test",
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
