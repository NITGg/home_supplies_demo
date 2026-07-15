import path from "path";
import dotenv from "dotenv";

dotenv.config({
  path: path.resolve("./.env"),
});

import { defineConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema",
  datasource: {
    url: process.env.DATABASE_URL,
  },
});
