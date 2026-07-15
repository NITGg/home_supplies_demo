import express, { NextFunction, Request, Response } from "express";
import path from "path";
import dotenv from "dotenv";
import router from "./routes";
import cors from "cors";
import helmet from "helmet";
import { errorMiddleware } from "./core/middlewares/error.middleware";
import { applyGlobalLimiter } from "./core/middlewares/limiter.middleware";
import logger from "../src/config/logger.config";
import { AppError } from "./core/errors/app.error";
import { HttpStatusCode } from "./core/http/http.status.code";
import { I18n } from "i18n";
import { socketIOServer } from "./utils/socketio/socketio.server";
import { requestLoggerMiddleware } from "./core/middlewares/request-logger.middleware";
import { pointsNodeCron } from "./utils/node-cron/points.node.cron";
import { requestLogger } from "./core/middlewares/requestLogger";
import { env } from "./config/env";
import "./queues/webhook";

const app = express();

// Trust proxy (e.g., Nginx) to correctly identify client IPs from X-Forwarded-For header
// This is required for express-rate-limit to work correctly behind a reverse proxy
app.set("trust proxy", 1);
dotenv.config({
  path: path.resolve("./.env"),
});
var whitelist = [
  "https://tawreedat.nitg-eg.com",
  "https://tawreedatgodashboard.nitg-eg.com",
  "https://admin-dashboard-dev.nitg-eg.com",
  "http://127.0.0.1:5501",
  "http://127.0.0.1:5502",
  "http://localhost:3000",
  "http://localhost:3001",
  "http://localhost:3100",
  undefined,
];
var corsOptions = {
  origin: function (origin: any, callback: any) {
    if (whitelist.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new AppError(HttpStatusCode.NOT_FOUND, "Not allowed by CORS"));
    }
  },
};
const i18n = new I18n({
  locales: ["ar", "en"],
  directory: path.join(__dirname, "./core/locals"),
  defaultLocale: "en",
  cookie: "locale",
  queryParameter: "lang",
  objectNotation: true,
  // Reload locale files in-memory when the admin i18n dashboard writes to them,
  // so translation edits apply without restarting the process.
  autoReload: true,
});

const bootstrap = async () => {
  app.use(helmet());
  app.use(applyGlobalLimiter);
  app.use(cors(corsOptions));
  app.use(express.json());
  app.use(
    requestLogger({
      // Skip noisy or sensitive routes entirely
      exclude: [
        /^\/uploads\//, // static files
        /^\/api\/v1\/health/, // health checks (already default-excluded)
        /^\/api\/v1\/logs/, // logs routes (already default-excluded)
      ],

      // --- Option A: log everything except excludes (comment out `include`) ---

      // --- Option B: log only specific routes ---
      // include: [
      //   /^\/api\/v1\/orders/,
      //   /^\/api\/v1\/auth/,
      //   "/api/v1/admin/wallet",
      // ],

      skipSuccess: false, // set true to only log 4xx/5xx
      logBody: true,
      logQuery: true,
    }),
  );
  app.use(requestLoggerMiddleware);
  app.use(i18n.init);
  app.use("/uploads", express.static(path.join(__dirname, "../uploads"))); // Serve static files from uploads directory
  app.use("/api/v1/courier", router);
  app.use(errorMiddleware);
  const httpServer = app.listen(env.PORT, () => {
    logger.info(`Backend server is running on port ${env.PORT} successfully`);
    logger.info("====================================================");
  });
  socketIOServer(httpServer);
  pointsNodeCron();
};

export { app, i18n };
export default bootstrap;
