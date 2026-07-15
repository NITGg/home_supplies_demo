import bcrypt from "bcrypt";
import { signAccessToken } from "@/lib/jwt";
import { prisma } from "@/config/prisma";
import { normalizePhone } from "@/schemas/phone";
import type {
  LoginFormData,
  RegisterFormData,
  ChangePasswordInput,
  ForgetPasswordInput,
  VerifyForgetPasswordInput,
} from "../auth.schema";
import getOrCreateRole from "@/lib/getOrCreateRole";
import { HttpError } from "@/lib/httpError";
import { getBadgeId } from "@/lib/getOrCreateBadge";
import { generateOtp, getOtpSettings, isExpired } from "@/lib/otp";
import { Lang } from "@/types/express";
import { buildVerificationEmail } from "@/lib/emails/verificationEmail";
import { sendEmail } from "@/lib/mailer";
import { buildVerificationSms } from "@/lib/sms/verificationSms";
import { sendSms } from "@/lib/sms/broadnet";
import { enforceOtpRateLimit } from "./otpRateLimit.service";

const ALLOWED_ROLE_IDS = new Set([1, 2, 3, 4, 6, 7, 8]); // 1=Admin, 2=Courier, 3=Customer, 4=Seller, 6=Supplier, 7=CourierOffice, 8=CustomerSupport

/**
 * Look up a user by a generic identifier (email or phone), trying email first
 * then a normalized phone number. Used by the forget-password flow.
 */
async function findUserByIdentifier(identifier: string) {
  let user = await prisma.user.findFirst({
    where: { email: identifier },
    select: {
      id: true,
      full_name: true,
      email: true,
      phone: true,
      lang: true,
      login_type: true,
      password: true,
    },
  });

  if (!user) {
    let searchPhone = identifier;
    try {
      searchPhone = normalizePhone(identifier, { defaultCountry: "EG" });
    } catch {
      // ignore error and query with raw input
    }
    user = await prisma.user.findFirst({
      where: { phone: searchPhone },
      select: {
        id: true,
        full_name: true,
        email: true,
        phone: true,
        lang: true,
        login_type: true,
        password: true,
      },
    });
  }

  return user;
}

export async function registerUser(input: RegisterFormData & { lang: Lang }) {
  if (input.email) {
    const exists = await prisma.user.findUnique({
      where: { email: input.email },
    });
    if (exists) throw new HttpError(400, "auth:errors.email_exists");
  }

  if (input.phone) {
    const exists = await prisma.user.findUnique({
      where: { phone: input.phone },
    });
    if (exists) throw new HttpError(400, "auth:errors.phone_exists");
  }

  // step: check role
  if (input.role_id) {
    const roleExists = await prisma.userRole.findUnique({
      where: { id: input.role_id },
    });
    if (!roleExists) throw new HttpError(400, "auth:errors.role_not_found");
  }
  const role = await getOrCreateRole("Customer", "عميل"); // default role

  // step: check badge
  if (input.badge_id) {
    const badgeExists = await prisma.userBadge.findUnique({
      where: { id: input.badge_id },
    });
    if (!badgeExists) throw new HttpError(400, "auth:errors.badge_not_found");
  }
  const badge_id = await getBadgeId(input.role_id ?? role.id, "Basic"); // default badge

  // step: hash password
  const hashed = await bcrypt.hash(input.password, 10);

  const user = await prisma.user.create({
    data: {
      full_name: input.full_name,
      email: input.email ?? null,
      phone: input.phone ?? null,
      password: hashed,
      gender: input.gender ?? "MALE",
      role_id: input.role_id ?? role.id,
      login_type: "LOCAL",
      lang: input.lang.toUpperCase() as "EN" | "AR",
      badge_id: input.badge_id ?? badge_id,
      wallet: {
        create: {
          owner_type: "CUSTOMER",
        },
      },
    },
    select: {
      id: true,
      full_name: true,
      email: true,
      phone: true,
      is_active: true,
      is_email_verified: true,
      is_phone_verified: true,
    },
  });

  // Account starts unverified (email + phone). Generate an OTP (length from
  // ApplicationSetting.otp_length) and deliver it so the user can verify their
  // contact channel: email is sent via SMTP, phone via the Broadnet SMS gateway.
  const { otpLength } = await getOtpSettings();
  const code = generateOtp(otpLength);

  // Store a channel-specific OTP row (email row → phone=null and vice-versa)
  // and deliver only to that channel. input.lang is the language the account
  // was just created with (User.lang). Email goes via SMTP, phone via Broadnet.
  if (user.email) {
    await prisma.userVerify.create({
      data: { code, user_id: user.id, type: "VERIFY", email: user.email },
    });
    const { subject, text, html } = buildVerificationEmail({
      name: user.full_name,
      code,
      lang: input.lang,
    });
    await sendEmail({ to: user.email, subject, text, html });
  } else if (user.phone) {
    await prisma.userVerify.create({
      data: { code, user_id: user.id, type: "VERIFY", phone: user.phone },
    });
    const { text } = buildVerificationSms({ code, lang: input.lang });
    // TODO: un comment next line after Broadnet credentials are ready
    // await sendSms({ to: user.phone, text, lang: input.lang });
  }

  // No token here: the account is unverified, and login is gated on
  // verification. The user verifies via the public request-verification /
  // verify-account endpoints, and the token is issued there (or at /login).
  return {
    ok: true as const,
    user,
    via: user.email ? ("email" as const) : ("phone" as const),
  };
}

