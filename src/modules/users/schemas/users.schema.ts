import { zPhoneEG } from "@/schemas/phone";
import { z } from "zod";

export const extraPhonesSchema = z.preprocess((val) => {
  // form-data commonly sends it as a JSON string
  if (typeof val === "string") {
    try {
      return JSON.parse(val);
    } catch {
      return val;
    }
  }
  return val;
}, z.array(zPhoneEG).optional());

const GenderEnum = z.enum(["MALE", "FEMALE"]);
const LoginTypeEnum = z.enum(["LOCAL", "GOOGLE", "APPLE"]);
const LanguageEnum = z.enum(["AR", "EN"]);

const walletInputSchema = z
  .object({
    owner_type: z.enum(["CUSTOMER", "COURIER", "PLATFORM"]).optional(),
    balance: z.coerce.number().int().min(0).optional(),
    points: z.coerce.number().int().min(0).optional(),
    status: z.enum(["ACTIVE", "FROZEN"]).optional(),
  })
  .optional();

export const createUserSchema = z.object({
  full_name: z
    .string()
    .min(2, "users:errors.full_name_min")
    .max(100, "users:errors.full_name_max"),
  email: z.email("users:errors.email_invalid").optional(),
  phone: zPhoneEG,
  extra_phones: extraPhonesSchema,
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(100, "Password must not exceed 100 characters")
    .regex(/[A-Z]/, "Requires uppercase")
    .regex(/[a-z]/, "Requires lowercase")
    .regex(/[0-9]/, "Requires number"),
  gender: GenderEnum.optional(),
  role_id: z.coerce.number().int().positive("users:errors.role_id_invalid"),
  badge_id: z.coerce
    .number()
    .int()
    .positive("users:errors.badge_id_invalid")
    .optional()
    .nullable(),

  is_active: z.coerce.boolean().optional(),
  is_email_verified: z.coerce.boolean().optional(),
  is_phone_verified: z.coerce.boolean().optional(),
  fcm_token: z.string().max(255).optional().nullable(),
  lang: LanguageEnum.default("EN"),
  google_id: z.string().max(100).optional().nullable(),
  apple_id: z.string().max(100).optional().nullable(),
  last_login_at: z.coerce.date().optional().nullable(),
  login_type: LoginTypeEnum.default("LOCAL"), // can be set by admin
  password_last_updated: z.coerce.date().optional().nullable(),
  deleted_at: z.coerce.date().optional().nullable(),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;

export const updateUserSchema = createUserSchema
  .extend({
    deleteImage: z.coerce.boolean().optional(),
    wallet: walletInputSchema,
  })
  .partial();

export type UpdateUserInput = z.infer<typeof updateUserSchema>;

export const userIdParamSchema = z.object({
  id: z.coerce.number().int().positive("users:errors.user_id_invalid"),
});

export const deleteUsersSchema = z.object({
  ids: z
    .array(z.coerce.number().int().positive("users:errors.user_id_invalid"))
    .min(1, "users:errors.ids_min_1"),
  archived: z.boolean().optional().default(false),
});

export type DeleteUsersInput = z.infer<typeof deleteUsersSchema>;

export const deleteUserSchema = z.object({
  id: z.coerce
    .number()
    .int()
    .positive("users:errors.user_id_invalid")
    .min(1, "users:errors.id_min_1"),
  archived: z.boolean().optional().default(true),
});

export type DeleteUserInput = z.infer<typeof deleteUserSchema>;

export const listUsersQuerySchema = z.object({
  skip: z.coerce.number().int().min(0, "users:errors.skip_min_0").optional(),
  take: z.coerce
    .number()
    .int()
    .min(1, "users:errors.take_min_1")
    .max(100, "users:errors.take_max_100")
    .optional(),
  keyword: z.string().optional(),
  is_active: z
    .union([z.literal("true"), z.literal("false")])
    .optional()
    .transform((v) => (v === undefined ? undefined : v === "true")),
  role_id: z.coerce
    .number()
    .int()
    .positive("users:errors.role_id_invalid")
    .optional(),
  badge_id: z.coerce
    .number()
    .int()
    .positive("users:errors.badge_id_invalid")
    .optional(),
});

export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;
