import { NextFunction, Request, Response } from "express";

export const responseHandler = ({
  req,
  res,
  next,
  status = 200,
  message = "OK",
  data = {},
  ...rest
}: {
  req?: Request;
  res: Response;
  next?: NextFunction;
  status?: number;
  message?: string;
  data?: Object;
  [key: string]: any;
}): Response => {
  return res.status(status).json({ status, message, data, ...rest });
};
