import jwt, { JwtPayload, type Secret, type SignOptions } from "jsonwebtoken";
import env from "@/config/env";
import { AppEnvironment } from "@prisma/client";

export type UserTokenPayload = JwtPayload & { userId: number };

export type ExternalAppTokenPayload = JwtPayload & {
  id: number;
  env: AppEnvironment;
  partner_id: number | null;
};

const USER_JWT_SECRET: Secret = env.JWT_SECRET;
const EXTERNAL_APP_JWT_SECRET: Secret = env.EXTERNAL_APP_JWT_SECRET;
export const EXTERNAL_APP_EXPIRES_IN = 60 * 60 * 2;

const getOptions = (type: "USER" | "EXTERNAL_APP" = "USER"): SignOptions => ({
  expiresIn: type === "EXTERNAL_APP" ? EXTERNAL_APP_EXPIRES_IN : env.JWT_EXPIRES_IN as SignOptions["expiresIn"],
});

export function signAccessToken(payload: UserTokenPayload) {
  return jwt.sign(payload, USER_JWT_SECRET, getOptions("USER"));
}

export function verifyAccessToken(token: string): UserTokenPayload {
  return jwt.verify(token, USER_JWT_SECRET) as UserTokenPayload;
}

export function signExternalAppToken(payload: ExternalAppTokenPayload) {
  return jwt.sign(payload, EXTERNAL_APP_JWT_SECRET, getOptions("EXTERNAL_APP"));
}

export function verifyExternalAppToken(token: string): ExternalAppTokenPayload {
  return jwt.verify(token, EXTERNAL_APP_JWT_SECRET) as ExternalAppTokenPayload;
}