export async function loginUser(input: LoginFormData) {
  const where =
    "email" in input ? { email: input.email } : { phone: input.phone };

  const user = await prisma.user.findFirst({
    where,
    select: {
      id: true,
      email: true,
      phone: true,
      full_name: true,
      password: true,
      is_active: true,
      is_email_verified: true,
      is_phone_verified: true,
      deleted_at: true,
      role: { select: { id: true, name: true } },
      wallet: { select: { frozen_at: true, freeze_reason: true } },
    },
  });

  if (!user) throw new HttpError(404, "auth:errors.user_not_found");
  if (user.deleted_at) throw new HttpError(400, "auth:errors.user_not_found");
  if (!user.is_active) throw new HttpError(403, "auth:errors.user_blocked");

  // Check role by fixed ID
  if (!ALLOWED_ROLE_IDS.has(user.role.id))
    throw new HttpError(401, "auth:errors.user_not_found");

  if (!user.password) throw new HttpError(400, "auth:errors.no_password_set");
  const match = await bcrypt.compare(input.password, user.password);
  if (!match) throw new HttpError(400, "auth:errors.invalid_password");

  // Block login when the user's wallet has been frozen (by an admin, or by the
  // anti-abuse guard on phone/email changes). frozen_at is the freeze flag; the
  // freeze_reason is surfaced in `data` so the client can show why.
  if (user.wallet?.frozen_at) {
    throw new HttpError(403, "auth:errors.wallet_frozen", "WALLET_FROZEN", {
      reason: user.wallet.freeze_reason,
      frozenAt: user.wallet.frozen_at,
    });
  }

  // Every contact channel the account actually has must be verified before
  // login: email-only → email verified; phone-only → phone verified; both → both.
  const unverified: ("email" | "phone")[] = [];
  if (user.email && !user.is_email_verified) unverified.push("email");
  if (user.phone && !user.is_phone_verified) unverified.push("phone");

  if (unverified.length > 0) {
    // Hard block: no token is issued. The client drives verification through
    // the public, tokenless endpoints (request-verification / verify-account)
    // using the email/phone, then retries login.
    const both = unverified.length === 2;
    const code = both
      ? "ACCOUNT_NOT_VERIFIED"
      : unverified[0] === "email"
        ? "EMAIL_NOT_VERIFIED"
        : "PHONE_NOT_VERIFIED";
    const messageKey = both
      ? "auth:errors.account_not_verified"
      : unverified[0] === "email"
        ? "auth:errors.email_not_verified"
        : "auth:errors.phone_not_verified";

    throw new HttpError(403, messageKey, code, { unverified });
  }

  await prisma.user.update({
    where: { id: user.id },
    data: { last_login_at: new Date() },
  });

  const token = signAccessToken({ userId: user.id });

  return {
    ok: true as const,
    token,
    user: {
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role.name,
    },
  };
}

