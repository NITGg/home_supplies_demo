import z from "zod";
import { GenderEnum } from "../../types/global.types";

export const registerSchema = z
  .object({
    // user fields
    full_name: z.string().min(3).max(50),
    phone: z.string(),
    password: z
      .string()
      .min(8, "Password must be at least 8 characters")
      .max(100, "Password must not exceed 100 characters")
      .regex(/[A-Z]/, "Requires uppercase")
      .regex(/[a-z]/, "Requires lowercase")
      .regex(/[0-9]/, "Requires number"),
    gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
    language: z.enum(["AR", "EN"]).optional(),
    // supplier fields
    type_id: z.coerce.number().optional(),
    national_id_number: z
      .string()
      .regex(/^\d{14}$/, "National ID must be exactly 14 digits"),
    synonyms: z.string().optional(),
    tax_card: z.string(),
    commercial_register: z.string(),
    // SupplierStoreAddress fields
    area_id: z.coerce.number().optional(),
    address_line_1: z.string().optional(),
    address_line_2: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    country: z.string().optional(),
    google_map_link: z.string().optional(),
    latitude: z.string().optional(),
    longitude: z.string().optional(),
    contact_name: z.string().optional(),
    contact_phone: z.string().optional(),
    working_hours: z.any().optional(),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
  });

export const googleRegisterSchema = z
  .object({
    id_token: z.string().min(1, "Google ID token is required"),
    // user fields
    phone: z.string(),
    gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
    language: z.enum(["AR", "EN"]).optional(),
    // supplier fields
    type_id: z.coerce.number().optional(),
    national_id_number: z
      .string()
      .regex(/^\d{14}$/, "National ID must be exactly 14 digits"),
    synonyms: z.string().optional(),
    tax_card: z.string(),
    commercial_register: z.string(),
    // SupplierStoreAddress fields
    area_id: z.coerce.number().optional(),
    address_line_1: z.string().optional(),
    address_line_2: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    country: z.string().optional(),
    google_map_link: z.string().optional(),
    latitude: z.string().optional(),
    longitude: z.string().optional(),
    contact_name: z.string().optional(),
    contact_phone: z.string().optional(),
    working_hours: z.any().optional(),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
  });

export const appleRegisterSchema = z
  .object({
    id_token: z.string().min(1, "Apple ID token is required"),
    // user fields
    phone: z.string(),
    gender: z.literal([GenderEnum.MALE, GenderEnum.FEMALE]).optional(),
    language: z.enum(["AR", "EN"]).optional(),
    // supplier fields
    type_id: z.coerce.number().optional(),
    national_id_number: z
      .string()
      .regex(/^\d{14}$/, "National ID must be exactly 14 digits"),
    synonyms: z.string().optional(),
    tax_card: z.string(),
    commercial_register: z.string(),
    // SupplierStoreAddress fields
    area_id: z.coerce.number().optional(),
    address_line_1: z.string().optional(),
    address_line_2: z.string().optional(),
    city: z.string().optional(),
    state: z.string().optional(),
    country: z.string().optional(),
    google_map_link: z.string().optional(),
    latitude: z.string().optional(),
    longitude: z.string().optional(),
    contact_name: z.string().optional(),
    contact_phone: z.string().optional(),
    working_hours: z.any().optional(),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
  });

export const verifyPhoneSchema = z
  .object({
    phone: z.string(),
    user_otp: z.string().min(1, "OTP is required"),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
  });

export const resendPhoneOTPSchema = z
  .object({
    phone: z.string(),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
  });

export const loginSchema = z
  .object({
    phone: z.string(),
    password: z.string(),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
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

export const forgetPasswordSchema = z
  .object({
    phone: z.string(),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
  });

export const changePasswordSchema = z
  .object({
    phone: z.string(),
    user_otp: z.string(),
    new_password: z
      .string()
      .min(8, "Password must be at least 8 characters")
      .max(100, "Password must not exceed 100 characters")
      .regex(/[A-Z]/, "Requires uppercase")
      .regex(/[a-z]/, "Requires lowercase")
      .regex(/[0-9]/, "Requires number"),
  })
  .superRefine((args, ctx) => {
    if (args.phone) {
      const clean = args.phone.replace(/[\s-]/g, "");
      const phoneRegex = /^\+?[1-9]\d{7,14}$/;
      if (!phoneRegex.test(clean)) {
        ctx.addIssue({
          code: "custom",
          path: ["phone"],
          message: "Phone number is incorrect",
        });
      }
    }
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

export const referralCodeSchema = z.object({
  referral_code: z.string(),
});
