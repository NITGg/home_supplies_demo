import type { Request, Response, NextFunction } from "express";
import { verifyAccessToken } from "@/lib/jwt";
import { prisma } from "@/config/prisma";

export default async function optionalAuth(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) return next();

  const token = header.slice("Bearer ".length).trim();
  try {
    const payload = verifyAccessToken(token);
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        full_name: true,
        email: true,
        phone: true,
        is_active: true,
        deleted_at: true,
        password_last_updated: true,
        role: { select: { name: true } },
      }, // Light fetch
    });

    if (user && !user.deleted_at && user.is_active) {
      req.user = user;
    }
    next();
  } catch {
    next();
  }
}
