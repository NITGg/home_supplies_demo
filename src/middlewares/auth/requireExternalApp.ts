import type { Request, Response, NextFunction } from "express";
import { verifyExternalAppToken } from "@/lib/jwt";
import { extractBearerToken, sendJwtErrorResponse } from "./authHelpers";

export default function requireExternalApp(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const token = extractBearerToken(req, res);
  if (!token) return;

  try {
    req.externalApp = verifyExternalAppToken(token);
    next();
  } catch (err) {
    sendJwtErrorResponse(req, res, err);
  }
}
