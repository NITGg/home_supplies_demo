import type { Response } from "express";
import { HttpError } from "@/lib/httpError";
import {
  updateProfileSchema,
  updateFcmSchema,
  changeEmailSchema,
  changePhoneSchema,
  confirmOtpSchema,
  changePasswordSchema,
} from "../schemas/profile.schema";
import {
  updateProfileService,
  deleteMyAccountService,
  updateFcmTokenService,
  requestChangeEmailService,
  requestChangePhoneService,
  confirmChangeOtpService,
  changePasswordService,
  getMyProfileService,
} from "../services/profile.service";
import { AuthedRequest } from "@/types/authedRequest";

export async function getMyProfile(req: AuthedRequest, res: Response) {
  const user = await getMyProfileService(req.user.id);
  return res.status(200).json({ user });
}

export async function updateProfile(req: AuthedRequest, res: Response) {
  const parsed = updateProfileSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const user = await updateProfileService(req.user.id, parsed.data, req.file);

  return res
    .status(200)
    .json({ message: req.t("profile:messages.profile_updated"), user });
}

export async function deleteMyAccount(req: AuthedRequest, res: Response) {
  await deleteMyAccountService(req.user.id);
  return res
    .status(200)
    .json({ message: req.t("profile:messages.account_deleted") });
}

export async function updateFcmToken(req: AuthedRequest, res: Response) {
  const parsed = updateFcmSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    console.log("hi");

    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  await updateFcmTokenService(req.user.id, parsed.data.fcmToken);
  return res
    .status(200)
    .json({ message: req.t("common:messages.fcm_updated") });
}

export async function changeEmail(req: AuthedRequest, res: Response) {
  if (!req.user) throw new HttpError(401, "auth:errors.unauthorized");

  const parsed = changeEmailSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const lang = req.language;

  await requestChangeEmailService(req.user.id, parsed.data.email, lang);
  return res.status(200).json({ message: req.t("profile:messages.otp_sent") });
}

export async function changePhone(req: AuthedRequest, res: Response) {
  if (!req.user) throw new HttpError(401, "auth:errors.unauthorized");

  const parsed = changePhoneSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await requestChangePhoneService(
    req.user.id,
    parsed.data.phone,
  );
  return res.status(200).json({
    message: req.t("profile:messages.otp_sent"),
    ...result,
  });
}

export async function confirmOtp(req: AuthedRequest, res: Response) {
  if (!req.user) throw new HttpError(401, "auth:errors.unauthorized");

  const parsed = confirmOtpSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  await confirmChangeOtpService(req.user.id, parsed.data.code);
  return res
    .status(200)
    .json({ message: req.t("profile:messages.contact_updated") });
}

export async function changePassword(req: AuthedRequest, res: Response) {
  if (!req.user) throw new HttpError(401, "auth:errors.unauthorized");

  const parsed = changePasswordSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  await changePasswordService(
    req.user.id,
    parsed.data.oldPassword,
    parsed.data.newPassword,
  );
  return res
    .status(200)
    .json({ message: req.t("profile:messages.password_changed") });
}
