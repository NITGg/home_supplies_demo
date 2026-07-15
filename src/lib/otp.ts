import { prisma } from "@/config/prisma";

export function generateOtp(length = 6) {
  let out = "";
  for (let i = 0; i < length; i++) out += Math.floor(Math.random() * 10);
  return out;
}

export function isExpired(createdAt: Date, minutes: number) {
  const diffMs = Date.now() - createdAt.getTime();
  return diffMs > minutes * 60 * 1000;
}

export function generateReferralCode(length = 8) {
  let out = "";
  for (let i = 0; i < length; i++) {
    const char = Math.floor(Math.random() * 36);
    out += char.toString(36);
  }
  return out;
}

/**
 * Admin-configurable OTP settings (ApplicationSetting), with fallbacks
 * matching the schema defaults.
 */
export async function getOtpSettings() {
  const settings = await prisma.applicationSetting.findFirst({
    select: {
      otp_length: true,
      otp_resend_duration_seconds: true,
      otp_validity_duration_minutes: true,
    },
  });

  return {
    otpLength: settings?.otp_length ?? 6,
    resendCooldownSeconds: settings?.otp_resend_duration_seconds ?? 60,
    validityMinutes: settings?.otp_validity_duration_minutes ?? 5,
  };
}
