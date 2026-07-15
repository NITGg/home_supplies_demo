import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { signAccessToken } from "@/lib/jwt";
import { generateOtp, getOtpSettings, isExpired } from "@/lib/otp";
import { buildVerificationEmail } from "@/lib/emails/verificationEmail";
import { sendEmail } from "@/lib/mailer";
import { buildVerificationSms } from "@/lib/sms/verificationSms";
import { sendSms } from "@/lib/sms/broadnet";
import { Lang } from "@/types/express";
import type { Language } from "@prisma/client";
import { enforceOtpRateLimit } from "./otpRateLimit.service";

type VerifyChannel = "email" | "phone";

type VerifyTarget = {
  id: number;
  email: string | null;
  phone: string | null;
  is_email_verified: boolean;
  is_phone_verified: boolean;
};

type OtpUser = VerifyTarget & {
  full_name: string;
  lang: Language;
};

const VERIFY_TARGET_SELECT = {
  id: true,
  email: true,
  phone: true,
  is_email_verified: true,
  is_phone_verified: true,
} as const;

const OTP_USER_SELECT = {
  ...VERIFY_TARGET_SELECT,
  full_name: true,
  lang: true,
} as const;

/**
 * Generate, persist and deliver an OTP (length from ApplicationSetting.otp_length)
 * for one channel. Rows are
 * channel-specific (an email OTP has phone=null and vice-versa) so the two
 * channels never clash, and a per-channel cooldown blocks rapid re-sends.
 */
async function issueVerificationOtp(
  user: OtpUser,
  channel: VerifyChannel,
  lang: Lang,
) {
  if (channel === "email" && user.is_email_verified)
    throw new HttpError(403, "auth:errors.already_verified");
  if (channel === "phone" && user.is_phone_verified)
    throw new HttpError(403, "auth:errors.already_verified");

  const channelValue = channel === "email" ? user.email! : user.phone!;

  // Per-channel rate limit (X requests per phone/email in X days)
  await enforceOtpRateLimit(channel, channelValue);

  const { otpLength, resendCooldownSeconds } = await getOtpSettings();

  const channelWhere =
    channel === "email"
      ? { user_id: user.id, type: "VERIFY" as const, email: user.email! }
      : { user_id: user.id, type: "VERIFY" as const, phone: user.phone! };

  // Anti-spam: refuse a new send while the previous code is still within the
  // admin-configurable resend cooldown, so the endpoint can't be hammered to
  // flood email/SMS.
  const last = await prisma.userVerify.findFirst({
    where: channelWhere,
    orderBy: { created_at: "desc" },
    select: { created_at: true },
  });
  if (last) {
    const elapsed = (Date.now() - last.created_at.getTime()) / 1000;
    if (elapsed < resendCooldownSeconds) {
      const retryAfter = Math.ceil(resendCooldownSeconds - elapsed);
      throw new HttpError(429, "auth:errors.otp_cooldown", "OTP_COOLDOWN", {
        retryAfter,
      });
    }
  }

  const code = generateOtp(otpLength);

  // replace any previous code for THIS channel only
  await prisma.userVerify.deleteMany({ where: channelWhere });

  await prisma.userVerify.create({
    data: {
      code,
      user_id: user.id,
      type: "VERIFY",
      email: channel === "email" ? user.email : null,
      phone: channel === "phone" ? user.phone : null,
    },
  });

  if (channel === "email") {
    const { subject, text, html } = buildVerificationEmail({
      name: user.full_name,
      code,
      lang,
    });
    await sendEmail({ to: user.email!, subject, text, html });
    return { via: "email" as const };
  }

  // SMS encoding follows the user's stored language (User.lang), so the text
  // and the Broadnet `type` (Latin vs Unicode) stay consistent.
  const smsLang: Lang = user.lang === "AR" ? "ar" : "en";
  const { text } = buildVerificationSms({ code, lang: smsLang });
  // TODO: un comment this line after Broadnet work
  // await sendSms({ to: user.phone!, text, lang: smsLang });
  return { via: "phone" as const };
}

/**
 * Validate a submitted code for one channel and flip the matching verified
 * flag.
 */
