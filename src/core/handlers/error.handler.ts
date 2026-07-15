import { NextFunction, Request, Response } from "express";
import { AppError } from "../errors/app.error";
import { HttpStatusCode } from "../http/http.status.code";
import { env } from "../../config/env";

export const errorHandler = ({
  err,
  req,
  res,
  next,
}: {
  err: AppError;
  req: Request;
  res: Response;
  next: NextFunction;
}) => {
  const statusCode = err.statusCode || 500;

  const isDev = env.NODE_ENV === "development";
  res.status(statusCode).json({
    status: statusCode,
    message: err.message || "Internal Server Error",
    ...(isDev && { stack: formatErrorStack(err.stack || "") }),
    ...(isDev && { errors: (err.cause as any)?.errors || [] }),
  });
};

// formatErrorStack
function formatErrorStack(stack: string) {
  if (!stack) return [];
  const lines = stack.split("\n").slice(1); // Skip error message line
  const parsed = [];
  for (const line of lines) {
    const match = line.match(/at\s+(.+?)\s+\((.+?)(?::(\d+):(\d+))?\)/);
    if (match) {
      parsed.push({
        function: match[1] || "unknown",
        file: match[2] || "unknown",
        line: match[3] && match[4] ? `${match[3]}:${match[4]}` : "unknown",
      });
    }
  }
  return parsed;
}
