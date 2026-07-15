import dotenv from "dotenv";

dotenv.config();

export const env = {
  // ====================== bootstrap.js ======================
  PORT: parseInt(process.env["PORT"] ?? "3004", 10),
  BASE_URL: process.env["BASE_URL"] ?? "http://localhost:3004",
  NODE_ENV: process.env["NODE_ENV"] ?? "development",

  get isDevelopment() {
    return this.NODE_ENV === "development";
  },
  get isProduction() {
    return this.NODE_ENV === "production";
  },
  get isTest() {
    return this.NODE_ENV === "test";
  },

  // ====================== prisma.config.ts & prisma.ts ======================
  DATABASE_URL: process.env["DATABASE_URL"] ?? "",
  DATABASE_HOST: process.env["DATABASE_HOST"] ?? "",
  DATABASE_USER: process.env["DATABASE_USER"] ?? "",
  DATABASE_PASSWORD: process.env["DATABASE_PASSWORD"] ?? "",
  DATABASE_NAME: process.env["DATABASE_NAME"] ?? "",
  DATABASE_PORT: process.env["DATABASE_PORT"] ?? "3306",

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
  // (NIT paymob test account)
  PAYMOB_API_KEY: process.env["PAYMOB_API_KEY"] ?? "",
  PAYMOB_SECRET_KEY: process.env["PAYMOB_SECRET_KEY"] ?? "",
  PAYMOB_PUBLIC_KEY: process.env["PAYMOB_PUBLIC_KEY"] ?? "",
  PAYMOB_INTEGRATION_ID: process.env["PAYMOB_INTEGRATION_ID"] ?? "0",
  PAYMOB_HMAC_SECRET: process.env["PAYMOB_HMAC_SECRET"] ?? "",
  PAYMOB_BASE_URL: process.env["PAYMOB_BASE_URL"] ?? "",
  PAYMOB_NOTIFICATION_URL: process.env["PAYMOB_NOTIFICATION_URL"] ?? "",
  PAYMOB_REDIRECTION_URL: process.env["PAYMOB_REDIRECTION_URL"] ?? "",
  PAYMOB_REDIRECTION_URL_SUCCESS_URL:
    process.env["PAYMOB_REDIRECTION_URL_SUCCESS_URL"] ?? "",
  PAYMOB_REDIRECTION_URL_FAILED_URL:
    process.env["PAYMOB_REDIRECTION_URL_FAILED_URL"] ?? "",
  // (NIT paymob production account)
  PRODUCTION_PAYMOB_API_KEY: process.env["PRODUCTION_PAYMOB_API_KEY"] ?? "",
  PRODUCTION_PAYMOB_SECRET_KEY:
    process.env["PRODUCTION_PAYMOB_SECRET_KEY"] ?? "",
  PRODUCTION_PAYMOB_PUBLIC_KEY:
    process.env["PRODUCTION_PAYMOB_PUBLIC_KEY"] ?? "",
  PRODUCTION_PAYMOB_INTEGRATION_ID:
    process.env["PRODUCTION_PAYMOB_INTEGRATION_ID"] ?? "0",
  PRODUCTION_PAYMOB_HMAC_SECRET:
    process.env["PRODUCTION_PAYMOB_HMAC_SECRET"] ?? "",
  PRODUCTION_PAYMOB_BASE_URL: process.env["PRODUCTION_PAYMOB_BASE_URL"] ?? "",
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
  FIREBASE_PRIVATE_KEY:
    process.env["FIREBASE_PRIVATE_KEY"]?.replace(/\\n/g, "\n") ?? "",
  FIREBASE_CLIENT_EMAIL: process.env["FIREBASE_CLIENT_EMAIL"] ?? "",
  FIREBASE_CLIENT_ID: process.env["FIREBASE_CLIENT_ID"] ?? "",
  FIREBASE_AUTH_URI: process.env["FIREBASE_AUTH_URI"] ?? "",
  FIREBASE_TOKEN_URI: process.env["FIREBASE_TOKEN_URI"] ?? "",
  FIREBASE_AUTH_PROVIDER_X509_CERT_URL:
    process.env["FIREBASE_AUTH_PROVIDER_X509_CERT_URL"] ?? "",
  FIREBASE_CLIENT_X509_CERT_URL:
    process.env["FIREBASE_CLIENT_X509_CERT_URL"] ?? "",
  FIREBASE__UNIVERSE_DOMAIN: process.env["FIREBASE__UNIVERSE_DOMAIN"] ?? "",

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

  // ====================== socketio.server.ts ======================
  ALLOWED_ORIGINS: process.env["ALLOWED_ORIGINS"] ?? "",
} as const;