async function applyOtpVerification(
  user: VerifyTarget,
  channel: VerifyChannel,
  code: string,
) {
  // already verified for that channel
  if (channel === "email" && user.is_email_verified)
    return { verified: true, via: "email" as const };
  if (channel === "phone" && user.is_phone_verified)
    return { verified: true, via: "phone" as const };

  const record = await prisma.userVerify.findFirst({
    where:
      channel === "email"
        ? { code, email: user.email!, type: "VERIFY" }
        : { code, phone: user.phone!, type: "VERIFY" },
  });

  if (!record) throw new HttpError(400, "auth:errors.otp_invalid");

  const { validityMinutes } = await getOtpSettings();
  if (isExpired(record.created_at, validityMinutes)) {
    await prisma.userVerify.delete({ where: { id: record.id } });
    throw new HttpError(400, "auth:errors.otp_expired");
  }

  // Delete only this channel's OTP — the other channel's code (if any) survives.
  await prisma.userVerify.delete({ where: { id: record.id } });

  await prisma.user.update({
    where: { id: user.id },
    data:
      channel === "email"
        ? { is_email_verified: true }
        : { is_phone_verified: true },
  });

  return { verified: true, via: channel };
}

/**
 * Public: request an OTP by email or phone (the only verification entry point,
 * since registration no longer hands out a token).
 */
export async function requestVerificationOtp(input: {
  email?: string;
  phone?: string;
  lang: Lang;
}) {
  if (!input.email && !input.phone)
    throw new HttpError(400, "auth:errors.email_or_phone_required");

  const user = await prisma.user.findFirst({
    where: input.email ? { email: input.email } : { phone: input.phone },
    select: OTP_USER_SELECT,
  });

  if (!user) throw new HttpError(404, "auth:errors.user_not_found");

  // Verify the channel matching the identifier the caller supplied.
  const channel: VerifyChannel = input.email ? "email" : "phone";
  return issueVerificationOtp(user, channel, input.lang);
}

/**
 * Public: confirm an OTP by email/phone + code. Once every channel the account
 * actually has is verified, a session token is returned so the user is logged
 * in immediately (no separate /login call needed). If another channel is still
 * unverified, no token is issued and the remaining channel(s) are reported.
 */
export async function confirmVerification(input: {
  email?: string;
  phone?: string;
  code: string;
}) {
  if (!input.email && !input.phone)
    throw new HttpError(400, "auth:errors.email_or_phone_required");

  const user = await prisma.user.findFirst({
    where: input.email ? { email: input.email } : { phone: input.phone },
    select: VERIFY_TARGET_SELECT,
  });

  if (!user) throw new HttpError(404, "auth:errors.user_not_found");

  const channel: VerifyChannel = input.email ? "email" : "phone";
  const result = await applyOtpVerification(user, channel, input.code);

  // Post-verification state: a channel is "ok" when the account doesn't have
  // it, it was already verified, or we just verified it in this call.
  const emailOk = !user.email || user.is_email_verified || channel === "email";
  const phoneOk = !user.phone || user.is_phone_verified || channel === "phone";

  if (emailOk && phoneOk) {
    const token = signAccessToken({ userId: user.id });
    return { ...result, fullyVerified: true as const, token };
  }

  const unverified: VerifyChannel[] = [];
  if (!emailOk) unverified.push("email");
  if (!phoneOk) unverified.push("phone");
  return { ...result, fullyVerified: false as const, unverified };
}

// ─── Change Phone / Email ────────────────────────────────────────────────────

/**
 * Send OTP to both the old and new phone/email. The user must be authenticated.
 */
