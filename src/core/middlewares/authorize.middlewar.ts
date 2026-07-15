import type { Request, Response, NextFunction } from "express";
import { AppError } from "../errors/app.error";
import { HttpStatusCode } from "../http/http.status.code";
import { prisma } from "../../DB/lib/prisma";

export const authorize = (...allowedRoles: any[]) => {
  return async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    const user = res.locals.user;

    if (!user) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        "Authentication required before authorization",
      );
    }

    // step: get user role
    const userRole = await prisma.userRole.findFirst({
      where: {
        id: user.role_id,
      },
    });

    if (!userRole || !allowedRoles.includes(userRole.name)) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        `Role '${userRole?.name}' is not authorized to access this resource`,
      );
    }

    next();
  };
};
