import { NextFunction, Request, Response } from "express";
import { decodeToken, TokenTypesEnum } from "../../utils/decodeToken.js";
import { AppError } from "../errors/app.error.js";
import { HttpStatusCode } from "../http/http.status.code.js";
import logger from "../../config/logger.config";

export const auth = async (
  req: Request | any,
  res: Response,
  next: NextFunction,
) => {
  // step: check authorization
  const { authorization } = req.headers;
  if (!authorization) {
    logger.warn(
      { ip: req.ip, path: req.path, method: req.method },
      "[Auth] Unauthorized — missing token",
    );
    throw new AppError(
      HttpStatusCode.UNAUTHORIZED,
      "Authorization is required",
    );
  }
  const { user, payload } = await decodeToken({
    authorization,
    tokenType: TokenTypesEnum.access,
  });
  // step: modify res.locals
  res.locals.user = user;
  res.locals.payload = payload;
  // step: modify req for multer.local.upload
  req.user = user;
  return next();
};
