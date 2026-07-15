import {
  Router,
  Request,
  Response,
  NextFunction,
  RequestHandler,
} from "express";
import rateLimit from "express-rate-limit";
import env from "@/config/env";
import { prisma } from "@/config/prisma";
import {
  register,
  login,
  verifyMe,
  googleVerify,
  appleVerify,
  requestVerification,
  verifyAccount,
  forgetPassword,
  verifyForgetPassword,
  changePassword,
  changePhoneEmail,
  verifyOldNewPhoneEmail,
  logout,
  issueToken,
  linkGoogle,
  linkApple,
} from "./auth.controller";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth } from "@/middlewares/auth";

const router = Router();

// IP-level throttling for the public, unauthenticated verification endpoints
// (the per-channel cooldown in otp.service is the precise control; this is a
// coarse second layer against abuse). Mirrors the global limiter: PROD only.
// Cache for limiter instances to avoid recreating them on every request
const limitersCache = new Map<string, RequestHandler>();

const getDynamicLimiter = (
  scope: string,
  windowMinutes: number,
  limit: number,
  message: string = "Too many requests, please try again later.",
) => {
  // `scope` keeps limiters with identical window/limit settings (e.g.
  // forget-password vs verify-forget-password) from sharing the same
  // express-rate-limit store/bucket.
  const key = `${scope}-${windowMinutes}-${limit}`;
  if (!limitersCache.has(key)) {
    limitersCache.set(
      key,
      rateLimit({
        windowMs: windowMinutes * 60 * 1000,
        limit,
        standardHeaders: true,
        legacyHeaders: false,
        skip: () => !env.PROD,
        message: { message },
      }),
    );
  }
  return limitersCache.get(key)!;
};

const loginLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.login_attempt_duration_minutes ?? 30;
    const attempts = settings?.login_attempts ?? 5;
    const limiter = getDynamicLimiter("login", duration, attempts);
    return limiter(req, res, next);
  },
);

const registerLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.register_attempt_duration_minutes ?? 30;
    const attempts = settings?.register_attempts ?? 5;
    const limiter = getDynamicLimiter("register", duration, attempts);
    return limiter(req, res, next);
  },
);

const changePasswordLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.update_password_attempt_duration_minutes ?? 30;
    const attempts = settings?.update_password_attempts ?? 5;
    const limiter = getDynamicLimiter("change-password", duration, attempts);
    return limiter(req, res, next);
  },
);

// Bounds how often a reset code can be REQUESTED from a given IP.
const forgetPasswordLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.forget_password_attempt_duration_minutes ?? 30;
    const attempts = settings?.forget_password_attempts ?? 5;
    const limiter = getDynamicLimiter("forget-password", duration, attempts);
    return limiter(req, res, next);
  },
);

// Bounds how many OTP/code guesses an IP can make. Separate bucket from
// forgetPasswordLimiter so retrying a mistyped code can't lock the user out
// of requesting a fresh code (and vice versa).
const verifyForgetPasswordLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.forget_password_attempt_duration_minutes ?? 30;
    const attempts = settings?.forget_password_attempts ?? 5;
    const limiter = getDynamicLimiter(
      "verify-forget-password",
      duration,
      attempts,
    );
    return limiter(req, res, next);
  },
);

const verifyAccountLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.verify_account_attempt_duration_minutes ?? 30;
    const attempts = settings?.verify_account_attempts ?? 5;
    const limiter = getDynamicLimiter("verify-account", duration, attempts);
    return limiter(req, res, next);
  },
);

const changeAccountLimiter = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const settings = await prisma.applicationSetting.findFirst();
    const duration = settings?.change_account_attempt_duration_minutes ?? 30;
    const attempts = settings?.change_account_attempts ?? 5;
    const limiter = getDynamicLimiter("change-account", duration, attempts);
    return limiter(req, res, next);
  },
);

router.post("/register", registerLimiter, asyncHandler(register));
router.post("/login", loginLimiter, asyncHandler(login));
router.get("/verify-me", requireAuth, asyncHandler(verifyMe));
router.post("/logout", requireAuth, asyncHandler(logout));

router.post("/google/verify", asyncHandler(googleVerify));
router.post("/apple/verify", asyncHandler(appleVerify));

router.post("/link-google", requireAuth, asyncHandler(linkGoogle));
router.post("/link-apple", requireAuth, asyncHandler(linkApple));

// public (tokenless) verification — the only verification path now that
// register no longer issues a token (login is gated on verification)
router.post(
  "/request-verification",
  verifyAccountLimiter,
  asyncHandler(requestVerification),
);
router.post(
  "/verify-account",
  verifyAccountLimiter,
  asyncHandler(verifyAccount),
);

// forget-password flow (2-step: forget-password → verify-forget-password)
router.post(
  "/forget-password",
  forgetPasswordLimiter,
  asyncHandler(forgetPassword),
);
router.post(
  "/verify-forget-password",
  verifyForgetPasswordLimiter,
  asyncHandler(verifyForgetPassword),
);

// change password (authenticated — requires old password)
router.post(
  "/change-password",
  requireAuth,
  changePasswordLimiter,
  asyncHandler(changePassword),
);

// change phone or email (authenticated — sends OTP to the NEW value)
router.post(
  "/change-phone-email",
  requireAuth,
  changeAccountLimiter,
  asyncHandler(changePhoneEmail),
);
router.post(
  "/verify-old-new-phone-email",
  requireAuth,
  changeAccountLimiter,
  asyncHandler(verifyOldNewPhoneEmail),
);

router.post("/token", asyncHandler(issueToken));

export default router;
