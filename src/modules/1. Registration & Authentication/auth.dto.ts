import z from "zod";
import {
  appleLoginSchema,
  appleRegisterSchema,
  changePasswordSchema,
  changePhoneSchema,
  forgetPasswordSchema,
  googleLoginSchema,
  googleRegisterSchema,
  linkAppleSchema,
  linkGoogleSchema,
  loginSchema,
  referralCodeSchema,
  registerSchema,
  resendOtpSchema,
  updatePasswordSchema,
  verifyOtpSchema,
} from "./auth.validation";

export type registerDTO = z.infer<typeof registerSchema>;
export type verifyPhonDTO = z.infer<typeof verifyOtpSchema>;
export type resendOtpDTO = z.infer<typeof resendOtpSchema>;
export type loginDTO = z.infer<typeof loginSchema>;
export type updatePasswordDTO = z.infer<typeof updatePasswordSchema>;
export type forgetPasswordDTO = z.infer<typeof forgetPasswordSchema>;
export type changePasswordDTO = z.infer<typeof changePasswordSchema>;
export type changePhoneDTO = z.infer<typeof changePhoneSchema>;
export type googleLoginDTO = z.infer<typeof googleLoginSchema>;
export type appleLoginDTO = z.infer<typeof appleLoginSchema>;
export type linkGoogleDTO = z.infer<typeof linkGoogleSchema>;
export type linkAppleDTO = z.infer<typeof linkAppleSchema>;
export type googleRegisterDTO = z.infer<typeof googleRegisterSchema>;
export type appleRegisterDTO = z.infer<typeof appleRegisterSchema>;
export type referralCodeDTO = z.infer<typeof referralCodeSchema>;
