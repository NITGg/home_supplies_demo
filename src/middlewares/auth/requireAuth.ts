import type { Request, Response, NextFunction } from "express";
import { verifyAccessToken } from "@/lib/jwt";
import {
  extractBearerToken,
  resolveUserFromPayload,
  sendJwtErrorResponse,
} from "./authHelpers";

export default async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const token = extractBearerToken(req, res);
  if (!token) return;

  try {
    const payload = verifyAccessToken(token);
    req.auth = payload;

    const ok = await resolveUserFromPayload(req, res, payload);
    if (ok) next();
  } catch (err) {
    sendJwtErrorResponse(req, res, err);
  }
}