export async function logoutUserService(userId: number) {
  await prisma.user.update({
    where: { id: userId },
    data: {
      fcm_token: null,
    },
  });

  return { ok: true as const };
}

/**
 * Forget-password: look up the user by a generic `identifier` (email or phone),
 * detect available channels, and send an OTP.
 *
 * Channel selection logic:
 * - Phone only  → send to phone.
 * - Email only  → send to email.
 * - Both        → use `channel` hint, default to email if omitted.
 */
export async function forgetPasswordService(
  input: ForgetPasswordInput & { lang: Lang },
) {
  const user = await findUserByIdentifier(input.identifier);

  if (!user) throw new HttpError(404, "auth:errors.user_not_found");
  if (user.login_type !== "LOCAL")
    throw new HttpError(400, "auth:errors.oauth_account");

  // Determine the delivery channel
  const hasEmail = !!user.email;
  const hasPhone = !!user.phone;

  let channel: "email" | "phone";

  if (hasEmail && hasPhone) {
    // Both available — use caller hint, default to email
    channel = input.channel ?? "email";
  } else if (hasEmail) {
    channel = "email";
  } else if (hasPhone) {
    channel = "phone";
  } else {
    throw new HttpError(400, "auth:errors.email_or_phone_required");
  }

  // Per-channel rate limit
  const channelValue = channel === "email" ? user.email! : user.phone!;
  await enforceOtpRateLimit(channel, channelValue);

  // Anti-spam: refuse a new send while the previous code is still within the
  // admin-configurable resend cooldown (ApplicationSetting.otp_resend_duration_seconds),
  // so the endpoint can't be hammered to flood email/SMS.
  const { otpLength, resendCooldownSeconds: cooldownSeconds } =
    await getOtpSettings();

  const lastOtp = await prisma.userVerify.findFirst({
    where: { user_id: user.id, type: "FORGET_PASSWORD" },
    orderBy: { created_at: "desc" },
    select: { created_at: true },
  });
  if (lastOtp) {
    const elapsed = (Date.now() - lastOtp.created_at.getTime()) / 1000;
    if (elapsed < cooldownSeconds) {
      const retryAfter = Math.ceil(cooldownSeconds - elapsed);
      throw new HttpError(429, "auth:errors.otp_cooldown", "OTP_COOLDOWN", {
        retryAfter,
      });
    }
  }

  const code = generateOtp(otpLength);

  // Invalidate any previous forget-password code so only the newest one is valid.
  await prisma.userVerify.deleteMany({
    where: {
      user_id: user.id,
      type: "FORGET_PASSWORD",
    },
  });

  await prisma.userVerify.create({
    data: {
      user_id: user.id,
      email: channel === "email" ? user.email : null,
      phone: channel === "phone" ? user.phone : null,
      code,
      type: "FORGET_PASSWORD",
    },
  });

  // Deliver the OTP
  if (channel === "email") {
    const { subject, text, html } = buildVerificationEmail({
      name: user.full_name,
      code,
      lang: input.lang,
    });
    await sendEmail({ to: user.email!, subject, text, html });
    return { via: "email" as const };
  }

  const smsLang: Lang = user.lang === "AR" ? "ar" : "en";
  const { text } = buildVerificationSms({ code, lang: smsLang });
  // TODO: un comment next line after Broadnet credentials are ready
  // await sendSms({ to: user.phone!, text, lang: smsLang });
  return { via: "phone" as const };
}

