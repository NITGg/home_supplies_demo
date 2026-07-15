import { zPhoneEG } from "@/schemas/phone";
import { z } from "zod";

const GenderEnum = z.enum(["MALE", "FEMALE"]);
const LanguageEnum = z.enum(["AR", "EN"]);

export const updateProfileSchema = z
  .object({
    full_name: z
      .string()
      .min(2, "users:errors.full_name_min")
      .max(100, "users:errors.full_name_max")
      .optional(),
    lang: LanguageEnum.optional(),
    gender: GenderEnum.optional(),

    // only for update to delete current photo
    deleteImage: z.coerce.boolean().optional(),
  })
  .partial();

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;

export const updateFcmSchema = z.object({
  fcmToken: z.string().min(1, "common:errors.fcm_required"),
});
export type UpdateFcmInput = z.infer<typeof updateFcmSchema>;

export const changeEmailSchema = z.object({
  email: z.email("users:errors.email_invalid"),
});
export type ChangeEmailInput = z.infer<typeof changeEmailSchema>;

export const changePhoneSchema = z.object({
  phone: zPhoneEG,
});
export type ChangePhoneInput = z.infer<typeof changePhoneSchema>;

export const confirmOtpSchema = z.object({
  code: z.string().min(1, "auth:errors.code_required"),
});
export type ConfirmOtpInput = z.infer<typeof confirmOtpSchema>;

export const changePasswordSchema = z.object({
  oldPassword: z.string().min(1, "profile:errors.old_password_required"),
  newPassword: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
});
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
