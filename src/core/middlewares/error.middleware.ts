import { NextFunction, Request, Response } from "express";
import { errorHandler } from "../handlers/error.handler";
import { AppError } from "../errors/app.error";

export const errorMiddleware = (
  err: AppError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  errorHandler({ err, req, res, next });
};
