import { Request, Response, NextFunction } from "express";
import { rateLimit } from "express-rate-limit";
import logger from "../../config/logger.config";
import { prisma } from "../../DB/lib/prisma";

let rateLimitersInitialized = false;
let globalLimiter: any;
let registerLimiter: any;
let loginLimiter: any;
let verifyAccountLimiter: any;
let updatePasswordLimiter: any;
let forgetPasswordLimiter: any;
let changeAccountLimiter: any;

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

  verifyAccountLimiter = rateLimit({
    windowMs:
      (settings?.verify_account_attempt_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.verify_account_attempts ?? 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Verify Account)`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_verify_account_attempts",
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

  changeAccountLimiter = rateLimit({
    windowMs:
      (settings?.change_account_attempt_duration_minutes ?? 30) * 60 * 1000,
    limit: settings?.change_account_attempts ?? 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (
      req: Request,
      res: Response,
      next: NextFunction,
      options: any,
    ) => {
      logger.warn(
        `Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl} (Change Account)`,
      );
      res.status(options.statusCode).json({
        message: res.__(
          "errors.too_many_change_account_attempts",
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

export const applyVerifyAccountLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  verifyAccountLimiter(req, res, next);
};

export const applyUpdatePasswordLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  updatePasswordLimiter(req, res, next);
};

export const applyChangeAccountLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  changeAccountLimiter(req, res, next);
};

export const applyForgetPasswordLimiter = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  await initRateLimiters();
  forgetPasswordLimiter(req, res, next);
};
