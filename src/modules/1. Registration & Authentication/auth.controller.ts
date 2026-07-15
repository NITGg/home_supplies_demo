import { Router, Request, Response, NextFunction } from "express";
import { AuthService } from "./auth.service";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  appleLoginSchema,
  changePasswordSchema,
  forgetPasswordSchema,
  googleLoginSchema,
  linkAppleSchema,
  linkGoogleSchema,
  loginSchema,
  referralCodeSchema,
  registerSchema,
  updatePasswordSchema,
  verifyPhoneSchema,
} from "./auth.validation";
import { auth } from "../../core/middlewares/auth.middleware";
import upload, { cleanupTempUploads } from "../../core/middlewares/upload";
import {
  applyRegisterLimiter,
  applyUpdatePasswordLimiter,
  applyForgetPasswordLimiter,
  applyLoginLimiter,
} from "../../core/middlewares/limiter.middleware";
import { googleRegisterSchema, appleRegisterSchema } from "./auth.validation";

const router = Router();
const authService = new AuthService();

// Todo: add service for send phone OTP
router.post(
  "/register",
  applyRegisterLimiter,
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "supplier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(registerSchema),
  authService.register,
);

router.post(
  "/google-register",
  applyRegisterLimiter,
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "supplier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(googleRegisterSchema),
  authService.googleRegister,
);

router.post(
  "/apple-register",
  applyRegisterLimiter,
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "supplier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(appleRegisterSchema),
  authService.appleRegister,
);

router.post("/verify-phone",validation(verifyPhoneSchema),authService.verifyPhone);

// Todo: add service for send phone OTP
router.post("/resend-phone-otp", authService.resendPhoneOTP);

// Todo: add service for send phone OTP
router.post("/login",applyLoginLimiter, validation(loginSchema), authService.login);

router.post("/refresh-token", authService.refreshToken);
router.post("/link-google",auth,validation(linkGoogleSchema),authService.linkGoogle);
router.post("/link-apple",auth,validation(linkAppleSchema),authService.linkApple);
router.post("/google-login",applyLoginLimiter,validation(googleLoginSchema),authService.googleLogin);
router.post("/apple-login",applyLoginLimiter,validation(appleLoginSchema),authService.appleLogin);
router.patch("/update-password",auth,applyUpdatePasswordLimiter,validation(updatePasswordSchema),authService.updatePassword);

// Todo: add service for send phone OTP
router.post("/forget-password",applyForgetPasswordLimiter,validation(forgetPasswordSchema),authService.forgetPassword);

router.patch("/change-password",validation(changePasswordSchema),authService.changePassword);
router.post("/logout", auth, authService.logout);

export default router;
