import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import env from "@/config/env";

type Channel = "email" | "phone";

/**
 * Enforce the per-channel OTP request limit: a single email/phone can only
 * receive X OTPs within the last X days. The limits are configured separately
 * for email and phone via environment variables.
 *
 * Call this **before** generating/sending a new OTP.
 */
export async function enforceOtpRateLimit(
  channel: Channel,
  value: string,
): Promise<void> {
  const maxRequests =
    channel === "email"
      ? env.OTP_EMAIL_MAX_REQUESTS
      : env.OTP_PHONE_MAX_REQUESTS;

  const windowDays =
    channel === "email"
      ? env.OTP_EMAIL_WINDOW_DAYS
      : env.OTP_PHONE_WINDOW_DAYS;

  const windowStart = new Date(
    Date.now() - windowDays * 24 * 60 * 60 * 1000,
  );

  const where =
    channel === "email"
      ? { email: value, created_at: { gte: windowStart } }
      : { phone: value, created_at: { gte: windowStart } };

  const count = await prisma.userVerify.count({ where });

  if (count >= maxRequests) {
    throw new HttpError(429, "auth:errors.otp_rate_limit", "OTP_RATE_LIMIT", {
      maxRequests,
      windowDays,
    });
  }
}
