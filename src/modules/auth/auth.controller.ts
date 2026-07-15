import type { Request, Response } from "express";
import {
  registerSchema,
  loginSchema,
  appleVerifySchema,
  googleVerifySchema,
  requestVerificationSchema,
  verifyAccountSchema,
  forgetPasswordSchema,
  verifyForgetPasswordSchema,
  changePasswordSchema,
  changePhoneEmailSchema,
  verifyChangePhoneEmailSchema,
  tokenSchema,
  linkAppleSchema,
  linkGoogleSchema,
} from "./auth.schema";
import {
  registerUser,
  loginUser,
  forgetPasswordService,
  verifyForgetPasswordService,
  changePasswordService,
  logoutUserService,
} from "./services/auth.service";
import {
  verifyAppleLogin,
  verifyGoogleLogin,
  linkAppleService,
  linkGoogleService,
} from "./services/oauth.service";
import {
  requestVerificationOtp,
  confirmVerification,
  requestChangePhoneEmail,
  verifyChangePhoneEmail as verifyChangePhoneEmailService,
} from "./services/otp.service";
import { AuthedRequest } from "@/types/authedRequest";
import { issueExternalAppToken } from "./services/externalApp.auth.service";

export async function register(req: Request, res: Response) {
  const parsed = registerSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }
  const lang = req.language;

  const result = await registerUser({ ...parsed.data, lang });

  return res.status(201).json({
    message: req.t("auth:messages.registered"),
    user: result.user,
    via: result.via,
  });
}

export async function login(req: Request, res: Response) {
  const parsed = loginSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await loginUser(parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.login_successful"),
    token: result.token,
    user: result.user,
  });
}
export async function logout(req: AuthedRequest, res: Response) {
  const result = await logoutUserService(req.user.id);

  return res.status(200).json({
    message: req.t("auth:messages.logout_successful"),
    ...result,
  });
}

export async function verifyMe(req: AuthedRequest, res: Response) {
  return res.status(200).json({
    user: {
      id: req.user.id,
      full_name: req.user.full_name,
      email: req.user.email,
      phone: req.user.phone,
      role: req.user.role.name,
      is_active: req.user.is_active,
    },
  });
}

export async function appleVerify(req: Request, res: Response) {
  const parsed = appleVerifySchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await verifyAppleLogin(parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.login_successful"),
    token: result.token,
    user: result.user,
    isNew: result.isNew,
  });
}

export async function googleVerify(req: Request, res: Response) {
  const parsed = googleVerifySchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await verifyGoogleLogin(parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.login_successful"),
    token: result.token,
    user: result.user,
    isNew: result.isNew,
  });
}

export async function linkApple(req: AuthedRequest, res: Response) {
  const parsed = linkAppleSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  await linkAppleService(req.user.id, parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.apple_linked_success"),
    ok: true,
  });
}

export async function linkGoogle(req: AuthedRequest, res: Response) {
  const parsed = linkGoogleSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  await linkGoogleService(req.user.id, parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.google_linked_success"),
    ok: true,
  });
}

export async function requestVerification(req: Request, res: Response) {
  const parsed = requestVerificationSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await requestVerificationOtp({
    ...parsed.data,
    lang: req.language,
  });

  return res
    .status(200)
    .json({ message: req.t("auth:messages.otp_sent"), ...result });
}

export async function verifyAccount(req: Request, res: Response) {
  const parsed = verifyAccountSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "common.errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await confirmVerification(parsed.data);

  return res
    .status(200)
    .json({ message: req.t("auth:messages.verified"), ...result });
}

export const forgetPassword = async (req: Request, res: Response) => {
  const parsed = forgetPasswordSchema.safeParse(req.sanitized.body);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    const key = issue?.message ?? "common.errors.validation";

    return res.status(400).json({
      message: req.t(key),
      field: issue.path[0],
    });
  }

  const result = await forgetPasswordService({
    ...parsed.data,
    lang: req.language,
  });

  return res.status(200).json({
    message: req.t("auth:messages.reset_otp_sent"),
    ...result,
  });
};

export const verifyForgetPassword = async (req: Request, res: Response) => {
  const parsed = verifyForgetPasswordSchema.safeParse(req.sanitized.body);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    const key = issue?.message ?? "common.errors.validation";

    return res.status(400).json({
      message: req.t(key),
      field: issue.path[0],
    });
  }

  const result = await verifyForgetPasswordService(parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.password_reset_success"),
    ...result,
  });
};

export const changePassword = async (req: AuthedRequest, res: Response) => {
  const parsed = changePasswordSchema.safeParse(req.sanitized.body);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    const key = issue?.message ?? "common.errors.validation";

    return res.status(400).json({
      message: req.t(key),
      field: issue.path[0],
    });
  }

  const result = await changePasswordService(req.user.id, parsed.data);

  return res.status(200).json({
    message: req.t("auth:messages.password_changed"),
    ...result,
  });
};

export const changePhoneEmail = async (req: AuthedRequest, res: Response) => {
  const parsed = changePhoneEmailSchema.safeParse(req.sanitized.body);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    const key = issue?.message ?? "common.errors.validation";

    return res.status(400).json({
      message: req.t(key),
      field: issue.path[0],
    });
  }

  const result = await requestChangePhoneEmail({
    userId: req.user.id,
    type: parsed.data.type,
    newValue: parsed.data.new_value,
    lang: req.language,
  });

  return res.status(200).json({
    message: req.t("auth:messages.change_otp_sent"),
    ...result,
  });
};

export const verifyOldNewPhoneEmail = async (
  req: AuthedRequest,
  res: Response,
) => {
  const parsed = verifyChangePhoneEmailSchema.safeParse(req.sanitized.body);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    const key = issue?.message ?? "common.errors.validation";

    return res.status(400).json({
      message: req.t(key),
      field: issue.path[0],
    });
  }

  const result = await verifyChangePhoneEmailService({
    userId: req.user.id,
    oldCode: parsed.data.old_code,
    newCode: parsed.data.new_code,
  });

  return res.status(200).json({
    message: req.t("auth:messages.phone_email_changed"),
    ...result,
  });
};

export async function issueToken(req: Request, res: Response) {
  const { client_id, client_secret } = tokenSchema.parse(req.body);
  const result = await issueExternalAppToken(client_id, client_secret);
  return res.json(result);
}
