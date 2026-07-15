import pino from "pino";
import env from "./env";

export const logger = pino({
  level: env.PROD ? "info" : "debug",
  transport: { target: "pino-pretty", options: { colorize: true } },
});

type LogMethod = typeof logger.info;

function devOnly(fn: LogMethod) {
  return (...args: Parameters<LogMethod>) => {
    if (!env.PROD) {
      fn(...args);
    }
  };
}

export const devLogger = {
  info: devOnly(logger.info.bind(logger)),
  debug: devOnly(logger.debug.bind(logger)),
  warn: devOnly(logger.warn.bind(logger)),
  error: devOnly(logger.error.bind(logger)),
};