export async function requestChangePhoneEmail(input: {
  userId: number;
  type: "email" | "phone";
  newValue: string;
  lang: Lang;
}) {
  // Make sure the new value isn't already taken
  if (input.type === "email") {
    const exists = await prisma.user.findUnique({
      where: { email: input.newValue },
    });
    if (exists) throw new HttpError(400, "auth:errors.email_already_in_use");
  } else {
    const exists = await prisma.user.findUnique({
      where: { phone: input.newValue },
    });
    if (exists) throw new HttpError(400, "auth:errors.phone_already_in_use");
  }

  const user = await prisma.user.findUnique({
    where: { id: input.userId },
    select: OTP_USER_SELECT,
  });
  if (!user) throw new HttpError(404, "auth:errors.user_not_found");

  const verifyType = input.type === "email" ? "CHANGE_EMAIL" : "CHANGE_PHONE";

  // Determine the old destination:
  // If we're changing email, old destination is user.email. If user.email is null, fallback to user.phone.
  // If we're changing phone, old destination is user.phone. If user.phone is null, fallback to user.email.
  let oldChannel: "email" | "phone" = input.type;
  let oldDestination = input.type === "email" ? user.email : user.phone;
  if (!oldDestination) {
    oldChannel = input.type === "email" ? "phone" : "email";
    oldDestination = oldChannel === "email" ? user.email : user.phone;
  }

  if (!oldDestination) {
    throw new HttpError(400, "auth:errors.email_or_phone_required");
  }

  // Per-channel rate limit on both the old destination and the new target value
  await enforceOtpRateLimit(oldChannel, oldDestination);
  await enforceOtpRateLimit(input.type, input.newValue);

  const { otpLength, resendCooldownSeconds } = await getOtpSettings();

  // Cooldown check on the target channel
  const last = await prisma.userVerify.findFirst({
    where: { user_id: user.id, type: verifyType as any },
    orderBy: { created_at: "desc" },
    select: { created_at: true },
  });
  if (last) {
    const elapsed = (Date.now() - last.created_at.getTime()) / 1000;
    if (elapsed < resendCooldownSeconds) {
      const retryAfter = Math.ceil(resendCooldownSeconds - elapsed);
      throw new HttpError(429, "auth:errors.otp_cooldown", "OTP_COOLDOWN", {
        retryAfter,
      });
    }
  }

  // ── Anti-abuse: auto-freeze the wallet after too many changes ──────────────
  // Log every change request, then count the requests inside the configured
  // rolling window (both limits live in ApplicationSetting). Once the user hits
  // the threshold, freeze their wallet — an admin must unfreeze it — and reject
  // this request before any OTP is sent.
  const settings = await prisma.applicationSetting.findFirst({
    select: {
      change_account_freeze_threshold: true,
      change_account_freeze_window_days: true,
    },
  });
  const freezeThreshold = settings?.change_account_freeze_threshold ?? 5;
  const freezeWindowDays = settings?.change_account_freeze_window_days ?? 2;

  await prisma.phoneEmailChangeRequest.create({
    data: { user_id: user.id, type: verifyType as any },
  });

  const freezeWindowStart = new Date(
    Date.now() - freezeWindowDays * 24 * 60 * 60 * 1000,
  );
  const recentChanges = await prisma.phoneEmailChangeRequest.count({
    where: { user_id: user.id, created_at: { gte: freezeWindowStart } },
  });

  if (recentChanges >= freezeThreshold) {
    // Only freeze a wallet that exists and isn't already frozen, so we never
    // clobber an existing admin freeze reason / timestamp.
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: user.id },
      select: { id: true, status: true },
    });
    if (wallet && wallet.status !== "FROZEN") {
      await prisma.wallet.update({
        where: { id: wallet.id },
        data: {
          status: "FROZEN",
          frozen_at: new Date(),
          freeze_reason:
            user.lang === "AR"
              ? "تجميد تلقائي: تجاوز الحد المسموح لمحاولات تغيير رقم الهاتف أو البريد الإلكتروني"
              : "Auto-freeze: exceeded the allowed number of phone/email change attempts",
        },
      });
    }
    throw new HttpError(
      401,
      "auth:errors.wallet_frozen_change_limit",
      "WALLET_FROZEN_CHANGE_LIMIT",
      { threshold: freezeThreshold, windowDays: freezeWindowDays },
    );
  }

  const oldCode = generateOtp(otpLength);
  const newCode = generateOtp(otpLength);

  // Remove old change OTPs for this user + type
  await prisma.userVerify.deleteMany({
    where: { user_id: user.id, type: verifyType as any },
  });

  // Create two rows
  await prisma.userVerify.createMany({
    data: [
      {
        code: oldCode,
        user_id: user.id,
        type: verifyType as any,
        email: oldChannel === "email" ? oldDestination : null,
        phone: oldChannel === "phone" ? oldDestination : null,
        target_email: input.type === "email" ? input.newValue : null,
        target_phone: input.type === "phone" ? input.newValue : null,
      },
      {
        code: newCode,
        user_id: user.id,
        type: verifyType as any,
        email: input.type === "email" ? input.newValue : null,
        phone: input.type === "phone" ? input.newValue : null,
        target_email: input.type === "email" ? input.newValue : null,
        target_phone: input.type === "phone" ? input.newValue : null,
      },
    ],
  });

  // Send OTP to the old email/phone
  if (oldChannel === "email") {
    const { subject, text, html } = buildVerificationEmail({
      name: user.full_name,
      code: oldCode,
      lang: input.lang,
    });
    await sendEmail({ to: oldDestination, subject, text, html });
  } else {
    const smsLang: Lang = user.lang === "AR" ? "ar" : "en";
    const { text } = buildVerificationSms({ code: oldCode, lang: smsLang });
    // TODO: un comment this line after Broadnet work
    // await sendSms({ to: oldDestination, text, lang: smsLang });
  }

  // Send OTP to the new email/phone
  if (input.type === "email") {
    const { subject, text, html } = buildVerificationEmail({
      name: user.full_name,
      code: newCode,
      lang: input.lang,
    });
    // TODO: un comment this line after Broadnet work
    // await sendEmail({ to: input.newValue, subject, text, html });
  } else {
    const smsLang: Lang = user.lang === "AR" ? "ar" : "en";
    const { text } = buildVerificationSms({ code: newCode, lang: smsLang });
    // TODO: un comment this line after Broadnet work
    // await sendSms({ to: input.newValue, text, lang: smsLang });
  }

  return {
    via_old: oldChannel,
    via_new: input.type,
  };
}

