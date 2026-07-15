import bcrypt from "bcrypt";
import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { generateOtp, getOtpSettings, isExpired } from "@/lib/otp";
import { buildVerificationEmail } from "@/lib/emails/verificationEmail";
import { sendEmail } from "@/lib/mailer";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";
import { buildVerificationSms } from "@/lib/sms/verificationSms";
import { sendSms } from "@/lib/sms/broadnet";

// Non-sensitive supplier fields safe to expose on the owner's own profile.
// Identity/legal documents (national_id_*, supplier_criminal_record, tax_card,
// commercial_register) are intentionally excluded.
const SUPPLIER_PUBLIC_SELECT = {
  id: true,
  type_id: true,
  synonyms: true,
  is_approved: true,
  markup_ratio: true,
  min_price_for_one_order: true,
  max_price_for_one_order: true,
  shopping_min_price_for_one_order: true,
  shopping_max_price_for_one_order: true,
  shopping_budget_fee: true,
  created_at: true,
  updated_at: true,
} as const;

export async function getMyProfileService(userId: number) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    omit: {
      password: true,
      password_last_updated: true,
    },
    include: {
      role: { select: { name: true } },
    },
  });
  if (!user || user.deleted_at)
    throw new HttpError(401, "auth:errors.unauthorized");

  if (user.role.name === "Supplier") {
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: userId },
      select: SUPPLIER_PUBLIC_SELECT,
    });
    return { ...user, supplier };
  }

  return user;
}

export async function updateProfileService(
  userId: number,
  input: {
    full_name?: string;
    lang?: "AR" | "EN";
    gender?: "MALE" | "FEMALE";
    deleteImage?: boolean;
  },
  file?: Express.Multer.File,
) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, personal_photo: true, deleted_at: true, role: true },
  });
  if (!user || user.deleted_at)
    throw new HttpError(401, "auth:errors.unauthorized");

  const _deleteImage = input.deleteImage === true;
  const hasNewFile = !!file?.path;

  let personal_photo: string | null | undefined = undefined;

  if ((_deleteImage || hasNewFile) && user.personal_photo) {
    const publicId = extractPublicIdFromUrl(user.personal_photo);
    if (publicId) {
      await destroySingleFile({ public_id: publicId }).catch((err) =>
        console.error(err),
      );
    }
  }
  if (_deleteImage) personal_photo = null;

  if (hasNewFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file!.path, // .path or .buffer
      storagePathOnCloudinary: `users/${user.role.name}`,
    });
    personal_photo = secure_url;
  }

  const { deleteImage: _del, ...rest } = input;

  return prisma.user.update({
    where: { id: userId },
    data: {
      ...rest,
      personal_photo,
    },
    select: {
      id: true,
      full_name: true,
      gender: true,
      personal_photo: true,
      lang: true,
    },
  });
}

export async function deleteMyAccountService(userId: number) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, deleted_at: true },
  });
  if (!user || user.deleted_at)
    throw new HttpError(401, "auth:errors.unauthorized");

  await prisma.user.update({
    where: { id: userId },
    data: {
      deleted_at: new Date(),
      is_active: false,
      fcm_token: null,
    },
  });

  return { ok: true as const };
}

export async function updateFcmTokenService(userId: number, fcmToken: string) {
  const token = fcmToken.trim();

  await prisma.$transaction(async (tx) => {
    await tx.user.updateMany({
      where: {
        id: { not: userId },
        fcm_token: token,
      },
      data: {
        fcm_token: null,
      },
    });

    await tx.user.update({
      where: { id: userId },
      data: {
        fcm_token: token,
      },
    });
  });

  return { ok: true as const };
}

/**
 * Change email/phone flow:
 * 1) request change => create UserVerify with email or phone + code
 * 2) confirm-otp => validate code then apply email/phone
 */
export async function requestChangeEmailService(
  userId: number,
  email: string,
  lang: "ar" | "en",
) {
  const exists = await prisma.user.findUnique({
    where: { email },
    select: { id: true },
  });
  if (exists) throw new HttpError(409, "users:errors.email_exists");

  const { otpLength } = await getOtpSettings();
  const code = generateOtp(otpLength);

  await prisma.userVerify.deleteMany({ where: { user_id: userId, email } });
  await prisma.userVerify.create({
    data: { user_id: userId, email, code },
  });

  const { subject, text, html } = buildVerificationEmail({
    name: "User",
    code,
    lang,
  });

  await sendEmail({ to: email, subject, text, html });

  return { ok: true as const };
}

export async function requestChangePhoneService(userId: number, phone: string) {
  const exists = await prisma.user.findUnique({
    where: { phone },
    select: { id: true },
  });
  if (exists) throw new HttpError(409, "users:errors.phone_exists");

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { lang: true },
  });
  if (!user) throw new HttpError(404, "users:errors.not_found");

  const { otpLength } = await getOtpSettings();
  const code = generateOtp(otpLength);

  await prisma.userVerify.deleteMany({ where: { user_id: userId, phone } });
  await prisma.userVerify.create({
    data: { user_id: userId, phone, code },
  });

  const smsLang = user.lang === "AR" ? "ar" : "en";
  const { text } = buildVerificationSms({ code, lang: smsLang });
  // TODO: un comment this line after Broadnet work
  // await sendSms({ to: phone, text, lang: smsLang });

  return { ok: true as const, via: "phone" as const };
}

export async function confirmChangeOtpService(userId: number, code: string) {
  const record = await prisma.userVerify.findFirst({
    where: { user_id: userId, code },
    orderBy: { created_at: "desc" },
  });

  if (!record) throw new HttpError(400, "auth:errors.invalid_code");
  const { validityMinutes } = await getOtpSettings();
  if (isExpired(record.created_at, validityMinutes)) {
    await prisma.userVerify.deleteMany({ where: { user_id: userId } });
    throw new HttpError(400, "auth:errors.code_expired");
  }

  // Apply change based on what was requested
  if (record.email) {
    await prisma.user.update({
      where: { id: userId },
      data: {
        email: record.email,
        is_email_verified: true,
      },
    });
  } else if (record.phone) {
    await prisma.user.update({
      where: { id: userId },
      data: {
        phone: record.phone,
        is_phone_verified: true,
      },
    });
  } else {
    throw new HttpError(400, "auth:errors.invalid_code");
  }

  await prisma.userVerify.deleteMany({ where: { user_id: userId } });

  return { ok: true as const };
}

export async function changePasswordService(
  userId: number,
  oldPassword: string,
  newPassword: string,
) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, password: true, deleted_at: true },
  });
  if (!user || user.deleted_at)
    throw new HttpError(401, "auth:errors.unauthorized");
  if (!user.password)
    throw new HttpError(400, "profile:errors.no_password_set");

  const match = await bcrypt.compare(oldPassword, user.password);
  if (!match) throw new HttpError(400, "profile:errors.old_password_wrong");

  const hashed = await bcrypt.hash(newPassword, 10);

  await prisma.user.update({
    where: { id: userId },
    data: {
      password: hashed,
      password_last_updated: new Date(),
      login_type: "LOCAL",
    },
  });

  return { ok: true as const };
}
