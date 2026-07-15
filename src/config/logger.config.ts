import pino from "pino";
import { env } from "./env";

const isProduction = env.NODE_ENV === "production";

const logger = pino({
  level: "info", // info || fatal || error || warn || debug || track || silent
  formatters: {
    level: (label) => {
      return { level: label.toUpperCase() };
    },
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: [
      "password",
      "token",
      "authorization",
      "accessToken",
      "refreshToken",
      "cookie",
      "req.headers.authorization",
      "req.headers.cookie",
    ],
    remove: true,
  },
  ...(isProduction
    ? {}
    : {
        transport: {
          target: "pino-pretty",
          options: {
            colorize: true,
            translateTime: "SYS:standard",
            ignore: "pid,hostname",
          },
        },
      }),
});

export default logger;
