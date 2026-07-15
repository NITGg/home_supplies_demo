import type { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";
import { HttpError } from "@/lib/httpError";
import { logger } from "@/config/logger";
import translateZodIssue from "@/errors/handelZodIssue";
import multer from "multer";
import { translateMulterError } from "@/errors/handleMulterIssue";
import { Prisma } from "@prisma/client";
import env from "@/config/env";

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Ensures we don't accidentally leak error objects inside the 'data' field
 */
function sanitizeData(data: any) {
  if (!data) return undefined;
  if (env.PROD) {
    // In production, if data is an error, don't send its details
    if (data instanceof Error) return undefined;
  }
  return data;
}

// ─── Per-error-type handlers ──────────────────────────────────────────────────
// Each returns true if it handled the error (so the caller can return early).

function handleMulterError(err: unknown, req: Request, res: Response): boolean {
  // Magic-byte rejection comes in as a plain Error with status 415 set by
  // the upload middleware — treat it the same as a MulterError.
  if (err instanceof multer.MulterError) {
    logger.debug("MulterError");
    const { status, body } = translateMulterError(req, err);
    res.status(status).json(body);
    return true;
  }
  return false;
}

function handleZodError(err: unknown, req: Request, res: Response): boolean {
  if (!(err instanceof ZodError)) return false;

  const errors = err.issues.map((i) => ({
    path: i.path,
    message: translateZodIssue(req, i),
  }));

  logger.debug(errors, "ZodError:");
  res.status(400).json({ message: req.t("errors.validation"), errors });
  return true;
}

function handleHttpError(err: unknown, req: Request, res: Response): boolean {
  if (!(err instanceof HttpError)) return false;

  logger.debug(err, "HttpError:");
  const msg =
    err.message.includes(".") && !err.message.includes(" ")
      ? req.t(err.message, err.data ?? {})
      : err.message;

  res.status(err.status).json({
    message: msg,
    code: err.code,
    data: sanitizeData(err.data),
  });
  return true;
}

function buildPrismaDevDetails(
  err: Prisma.PrismaClientKnownRequestError,
): object {
  // STRICT FIX: Only return database meta-data in non-production environments
  return env.PROD ? {} : { details: err.message, meta: err.meta };
}

function handlePrismaError(err: unknown, req: Request, res: Response): boolean {
  if (!(err instanceof Prisma.PrismaClientKnownRequestError)) return false;

  logger.error(err, "Prisma Error");
  const dev = buildPrismaDevDetails(err);

  if (err.code === "P2022") {
    res.status(500).json({
      message: req.t("errors.database_schema_mismatch"),
      ...(env.PROD ? {} : dev),
    });
    return true;
  }

  if (err.code === "P2002") {
    res.status(409).json({
      message: req.t("errors.conflict"),
      ...(env.PROD ? {} : dev),
    });
    return true;
  }

  // Known Prisma error but unhandled code — fall through to generic 500
  return false;
}

function handleUnknownError(err: unknown, req: Request, res: Response): void {
  // Always log the full stack trace internally for the dev team
  logger.error({ err }, "Unhandled error");

  const message =
    typeof req.t === "function"
      ? req.t("errors.internal")
      : "Internal server error";

  // STRICT FIX: Ensure stack traces never reach the client in production
  res.status(500).json({
    message,
    ...(env.PROD
      ? {}
      : {
          debug_message: err instanceof Error ? err.message : String(err),
          stack: err instanceof Error ? err.stack : undefined,
        }),
  });
}

// ─── Main error handler ───────────────────────────────────────────────────────

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  if (handleMulterError(err, req, res)) return;
  if (handleZodError(err, req, res)) return;
  if (handleHttpError(err, req, res)) return;
  if (handlePrismaError(err, req, res)) return;

  handleUnknownError(err, req, res);
}