/**
 * Verify both OTPs and apply the phone/email change.
 */
export async function verifyChangePhoneEmail(input: {
  userId: number;
  oldCode: string;
  newCode: string;
}) {
  const user = await prisma.user.findUnique({
    where: { id: input.userId },
    select: {
      id: true,
      email: true,
      phone: true,
    },
  });
  if (!user) throw new HttpError(404, "auth:errors.user_not_found");

  const oldRecord = await prisma.userVerify.findFirst({
    where: {
      code: input.oldCode,
      user_id: input.userId,
      type: { in: ["CHANGE_EMAIL", "CHANGE_PHONE"] },
    },
  });

  const newRecord = await prisma.userVerify.findFirst({
    where: {
      code: input.newCode,
      user_id: input.userId,
      type: { in: ["CHANGE_EMAIL", "CHANGE_PHONE"] },
    },
  });

  if (!oldRecord || !newRecord) {
    throw new HttpError(400, "auth:errors.otp_invalid");
  }

  if (oldRecord.type !== newRecord.type) {
    throw new HttpError(400, "auth:errors.otp_invalid");
  }

  const { validityMinutes } = await getOtpSettings();
  if (
    isExpired(oldRecord.created_at, validityMinutes) ||
    isExpired(newRecord.created_at, validityMinutes)
  ) {
    await prisma.userVerify.deleteMany({
      where: { id: { in: [oldRecord.id, newRecord.id] } },
    });
    throw new HttpError(400, "auth:errors.otp_expired");
  }

  if (
    oldRecord.target_email !== newRecord.target_email ||
    oldRecord.target_phone !== newRecord.target_phone
  ) {
    throw new HttpError(400, "auth:errors.otp_invalid");
  }

  const verifyType = oldRecord.type;
  const targetEmail = oldRecord.target_email;
  const targetPhone = oldRecord.target_phone;

  const isOldValid =
    (oldRecord.email && oldRecord.email === user.email) ||
    (oldRecord.phone && oldRecord.phone === user.phone);

  const isNewValid =
    (newRecord.email && newRecord.email === targetEmail) ||
    (newRecord.phone && newRecord.phone === targetPhone);

  if (!isOldValid || !isNewValid) {
    throw new HttpError(400, "auth:errors.otp_invalid");
  }

  // Re-validate uniqueness before applying (race condition guard)
  if (verifyType === "CHANGE_EMAIL" && targetEmail) {
    const exists = await prisma.user.findUnique({
      where: { email: targetEmail },
    });
    if (exists && exists.id !== input.userId)
      throw new HttpError(400, "auth:errors.email_already_in_use");
  }
  if (verifyType === "CHANGE_PHONE" && targetPhone) {
    const exists = await prisma.user.findUnique({
      where: { phone: targetPhone },
    });
    if (exists && exists.id !== input.userId)
      throw new HttpError(400, "auth:errors.phone_already_in_use");
  }

  // Apply the change
  const updateData =
    verifyType === "CHANGE_EMAIL"
      ? { email: targetEmail, is_email_verified: true }
      : { phone: targetPhone, is_phone_verified: true };

  await prisma.user.update({
    where: { id: input.userId },
    data: updateData,
  });

  // Cleanup
  await prisma.userVerify.deleteMany({
    where: {
      user_id: input.userId,
      type: verifyType,
    },
  });

  return {
    ok: true as const,
    changed: verifyType === "CHANGE_EMAIL" ? "email" : "phone",
  };
}
