import IORedis from "ioredis";
import dotenv from "dotenv";
import path from "node:path";

dotenv.config({
  path: path.resolve("./.env"),
});

export const redis = new IORedis({
  host: process.env.REDIS_HOST,
  port: Number(process.env.REDIS_PORT),
  password: process.env.REDIS_PASSWORD,
  maxRetriesPerRequest: null,
});
