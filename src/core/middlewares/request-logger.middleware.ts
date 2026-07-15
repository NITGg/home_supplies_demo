import { NextFunction, Request, Response } from "express";
import logger from "../../config/logger.config";

/**
 * HTTP request logger middleware.
 * Logs method, URL, status code, and response time for every request.
 * Register this early in bootstrap, right after express.json().
 */
export const requestLoggerMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const startTime = Date.now();

  res.on("finish", () => {
    const responseTime = Date.now() - startTime;
    const logData = {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      responseTimeMs: responseTime,
      ip: req.ip,
    };

    if (res.statusCode >= 500) {
      logger.error(logData, `[HTTP] ${req.method} ${req.originalUrl}`);
    } else if (res.statusCode >= 400) {
      logger.warn(logData, `[HTTP] ${req.method} ${req.originalUrl}`);
    } else {
      logger.info(logData, `[HTTP] ${req.method} ${req.originalUrl}`);
    }
  });

  next();
};
