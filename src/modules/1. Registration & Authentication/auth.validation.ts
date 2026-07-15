import z from "zod";
import { GenderEnum } from "../../core/types/global.types";
import { VerifyType } from "@prisma/client";

// ============================ phone normalization ============================
// Normalizes any reasonable Egyptian phone input to international format: +20XXXXXXXXXX
// Accepts e.g. "01012345678", "1012345678", "0020 101 234 5678", "+20-101-234-5678".
const normalizeEgyptianPhone = (value: string): string => {
  // keep digits only (drops "+", spaces, dashes, parentheses, dots, etc.)
  let digits = value.replace(/\D/g, "");

  if (digits.startsWith("0020")) {
    digits = digits.slice(4); // 0020 1X... -> 1X...
  } else if (digits.startsWith("20")) {
    digits = digits.slice(2); // 20 1X...   -> 1X...
  } else if (digits.startsWith("0")) {
    digits = digits.slice(1); // 01X...     -> 1X...
  }

  return "+20" + digits;
};

// Reusable Egyptian phone schema: normalizes first, then validates the +20 national
// format (10 national digits, e.g. +201012345678).
const egPhone = z
  .string()
  .transform((val) => normalizeEgyptianPhone(val))
  .refine((val) => /^\+20\d{10}$/.test(val), {
    message: "Phone number is incorrect",
  });

export const registerSchema = z.object({
  full_name: z.string().min(3).max(50),
  phone: egPhone,
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
  gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
  vehicle_id: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number),
  vehicle_plate: z.string().optional(),
  national_id_number: z
    .string()
    .regex(/^\d{14}$/, "National ID must be exactly 14 digits"),
});

export const verifyOtpSchema = z
  .object({
    phone: egPhone,
    user_otp: z.string().min(1, "OTP is required"),
    second_phone: egPhone.optional(),
    second_user_otp: z.string().min(1, "OTP is required").optional(),
    new_password: z
      .string()
      .min(8, "Password must be at least 8 characters")
      .max(100, "Password must not exceed 100 characters")
      .regex(/[A-Z]/, "Requires uppercase")
      .regex(/[a-z]/, "Requires lowercase")
      .regex(/[0-9]/, "Requires number")
      .optional(),
    verify_type: z.enum([
      VerifyType.VERIFY,
      VerifyType.RESET_PASSWORD,
      VerifyType.FORGET_PASSWORD,
      VerifyType.CHANGE_EMAIL,
      VerifyType.CHANGE_PHONE,
    ]),
  })
  .superRefine((args, ctx) => {
    if (args.verify_type === VerifyType.CHANGE_PHONE) {
      if (!args.second_phone || !args.second_user_otp) {
        ctx.addIssue({
          code: "custom",
          path: ["second_phone"],
          message: "Second phone and OTP are required",
        });
      }
    }
    if (args.verify_type == VerifyType.FORGET_PASSWORD) {
      if (!args.new_password) {
        ctx.addIssue({
          code: "custom",
          path: ["new_password"],
          message: "New password is required",
        });
      }
    }
  });

export const resendOtpSchema = z
  .object({
    phone: egPhone,
    second_phone: egPhone.optional(),
    verify_type: z.enum([
      VerifyType.VERIFY,
      VerifyType.RESET_PASSWORD,
      VerifyType.FORGET_PASSWORD,
      VerifyType.CHANGE_EMAIL,
      VerifyType.CHANGE_PHONE,
    ]),
  })
  .superRefine((args, ctx) => {
    if (args.verify_type === VerifyType.CHANGE_PHONE) {
      if (!args.second_phone) {
        ctx.addIssue({
          code: "custom",
          path: ["second_phone"],
          message: "Second phone is required",
        });
      }
    }
  });

export const loginSchema = z.object({
  phone: egPhone,
  password: z.string(),
});

export const linkGoogleSchema = z.object({
  id_token: z.string().min(1, "Google ID token is required"),
});

export const linkAppleSchema = z.object({
  id_token: z.string().min(1, "Apple ID token is required"),
});

export const googleLoginSchema = z.object({
  id_token: z.string().min(1, "Google ID token is required"),
});

export const appleLoginSchema = z.object({
  id_token: z.string().min(1, "Apple ID token is required"),
});

export const forgetPasswordSchema = z.object({
  phone: egPhone,
});

export const changePasswordSchema = z.object({
  phone: egPhone,
  user_otp: z.string(),
  new_password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
});

export const changePhoneSchema = z.object({
  current_phone: egPhone,
  new_phone: egPhone,
});

export const updatePasswordSchema = z.object({
  current_password: z.string(),
  new_password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
});

export const googleRegisterSchema = z.object({
  id_token: z.string().min(1, "Google ID token is required"),
  full_name: z.string().min(3).max(50),
  phone: egPhone,
  gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
  vehicle_id: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number),
  vehicle_plate: z.string().optional(),
  national_id_number: z
    .string()
    .regex(/^\d{14}$/, "National ID must be exactly 14 digits"),
});

export const appleRegisterSchema = z.object({
  id_token: z.string().min(1, "Apple ID token is required"),
  full_name: z.string().min(3).max(50),
  phone: egPhone,
  gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
  vehicle_id: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .transform(Number),
  vehicle_plate: z.string().optional(),
  national_id_number: z
    .string()
    .regex(/^\d{14}$/, "National ID must be exactly 14 digits"),
});

export const referralCodeSchema = z.object({
  referral_code: z.string(),
});
