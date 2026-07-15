import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(process.cwd(), ".env") });

/**
 * Centralized environment configuration.
 * All env variables are accessed through this object — never directly via process.env.
 * This makes it easy to validate, type-check, and mock configuration in tests.
 */
export const env = {
  // ====================== bootstrap.js ======================
  NODE_ENV: process.env["NODE_ENV"] ?? "development",
  PORT: parseInt(process.env["PORT"] ?? "3000", 10),
  BASE_URL: process.env["BASE_URL"] ?? "http://localhost:3000",

  get isDevelopment() {
    return this.NODE_ENV === "development";
  },
  get isProduction() {
    return this.NODE_ENV === "production";
  },
  get isTest() {
    return this.NODE_ENV === "test";
  },

  // ====================== logger.config.ts ======================
  LOG_LEVEL: process.env["LOG_LEVEL"] ?? "info",

  // ====================== prisma.config.ts & prisma.ts ======================
  DATABASE_URL: process.env["DATABASE_URL"] ?? "",
  DATABASE_HOST: process.env["DATABASE_HOST"] ?? "",
  DATABASE_USER: process.env["DATABASE_USER"] ?? "",
  DATABASE_PASSWORD: process.env["DATABASE_PASSWORD"] ?? "",
  DATABASE_NAME: process.env["DATABASE_NAME"] ?? "",
  DATABASE_PORT: parseInt(process.env["DATABASE_PORT"] ?? "3306", 10),

  // ====================== bcrypt.js ======================
  SALAT: parseInt(process.env["SALAT"] ?? "10", 10),

  // ====================== crypto.js ======================
  PRIVATE_KEY: process.env["PRIVATE_KEY"] ?? "",

  // ====================== sendEmail.js ======================
  HOST_EMAIL: process.env["HOST_EMAIL"] ?? "",
  SENDER_EMAIL: process.env["SENDER_EMAIL"] ?? "",
  GOOGLE_APP_PASSWORD: process.env["GOOGLE_APP_PASSWORD"] ?? "",

  // ====================== decodeToken.js ======================
  BEARER_KEY: process.env["BEARER_KEY"] ?? "Bearer",
  ACCESS_SEGNATURE: process.env["ACCESS_SEGNATURE"] ?? "",
  REFRESH_SEGNATURE: process.env["REFRESH_SEGNATURE"] ?? "",

  // ====================== uploadImage.ts ======================
  UPLOAD_IMAGE_BASE_URL: process.env["UPLOAD_IMAGE_BASE_URL"] ?? "",

  // ====================== auth.service.ts ======================
  GOOGLE_WEB_CLIENT_ID: process.env["GOOGLE_WEB_CLIENT_ID"] ?? "",
  GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID:
    process.env["GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID"] ?? "",
  GOOGLE_FLUTTER_COURIER_CLIENT_ID:
    process.env["GOOGLE_FLUTTER_COURIER_CLIENT_ID"] ?? "",
  GOOGLE_CLIENT_SECRET: process.env["GOOGLE_CLIENT_SECRET"] ?? "",
  GOOGLE_WEB_TESTING_CLIENT_ID:
    process.env["GOOGLE_WEB_TESTING_CLIENT_ID"] ?? "",

  // ====================== paymob.service.ts ======================
  PAYMOB_API_KEY: process.env["PAYMOB_API_KEY"] ?? "",
  PAYMOB_SECRET_KEY: process.env["PAYMOB_SECRET_KEY"] ?? "",
  PAYMOB_PUBLIC_KEY: process.env["PAYMOB_PUBLIC_KEY"] ?? "",
  PAYMOB_INTEGRATION_ID: process.env["PAYMOB_INTEGRATION_ID"] ?? "0",
  PAYMOB_HMAC_SECRET: process.env["PAYMOB_HMAC_SECRET"] ?? "",
  PAYMOB_BASE_URL:
    process.env["PAYMOB_BASE_URL"] ?? "https://accept.paymob.com",
  PAYMOB_NOTIFICATION_URL: process.env["PAYMOB_NOTIFICATION_URL"] ?? "",
  PAYMOB_REDIRECTION_URL: process.env["PAYMOB_REDIRECTION_URL"] ?? "",
  PAYMOB_REDIRECTION_URL_SUCCESS_URL:
    process.env["PAYMOB_REDIRECTION_URL_SUCCESS_URL"] ?? "",
  PAYMOB_REDIRECTION_URL_FAILED_URL:
    process.env["PAYMOB_REDIRECTION_URL_FAILED_URL"] ?? "",
  PRODUCTION_PAYMOB_API_KEY: process.env["PRODUCTION_PAYMOB_API_KEY"] ?? "",
  PRODUCTION_PAYMOB_SECRET_KEY:
    process.env["PRODUCTION_PAYMOB_SECRET_KEY"] ?? "",
  PRODUCTION_PAYMOB_PUBLIC_KEY:
    process.env["PRODUCTION_PAYMOB_PUBLIC_KEY"] ?? "",
  PRODUCTION_PAYMOB_INTEGRATION_ID:
    process.env["PRODUCTION_PAYMOB_INTEGRATION_ID"] ?? "0",
  PRODUCTION_PAYMOB_HMAC_SECRET:
    process.env["PRODUCTION_PAYMOB_HMAC_SECRET"] ?? "",
  PRODUCTION_PAYMOB_BASE_URL:
    process.env["PRODUCTION_PAYMOB_BASE_URL"] ?? "https://accept.paymob.com",
  PRODUCTION_PAYMOB_NOTIFICATION_URL:
    process.env["PRODUCTION_PAYMOB_NOTIFICATION_URL"] ?? "",
  PRODUCTION_PAYMOB_REDIRECTION_URL:
    process.env["PRODUCTION_PAYMOB_REDIRECTION_URL"] ?? "",
  PRODUCTION_PAYMOB_REDIRECTION_URL_SUCCESS_URL:
    process.env["PRODUCTION_PAYMOB_REDIRECTION_URL_SUCCESS_URL"] ?? "",
  PRODUCTION_PAYMOB_REDIRECTION_URL_FAILED_URL:
    process.env["PRODUCTION_PAYMOB_REDIRECTION_URL_FAILED_URL"] ?? "",

  // ====================== firebase ======================
  FIREBASE_TYPE: process.env["FIREBASE_TYPE"] ?? "",
  FIREBASE_PROJECT_ID: process.env["FIREBASE_PROJECT_ID"] ?? "",
  FIREBASE_PRIVATE_KEY_ID: process.env["FIREBASE_PRIVATE_KEY_ID"] ?? "",
  FIREBASE_PRIVATE_KEY: process.env["FIREBASE_PRIVATE_KEY"] ?? "",
  FIREBASE_CLIENT_EMAIL: process.env["FIREBASE_CLIENT_EMAIL"] ?? "",
  FIREBASE_CLIENT_ID: process.env["FIREBASE_CLIENT_ID"] ?? "",
  FIREBASE_AUTH_URI: process.env["FIREBASE_AUTH_URI"] ?? "",
  FIREBASE_TOKEN_URI: process.env["FIREBASE_TOKEN_URI"] ?? "",
  FIREBASE_AUTH_PROVIDER_X509_CERT_URL:
    process.env["FIREBASE_AUTH_PROVIDER_X509_CERT_URL"] ?? "",
  FIREBASE_CLIENT_X509_CERT_URL:
    process.env["FIREBASE_CLIENT_X509_CERT_URL"] ?? "",
  FIREBASE_UNIVERSE_DOMAIN: process.env["FIREBASE_UNIVERSE_DOMAIN"] ?? "",

  // ======================  ======================
  GOOGLE_FLUTTER_COURIER_IOS_CLIENT_ID:
    process.env["GOOGLE_FLUTTER_COURIER_IOS_CLIENT_ID"] ?? "",

  // ====================== cloudinary.services.ts ======================
  APP_NAME: process.env["APP_NAME"] ?? "",
  CLOUD_NAME: process.env["CLOUD_NAME"] ?? "",
  API_KEY: process.env["API_KEY"] ?? "",
  API_SECRET: process.env["API_SECRET"] ?? "",
  CLOUDINARY_MAX_IMAGE_WIDTH: parseInt(
    process.env["CLOUDINARY_MAX_IMAGE_WIDTH"] ?? "2000",
    10,
  ),

  // ====================== upload.ts ======================
  MULTER_MAX_FILE_SIZE_MB: process.env["MAX_FILE_SIZE_MB"] ?? "5",

  // ======================  ======================
  ADMIN_API_BASE_URL: process.env["ADMIN_API_BASE_URL"] ?? "",

  // ====================== socketio.server.ts ======================
  ALLOWED_ORIGINS: process.env["ALLOWED_ORIGINS"] ?? "",

  // ====================== socketio.server.ts ======================
  ADMIN_JWT_SECRET: process.env["ADMIN_JWT_SECRET"] ?? "",

  // ======================  ======================
  REDIS_HOST: process.env["REDIS_HOST"] ?? "",
  REDIS_PORT: process.env["REDIS_PORT"] ?? 6379,
  REDIS_PASSWORD: process.env["REDIS_PASSWORD"] ?? "",

  // ====================== broadnet.ts ======================
  BROADNET_SMS_URL: process.env["BROADNET_SMS_URL"] ?? "",
  BROADNET_USERNAME: process.env["BROADNET_USERNAME"] ?? "",
  BROADNET_PASSWORD: process.env["BROADNET_PASSWORD"] ?? "",
  BROADNET_SENDER: process.env["BROADNET_SENDER"] ?? "",
  BROADNET_SMS_FORMAT: process.env["BROADNET_SMS_FORMAT"] ?? "",
} as const;
