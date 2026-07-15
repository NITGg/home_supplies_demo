import "dotenv/config";
import { z } from "zod";

const EnvSchema = z.object({
  PORT: z.coerce.number().default(3100),
  PROD: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
  DATABASE_URL: z.string().min(1),
  DATABASE_HOST: z.string().min(1),
  DATABASE_USER: z.string().min(1),
  DATABASE_PORT: z.coerce.number().default(3306),
  DATABASE_PASSWORD: z.string().min(1),
  DATABASE_NAME: z.string().min(1),

  // apple config
  AUTH_APPLE_CLIENT_ID: z.string().min(1),
  GOOGLE_WEB_CLIENT_ID: z.string().min(1),
  GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID: z.string().min(1),
  GOOGLE_FLUTTER_COURIER_CLIENT_ID: z.string().min(1),
  GOOGLE_FLUTTER_CUSTOMER_PROD_CLIENT_ID: z.string().min(1),
  GOOGLE_FLUTTER_COURIER_PROD_CLIENT_ID: z.string().min(1),
  GOOGLE_FLUTTER_CUSTOMER_IOS_CLIENT_ID: z.string().min(1),
  GOOGLE_FLUTTER_COURIER_IOS_CLIENT_ID: z.string().min(1),

  JWT_SECRET: z.string().min(10, "JWT_SECRET should be at least 10 chars"),
  JWT_EXPIRES_IN: z.string().default("7d"), // we'll cast in jwt.ts to the right type

  // nodemailer config
  MAIL_HOST: z.string().min(1),
  MAIL_PORT: z.coerce.number().default(587),
  MAIL_USER: z.string().min(1),
  MAIL_PASS: z.string().min(1),
  MAIL_FROM: z.string().optional(),

  // broadnet sms gateway
  BROADNET_SMS_URL: z
    .string()
    .default("https://gwe2s.broadnet.me:8443/websmpp/json/sms"),
  BROADNET_USERNAME: z.string().optional(),
  BROADNET_PASSWORD: z.string().optional(),
  BROADNET_SENDER: z.string().default("Tawreedat Go"),
  BROADNET_SMS_FORMAT: z.string().default("1"),
  // NOTE: SMS `type` (Latin vs Unicode) is derived per-message from the user's
  // language in src/lib/sms/broadnet.ts — it is intentionally not an env var.

  // paymob
  PAYMOB_API_KEY: z.string().min(1),
  PAYMOB_SECRET_KEY: z.string().min(1),
  PAYMOB_PUBLIC_KEY: z.string().min(1),
  PAYMOB_BASE_URL: z.string().min(1),
  PAYMOB_PAYMENT_METHODS: z.coerce.number(),
  PAYMOB_HMAC_SECRET: z.string().min(1),

  // easykash
  EASYKASH_API_KEY: z.string().optional().default(""),
  EASYKASH_HMAC_SECRET: z.string().optional().default(""),
  EASYKASH_BASE_URL: z.string().optional().default("https://back.easykash.net"),

  // kashier
  KASHIER_API_KEY: z.string().min(1).optional().default(""),
  KASHIER_SECRET_KEY: z.string().min(1).optional().default(""),
  KASHIER_MERCHANT_ID: z.string().min(1).optional().default(""),
  KASHIER_BASE_URL: z.string().optional().default("https://api.kashier.io"),
  KASHIER_REFUND_BASE_URL: z
    .string()
    .optional()
    .default("https://fep.kashier.io"),

  // firebase
  FIREBASE_TYPE: z.string().min(1),
  FIREBASE_PROJECT_ID: z.string().min(1),
  FIREBASE_PRIVATE_KEY_ID: z.string().min(1),
  FIREBASE_PRIVATE_KEY: z.string().min(1),
  FIREBASE_CLIENT_EMAIL: z.string().min(1),
  FIREBASE_CLIENT_ID: z.string().min(1),
  FIREBASE_AUTH_URI: z.string().min(1),
  FIREBASE_TOKEN_URI: z.string().min(1),
  FIREBASE_AUTH_PROVIDER_X509_CERT_URL: z.string().min(1),
  FIREBASE_CLIENT_X509_CERT_URL: z.string().min(1),
  FIREBASE__UNIVERSE_DOMAIN: z.string().min(1),
  GOOGLE_MAPS_API_KEY: z.string().min(1),
  DASHBOARD_URL: z.string().optional(),
  UPLOAD_IMAGE_BASE_URL: z.string().min(1),
  ALLOWED_ORIGINS: z.string().min(1),
  RATE_LIMIT_WINDOW_MINUTES: z.coerce.number().positive().default(15),
  RATE_LIMIT_MAX_REQUESTS: z.coerce.number().positive().default(9999),
  EXTERNAL_APP_JWT_SECRET: z
    .string()
    .min(10, "EXTERNAL_APP_JWT_SECRET should be at least 10 chars"),
  REDIS_HOST: z.string().min(1),
  REDIS_PORT: z.coerce.number().default(6379),
  REDIS_PASSWORD: z.string().min(16),

  // OTP rate-limiting per channel (separate for email and phone)
  OTP_EMAIL_MAX_REQUESTS: z.coerce.number().positive().default(5),
  OTP_EMAIL_WINDOW_DAYS: z.coerce.number().positive().default(1),
  OTP_PHONE_MAX_REQUESTS: z.coerce.number().positive().default(5),
  OTP_PHONE_WINDOW_DAYS: z.coerce.number().positive().default(1),

  APP_NAME: z.string().min(1),
  CLOUD_NAME: z.string().min(1),
  API_KEY: z.string().min(1),
  API_SECRET: z.string().min(1),
  CLOUDINARY_MAX_IMAGE_WIDTH: z.coerce.number().positive().default(2000),
});

const parsed = EnvSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("❌ Invalid environment variables:");
  console.error(
    parsed.error.issues.map((i) => ({
      path: i.path.join("."),
      message: i.message,
    })),
  );

  throw new Error("Invalid environment variables");
}

export default parsed.data;
