import { Prisma } from "@prisma/client";
import { Request, Response, NextFunction } from "express";
import { prisma } from "../../DB/lib/prisma";
import { getSocketIOServer } from "../../utils/socketio/socketio.server";
import logger from "../../config/logger.config";

interface RequestLoggerOptions {
  /** Routes to always skip, regardless of include list. Supports exact strings and RegExp. */
  exclude?: Array<string | RegExp>;
  /** If provided, only these routes are logged. Supports exact strings and RegExp. */
  include?: Array<string | RegExp>;
  /** Skip logging successful requests (2xx). Default: false */
  skipSuccess?: boolean;
  /** Log request body. Default: true */
  logBody?: boolean;
  /** Log query params. Default: true */
  logQuery?: boolean;
}

function matchesPattern(
  path: string,
  patterns: Array<string | RegExp>,
): boolean {
  return patterns.some((pattern) =>
    pattern instanceof RegExp ? pattern.test(path) : path === pattern,
  );
}

export function requestLogger(options: RequestLoggerOptions = {}) {
  const {
    exclude = [],
    include,
    skipSuccess = false,
    logBody = true,
    logQuery = true,
  } = options;

  // Always skip health checks unless explicitly included
  const defaultExcludes: Array<string | RegExp> = [/^\/api\/v1\/health/];
  const allExcludes = [...defaultExcludes, ...exclude];

  return function (req: Request, res: Response, next: NextFunction) {
    const path = req.originalUrl;

    // Check exclusions first
    if (matchesPattern(path, allExcludes)) return next();

    // If include list is set, only log matching routes
    if (include && !matchesPattern(path, include)) return next();

    const start = Date.now();

    res.on("finish", async () => {
      const status = res.statusCode;

      if (skipSuccess && status >= 200 && status < 300) return;

      const duration = Date.now() - start;

      const log: Prisma.LogUncheckedCreateInput = {
        method: req.method,
        path,
        status_code: status,
        duration,
        user_id: (req as any).user?.id ?? null,
        body:
          logBody && req.body && Object.keys(req.body).length > 0
            ? (sanitizeBody(req.body) as Prisma.JsonObject)
            : Prisma.JsonNull,
        query:
          logQuery && Object.keys(req.query).length > 0
            ? (req.query as Prisma.JsonObject)
            : Prisma.JsonNull,
        ip: req.ip ?? null,
        service: "COURIER",
      };

      // Fire-and-forget — never await logs in the request path
      try {
        // 🔹 1. Save to DB and capture the result
        // We include 'user' so the frontend gets the name immediately
        const savedLog = await prisma.log.create({
          data: log,
          include: {
            user: {
              select: { id: true, full_name: true, email: true, phone: true },
            },
          },
        });

        // 🔹 2. Emit the REAL data from Prisma
        getSocketIOServer().to("dashboard").emit("log:new", savedLog);

        logger.info(`[requestLogger] Logged: ${savedLog.id}`);
      } catch (err) {
        console.error("[requestLogger] DB save failed:", err);
      }
    });

    next();
  };
}

/** Strip sensitive fields before persisting */
function sanitizeBody(body: Record<string, unknown>): Record<string, unknown> {
  const SENSITIVE = new Set([
    "password",
    "token",
    "secret",
    "authorization",
    "cvv",
    "card_number",
  ]);
  return Object.fromEntries(
    Object.entries(body).filter(([key]) => !SENSITIVE.has(key.toLowerCase())),
  );
}
