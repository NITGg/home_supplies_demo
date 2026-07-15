import "dotenv/config";
import { PrismaMariaDb } from "@prisma/adapter-mariadb";
import env from "@/config/env";
import { PrismaClient } from "@prisma/client";

const adapter = new PrismaMariaDb({
  host: env.DATABASE_HOST,
  user: env.DATABASE_USER,
  port: env.DATABASE_PORT,
  password: env.DATABASE_PASSWORD,
  database: env.DATABASE_NAME,
  connectionLimit: 5,
  rowsAsArray: true,
});
const prisma = new PrismaClient({
  errorFormat: "minimal",
  adapter,
  transactionOptions: {
    maxWait: 10000, //  10 seconds
    timeout: 15000, //  15s
  },
});

export { prisma };