/**
 * Verify the forget-password OTP and reset the password in one step (2-step
 * flow: forget-password → verify-forget-password).
 *
 * - Brute force: each wrong code increments `failed_attempts`; once it reaches
 *   the admin-configurable `forget_password_attempts` (ApplicationSetting,
 *   default 5 — the same setting used by the IP-level forgetPasswordLimiter),
 *   the OTP is invalidated entirely and a new one must be requested.
 * - Replay/idempotency: a successful verification marks the OTP as `consumed_at`
 *   (instead of deleting it) so a duplicate request with the same code+password
 *   (e.g. double-click / network retry) returns success again instead of erroring.
 * - Session hijacking: `password_last_updated` is bumped, which invalidates every
 *   previously issued access token (checked in resolveUserFromPayload).
 */
export async function verifyForgetPasswordService(
  input: VerifyForgetPasswordInput,
) {
  const user = await findUserByIdentifier(input.identifier);
  if (!user?.password) throw new HttpError(404, "auth:errors.user_not_found");

  const [record, settings] = await Promise.all([
    prisma.userVerify.findFirst({
      where: { user_id: user.id, type: "FORGET_PASSWORD" },
    }),
    prisma.applicationSetting.findFirst({
      select: {
        otp_validity_duration_minutes: true,
        forget_password_attempts: true,
      },
    }),
  ]);

  if (!record) throw new HttpError(400, "auth:errors.otp_invalid");
  const OTP_MINUTES = settings?.otp_validity_duration_minutes ?? 5;
  if (isExpired(record.created_at, OTP_MINUTES)) {
    await prisma.userVerify.delete({ where: { id: record.id } });
    throw new HttpError(400, "auth:errors.otp_expired");
  }

  // Replay of an already-processed request: if the password was already
  // changed to the one submitted now, treat this as a successful retry.
  if (record.consumed_at) {
    const alreadyApplied = await bcrypt.compare(input.password, user.password);
    if (alreadyApplied) return { ok: true as const };
    throw new HttpError(400, "auth:errors.otp_invalid");
  }

  if (record.code !== input.code) {
    const maxAttempts = settings?.forget_password_attempts ?? 5;
    const failedAttempts = record.failed_attempts + 1;
    if (failedAttempts >= maxAttempts) {
      await prisma.userVerify.delete({ where: { id: record.id } });
      throw new HttpError(400, "auth:errors.otp_too_many_attempts");
    }
    await prisma.userVerify.update({
      where: { id: record.id },
      data: { failed_attempts: failedAttempts },
    });
    throw new HttpError(400, "auth:errors.otp_invalid");
  }

  const isSamePassword = await bcrypt.compare(input.password, user.password);
  if (isSamePassword) {
    throw new HttpError(400, "auth:errors.password_same_as_old");
  }

  const hashed = await bcrypt.hash(input.password, 10);

  await prisma.user.update({
    where: { id: user.id },
    data: { password: hashed, password_last_updated: new Date() },
  });

  // // Keep the OTP row (marked consumed) until it naturally expires, so a
  // // retried request can be recognized as a replay instead of failing.
  // await prisma.userVerify.update({
  //   where: { id: record.id },
  //   data: { consumed_at: new Date() },
  // });

  // OTP consumed — delete it so user_verify only ever holds usable codes.
  await prisma.userVerify.delete({ where: { id: record.id } });

  return { ok: true as const };
}

/**
 * Change password (authenticated). Verifies the old password before setting
 * the new one.
 */
export async function changePasswordService(
  userId: number,
  input: ChangePasswordInput,
) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, password: true, login_type: true },
  });

  if (!user) throw new HttpError(404, "auth:errors.user_not_found");
  if (user.login_type !== "LOCAL")
    throw new HttpError(400, "auth:errors.oauth_account");
  if (!user.password) throw new HttpError(400, "auth:errors.no_password_set");

  const match = await bcrypt.compare(input.old_password, user.password);
  if (!match) throw new HttpError(400, "auth:errors.invalid_password");

  const isSame = await bcrypt.compare(input.new_password, user.password);
  if (isSame) throw new HttpError(400, "auth:errors.password_same_as_old");

  const hashed = await bcrypt.hash(input.new_password, 10);

  await prisma.user.update({
    where: { id: userId },
    data: { password: hashed, password_last_updated: new Date() },
  });

  return { ok: true as const };
}
