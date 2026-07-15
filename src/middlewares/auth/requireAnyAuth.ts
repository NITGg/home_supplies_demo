import type { Request, Response, NextFunction } from "express";
import { verifyAccessToken, verifyExternalAppToken } from "@/lib/jwt";
import { JsonWebTokenError } from "jsonwebtoken";
import {
  extractBearerToken,
  resolveUserFromPayload,
  sendJwtErrorResponse,
} from "./authHelpers";

export default async function requireAnyAuth(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const token = extractBearerToken(req, res);
  if (!token) return;

  // Try external-app first — sync, no DB call
  try {
    req.externalApp = verifyExternalAppToken(token);
    return next();
  } catch (err) {
    // Expired external-app token → reject immediately, don't try user path
    if (!(err instanceof JsonWebTokenError)) {
      return sendJwtErrorResponse(req, res, err);
    }
    // JsonWebTokenError = wrong secret/format → not an external-app token, fall through
  }

  // Try user token
  try {
    const payload = verifyAccessToken(token);
    req.auth = payload;

    const ok = await resolveUserFromPayload(req, res, payload);
    if (ok) next();
  } catch (err) {
    sendJwtErrorResponse(req, res, err);
  }
}
