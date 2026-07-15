import type { Request, Response } from "express";
import { prisma } from "@/config/prisma";
import { TokenExpiredError, JsonWebTokenError } from "jsonwebtoken";
import type { AuthedRequest } from "@/types/authedRequest";

// ─── Token Extraction ─────────────────────────────────────────────────────────

export function extractBearerToken(req: Request, res: Response): string | null {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({
      message: req.t("auth:errors.unauthorized"),
      code: "UNAUTHORIZED",
    });
    return null;
  }
  return header.slice("Bearer ".length).trim();
}

// ─── JWT Error Response ───────────────────────────────────────────────────────

export function sendJwtErrorResponse(
  req: Request,
  res: Response,
  err: unknown,
): void {
  if (err instanceof TokenExpiredError) {
    res.status(401).json({
      message: req.t("auth:errors.token_expired"),
      code: "TOKEN_EXPIRED",
      expiredAt: err.expiredAt,
    });
    return;
  }
  if (err instanceof JsonWebTokenError) {
    res.status(401).json({
      message: req.t("auth:errors.invalid_token"),
      code: "INVALID_TOKEN",
    });
    return;
  }

  console.error("Auth middleware error:", err);
  res
    .status(500)
    .json({ message: "Internal Server Error", code: "INTERNAL_ERROR" });
}

// ─── User Validation (shared by requireAuth + requireAnyAuth) ─────────────────

const USER_SELECT = {
  id: true,
  full_name: true,
  email: true,
  phone: true,
  is_active: true,
  deleted_at: true,
  password_last_updated: true,
  role: { select: { name: true } },
  wallet: { select: { frozen_at: true } },
} as const;

export async function resolveUserFromPayload(
  req: Request,
  res: Response,
  payload: { userId: number; iat?: number },
): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: payload.userId },
    select: USER_SELECT,
  });

  if (!user || user.deleted_at) {
    res.status(401).json({
      message: req.t("auth:errors.unauthorized"),
      code: "USER_NOT_FOUND",
    });
    return false;
  }

  if (!user.is_active) {
    res.status(403).json({
      message: req.t("auth:errors.account_disabled"),
      code: "ACCOUNT_DISABLED",
    });
    return false;
  }

  // A frozen wallet locks the user out of the whole app, not just login: every
  // authenticated request is rejected until an admin unfreezes the wallet.
  if (user.wallet?.frozen_at) {
    res.status(401).json({
      message: req.t("auth:errors.wallet_frozen"),
      code: "WALLET_FROZEN",
    });
    return false;
  }

  if (user.password_last_updated && payload.iat) {
    const tokenIssuedAt = new Date(payload.iat * 1000);
    if (user.password_last_updated > tokenIssuedAt) {
      res.status(401).json({
        message: req.t("auth:errors.token_invalidated"),
        code: "PASSWORD_CHANGED",
      });
      return false;
    }
  }

  const { password_last_updated, wallet, ...rest } = user;
  req.user = rest satisfies AuthedRequest["user"];
  return true;
}
