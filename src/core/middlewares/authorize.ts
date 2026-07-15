import type { Request, Response, NextFunction } from "express";
import { ForbiddenError } from "../errors/app.error";

export const authorize = (...allowedRoles: any[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const user = (res as any).locals.user as any | undefined;
    
    if (!user) {
      throw new ForbiddenError("Authentication required before authorization");
    }

    if (!allowedRoles.includes(user.role?.name)) {
      throw new ForbiddenError(
        `Role '${user.role?.name}' is not authorized to access this resource`,
      );
    }

    next();
  };
};
