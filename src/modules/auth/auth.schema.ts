import { zPhoneEG } from "@/schemas/phone";
import { z } from "zod";

export const registerSchema = z
  .object({
    full_name: z
      .string()
      .min(2, "auth:errors.full_name_min")
      .max(100, "auth:errors.full_name_max"),
    email: z.email("auth:errors.email_invalid").optional(),
    phone: zPhoneEG.optional(),
    password: z
      .string()
      .min(8, "Password must be at least 8 characters")
      .max(100, "Password must not exceed 100 characters")
      .regex(/[A-Z]/, "Requires uppercase")
      .regex(/[a-z]/, "Requires lowercase")
      .regex(/[0-9]/, "Requires number"),
    gender: z.enum(["MALE", "FEMALE"]).optional(),
    role_id: z.coerce.number().int().positive().min(1).optional(),
    badge_id: z.coerce.number().int().positive().min(1).optional(),
  })
  .refine((data) => data.email || data.phone, {
    message: "auth:errors.email_or_phone_required",
    path: ["email"],
  });

export type RegisterFormData = z.infer<typeof registerSchema>;

export const loginSchema = z.union([
  z.object({
    email: z.email("auth:errors.email_invalid"),
    password: z.string(),
  }),
  z.object({
    phone: zPhoneEG,
    password: z.string(),
  }),
]);

export type LoginFormData = z.infer<typeof loginSchema>;

export const appleVerifySchema = z.object({
  idToken: z.string().min(1, "auth:errors.apple_token_missing"),
  full_name: z
    .string()
    .min(2, "auth:errors.full_name_min")
    .max(100, "auth:errors.full_name_max")
    .optional(),
  nonce: z.string().min(1, "auth:errors.apple_nonce_missing").optional(),
  role_id: z.coerce.number().int().positive().min(1).optional(),
  badge_id: z.coerce.number().int().positive().min(1).optional(),
});

export type AppleVerifyInput = z.infer<typeof appleVerifySchema>;

export const googleVerifySchema = z.object({
  idToken: z.string().min(1, "auth:errors.google_token_missing"),
  role_id: z.coerce.number().int().positive().min(1).optional(),
  badge_id: z.coerce.number().int().positive().min(1).optional(),
});

export type GoogleVerifyInput = z.infer<typeof googleVerifySchema>;

export const linkGoogleSchema = z.object({
  idToken: z.string().min(1, "auth:errors.google_token_missing"),
});

export type LinkGoogleInput = z.infer<typeof linkGoogleSchema>;

export const linkAppleSchema = z.object({
  idToken: z.string().min(1, "auth:errors.apple_token_missing"),
  nonce: z.string().min(1, "auth:errors.apple_nonce_missing").optional(),
});

export type LinkAppleInput = z.infer<typeof linkAppleSchema>;

/**
 * Public (tokenless) verification: request an OTP by email or phone.
 */
export const requestVerificationSchema = z
  .object({
    email: z.email("auth:errors.email_invalid").optional(),
    phone: zPhoneEG.optional(),
  })
  .refine((data) => data.email || data.phone, {
    message: "auth:errors.email_or_phone_required",
    path: ["email"],
  });

export type RequestVerificationInput = z.infer<
  typeof requestVerificationSchema
>;

/**
 * Public (tokenless) verification: confirm the OTP by email or phone + code.
 */
export const verifyAccountSchema = z
  .object({
    email: z.email("auth:errors.email_invalid").optional(),
    phone: zPhoneEG.optional(),
    code: z.string().min(1, "auth:errors.otp_code_required"),
  })
  .refine((data) => data.email || data.phone, {
    message: "auth:errors.email_or_phone_required",
    path: ["email"],
  });

export type VerifyAccountInput = z.infer<typeof verifyAccountSchema>;

/**
 * Forget password – accepts a raw identifier (email or phone) and an optional
 * channel hint. When the user has both channels and no hint is provided, email
 * is used by default.
 */
export const forgetPasswordSchema = z.object({
  identifier: z.string().min(1, "auth:errors.email_or_phone_required"),
  channel: z.enum(["email", "phone"]).optional(),
});

export type ForgetPasswordInput = z.infer<typeof forgetPasswordSchema>;

/**
 * Verify the forget-password OTP **and** set a new password in one step.
 */
export const verifyForgetPasswordSchema = z.object({
  identifier: z.string().min(1, "auth:errors.email_or_phone_required"),
  code: z
    .string()
    .min(3, "auth:errors.invalid_otp")
    .max(10, "auth:errors.invalid_otp"),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
});

export type VerifyForgetPasswordInput = z.infer<
  typeof verifyForgetPasswordSchema
>;

/**
 * Change password (authenticated — requires old password).
 */
export const changePasswordSchema = z.object({
  old_password: z.string().min(1, "auth:errors.password_min"),
  new_password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
});

export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;

/**
 * Request OTP to change phone or email – sends code to the NEW value.
 */
export const changePhoneEmailSchema = z.object({
  type: z.enum(["email", "phone"]),
  new_value: z.string().min(1, "auth:errors.email_or_phone_required"),
});

export type ChangePhoneEmailInput = z.infer<typeof changePhoneEmailSchema>;

/**
 * Verify the OTP for changing phone or email.
 */
export const verifyChangePhoneEmailSchema = z.object({
  old_code: z
    .string()
    .min(3, "auth:errors.otp_code_required")
    .max(10, "auth:errors.otp_code_required"),
  new_code: z
    .string()
    .min(3, "auth:errors.otp_code_required")
    .max(10, "auth:errors.otp_code_required"),
});

export type VerifyChangePhoneEmailInput = z.infer<
  typeof verifyChangePhoneEmailSchema
>;

export const tokenSchema = z.object({
  // grant_type: z.literal("client_credentials"),
  client_id: z.string(),
  client_secret: z.string(),
});
