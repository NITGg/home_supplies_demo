import IORedis from "ioredis";
import env from "@/config/env";

const isRedisEnabled = env.PROD || process.env.ENABLE_REDIS === "true";

// We export a function or the instance.
// If disabled, we return undefined or a dummy object.
export const redis = isRedisEnabled
  ? new IORedis({
      host: env.REDIS_HOST,
      port: Number(env.REDIS_PORT),
      password: env.REDIS_PASSWORD,
      maxRetriesPerRequest: null,
      lazyConnect: true,
    })
  : null;

export { isRedisEnabled };
