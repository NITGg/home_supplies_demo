import { Router, Request, Response, NextFunction } from "express";
import { AuthService } from "./auth.service";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  appleLoginSchema,
  changePasswordSchema,
  changePhoneSchema,
  forgetPasswordSchema,
  googleLoginSchema,
  linkAppleSchema,
  linkGoogleSchema,
  loginSchema,
  referralCodeSchema,
  registerSchema,
  resendOtpSchema,
  updatePasswordSchema,
  verifyOtpSchema,
} from "./auth.validation";
import { auth } from "../../core/middlewares/auth.middleware";
import upload, { cleanupTempUploads } from "../../core/middlewares/upload";
import {
  applyRegisterLimiter,
  applyLoginLimiter,
  applyVerifyAccountLimiter,
  applyUpdatePasswordLimiter,
  applyForgetPasswordLimiter,
  applyChangeAccountLimiter,
} from "../../core/middlewares/limiter.middleware";
import { googleRegisterSchema, appleRegisterSchema } from "./auth.validation";
import { authorize } from "../../core/middlewares/authorize";

const router = Router();
const authService = new AuthService();

router.post(
  "/register",
  applyRegisterLimiter,
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "vehicle_license_front", maxCount: 1 },
    { name: "vehicle_license_back", maxCount: 1 },
    { name: "courier_license_front", maxCount: 1 },
    { name: "courier_license_back", maxCount: 1 },
    { name: "courier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(registerSchema),
  authService.register,
);
router.post(
  "/google-register",
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "vehicle_license_front", maxCount: 1 },
    { name: "vehicle_license_back", maxCount: 1 },
    { name: "courier_license_front", maxCount: 1 },
    { name: "courier_license_back", maxCount: 1 },
    { name: "courier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(googleRegisterSchema),
  authService.googleRegister,
);
router.post(
  "/apple-register",
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "vehicle_license_front", maxCount: 1 },
    { name: "vehicle_license_back", maxCount: 1 },
    { name: "courier_license_front", maxCount: 1 },
    { name: "courier_license_back", maxCount: 1 },
    { name: "courier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(appleRegisterSchema),
  authService.appleRegister,
);
router.post("/verify-otp",applyVerifyAccountLimiter,validation(verifyOtpSchema),authService.verifyOtp);
router.post("/resend-otp",applyVerifyAccountLimiter,validation(resendOtpSchema), authService.resendOtp);
router.post("/login", applyLoginLimiter, validation(loginSchema), authService.login);
router.post("/refresh-token", authService.refreshToken);
router.post("/link-google",auth,validation(linkGoogleSchema),authService.linkGoogle);
router.post("/link-apple",auth,validation(linkAppleSchema),authService.linkApple);
router.post("/google-login",validation(googleLoginSchema),authService.googleLogin);
router.post("/apple-login",validation(appleLoginSchema),authService.appleLogin);
router.patch("/update-password",auth,applyUpdatePasswordLimiter,validation(updatePasswordSchema),authService.updatePassword);
router.post("/forget-password",applyForgetPasswordLimiter,validation(forgetPasswordSchema),authService.forgetPassword);
router.patch("/change-password",applyUpdatePasswordLimiter,validation(changePasswordSchema),authService.changePassword);
router.patch("/change-phone",applyChangeAccountLimiter,validation(changePhoneSchema),authService.changePhone);
router.post("/logout", auth, authService.logout);
router.get("/available-vehicles", authService.availableVehicles);
router.post("/save-referral-code/:userId", validation(referralCodeSchema), authService.saveReferralCode);

export default router;
