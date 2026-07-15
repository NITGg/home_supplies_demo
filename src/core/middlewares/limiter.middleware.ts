import { Request, Response, NextFunction } from "express";
import { rateLimit } from "express-rate-limit";
import logger from "../../config/logger.config";
import { prisma } from "../../DB/lib/prisma";

let rateLimitersInitialized = false;
let globalLimiter: any;
let registerLimiter: any;
let loginLimiter: any;
let updatePasswordLimiter: any;
let forgetPasswordLimiter: any;
let offersLimiter: any;

export const initRateLimiters = async () => {
  if (rateLimitersInitialized) return;

  const settings = await prisma.applicationSetting.findFirst();

  if (!settings) {
    logger.error(
      "ApplicationSettings not found in DB. Using default rate limit values.",
    );
  }

  globalLimiter = rateLimit({
    windowMs: (settings?.global_api_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.global_api_attempts ?? 200,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    ipv6Subnet: 56,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl}`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_requests",
          options.limit.toString(),
          (options.windowMs / 60000).toString(),
        ),
      });
    },
  });

  registerLimiter = rateLimit({
    windowMs: (settings?.register_attempt_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.register_attempts ?? 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Register)`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_registration_attempts",
          options.limit.toString(),
          (options.windowMs / 60000).toString(),
        ),
      });
    },
  });

  loginLimiter = rateLimit({
    windowMs: (settings?.login_attempt_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.login_attempts ?? 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Login)`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_login_attempts",
          options.limit.toString(),
          (options.windowMs / 60000).toString(),
        ),
      });
    },
  });

  updatePasswordLimiter = rateLimit({
    windowMs:
      (settings?.update_password_attempt_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.update_password_attempts ?? 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Update Password)`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_password_update_attempts",
          options.limit.toString(),
          (options.windowMs / 60000).toString(),
        ),
      });
    },
  });

  forgetPasswordLimiter = rateLimit({
    windowMs:
      (settings?.forget_password_attempt_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.forget_password_attempts ?? 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Forget Password)`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_forget_password_attempts",
          options.limit.toString(),
          (options.windowMs / 60000).toString(),
        ),
      });
    },
  });

  offersLimiter = rateLimit({
    windowMs: (settings?.global_api_duration_minutes ?? 30) * 60 * 1000,
    limit: 500, // bigger limit for offers listing
    standardHeaders: "draft-8",
    legacyHeaders: false,
    ipv6Subnet: 56,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Offers)`,
      );

      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_requests",
          options.limit.toString(),
          (options.windowMs / 60000).toString(),
        ),
      });
    },
  });

  rateLimitersInitialized = true;
};

export const applyGlobalLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  globalLimiter(req, res, next);
};

export const applyRegisterLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  registerLimiter(req, res, next);
};

export const applyLoginLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  loginLimiter(req, res, next);
};

export const applyUpdatePasswordLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  updatePasswordLimiter(req, res, next);
};

export const applyForgetPasswordLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  forgetPasswordLimiter(req, res, next);
};

export const applyOffersLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  offersLimiter(req, res, next);
};
