import "dotenv/config";
import { defineConfig, env, PrismaConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma",
  datasource: {
    url: env("DATABASE_URL"),
  },
  migrations: {
    path: "prisma/migrations",
  },
}) satisfies PrismaConfig;
