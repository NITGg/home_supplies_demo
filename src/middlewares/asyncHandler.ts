import type { RequestHandler, Request, Response, NextFunction } from "express";

type AnyAsyncHandler<Req extends Request> =
  | ((req: Req, res: Response) => Promise<any>)
  | ((req: Req, res: Response, next: NextFunction) => Promise<any>);

export const asyncHandler =
  <Req extends Request = Request>(fn: AnyAsyncHandler<Req>): RequestHandler =>
  (req, res, next) =>
    Promise.resolve((fn as any)(req as Req, res, next)).catch(next);
