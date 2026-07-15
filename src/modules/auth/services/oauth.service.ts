import { signAccessToken } from "@/lib/jwt";
import { prisma } from "@/config/prisma";
import * as jose from "jose";
import env from "@/config/env";
import { HttpError } from "@/lib/httpError";
import type {
  AppleVerifyInput,
  GoogleVerifyInput,
  LinkAppleInput,
  LinkGoogleInput,
} from "../auth.schema";
import { OAuth2Client } from "google-auth-library";
import getOrCreateRole from "@/lib/getOrCreateRole";
import { getBadgeId } from "@/lib/getOrCreateBadge";

const ALLOWED_ROLE_IDS = [1, 3, 6];

type AppleJwtPayload = jose.JWTPayload & {
  sub?: string;
  email?: string;
};

async function verifyAppleToken(input: {
  idToken: string;
  clientId: string;
  nonce?: string;
}) {
  const JWKS_URL = "https://appleid.apple.com/auth/keys";
  const JWKS = jose.createRemoteJWKSet(new URL(JWKS_URL));

  let payload: AppleJwtPayload;
  try {
    const result = await jose.jwtVerify(input.idToken, JWKS, {
      issuer: "https://appleid.apple.com",
      audience: [input.clientId, "com.nit.tawreedat.go"],
    });
    payload = result.payload as AppleJwtPayload;
  } catch {
    throw new HttpError(401, "auth:errors.apple_token_invalid");
  }

  // optional nonce check
  if (input.nonce && payload.nonce && payload.nonce !== input.nonce) {
    throw new HttpError(401, "auth:errors.nonce_mismatch");
  }

  return payload;
}

export async function verifyAppleLogin(input: AppleVerifyInput) {
  const claims = await verifyAppleToken({
    idToken: input.idToken,
    clientId: env.AUTH_APPLE_CLIENT_ID,
    nonce: input.nonce,
  });

  const appleId = claims.sub;
  const email = typeof claims.email === "string" ? claims.email : undefined;

  if (!appleId) throw new HttpError(401, "auth:errors.apple_token_invalid");

  const where = email ? { email } : { apple_id: appleId };

  const existing = await prisma.user.findUnique({
    where: where as any,
    select: {
      id: true,
      full_name: true,
      email: true,
      phone: true,
      is_active: true,
      deleted_at: true,
      role: { select: { id: true, name: true } },
      wallet: true,
    },
  });

  if (existing) {
    if (existing.deleted_at)
      throw new HttpError(401, "auth:errors.unauthorized");
    if (!existing.is_active)
      throw new HttpError(403, "auth:errors.account_disabled");
    if (!ALLOWED_ROLE_IDS.includes(existing.role.id))
      throw new HttpError(401, "auth:errors.user_not_found");
    // Block login when the user's wallet has been frozen (by an admin, or by the
    // anti-abuse guard on phone/email changes). frozen_at is the freeze flag; the
    // freeze_reason is surfaced in `data` so the client can show why.
    if (existing.wallet?.frozen_at) {
      throw new HttpError(403, "auth:errors.wallet_frozen", "WALLET_FROZEN", {
        reason: existing.wallet.freeze_reason,
        frozenAt: existing.wallet.frozen_at,
      });
    }

    await prisma.user.update({
      where: { id: existing.id },
      data: {
        apple_id: appleId,
        login_type: "APPLE",
        ...(input.full_name ? { full_name: input.full_name } : {}),
        last_login_at: new Date(),
      },
    });

    const token = signAccessToken({ userId: existing.id });

    return {
      token,
      user: {
        id: existing.id,
        full_name: input.full_name ?? existing.full_name,
        email: existing.email,
        phone: existing.phone,
        role: existing.role.name,
      },
      isNew: false,
    };
  }

  // New user — role is always CUSTOMER by design, no check needed
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

  const created = await prisma.user.create({
    data: {
      full_name: input.full_name ?? "Apple User",
      email: email ?? null,
      apple_id: appleId,
      login_type: "APPLE",
      role_id: input.role_id ?? role.id,
      is_active: true,
      is_email_verified: true,
      badge_id: input.badge_id ?? badge_id,
      wallet: { create: { owner_type: "CUSTOMER" } },
    },
    select: {
      id: true,
      full_name: true,
      email: true,
      phone: true,
      role: { select: { name: true } },
    },
  });

  const token = signAccessToken({ userId: created.id });

  return {
    token,
    user: {
      id: created.id,
      full_name: created.full_name,
      email: created.email,
      phone: created.phone,
      role: created.role.name,
    },
    isNew: true,
  };
}

const client = new OAuth2Client();

export async function verifyGoogleLogin(input: GoogleVerifyInput) {
  let ticket;
  try {
    ticket = await client.verifyIdToken({
      idToken: input.idToken,
      audience: [
        env.GOOGLE_WEB_CLIENT_ID,
        env.GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID,
        env.GOOGLE_FLUTTER_COURIER_CLIENT_ID,
        env.GOOGLE_FLUTTER_CUSTOMER_PROD_CLIENT_ID,
        env.GOOGLE_FLUTTER_COURIER_PROD_CLIENT_ID,
        env.GOOGLE_FLUTTER_COURIER_IOS_CLIENT_ID,
      ],
    });
  } catch (error: any) {
    throw new HttpError(401, "auth:errors.google_token_invalid");
  }

  const payload = ticket.getPayload();

  const email = payload?.email ?? undefined;
  const full_name = payload?.name ?? "Google User";
  const personal_photo = payload?.picture ?? undefined;
  const googleId = payload?.sub ?? undefined;

  if (!email) throw new HttpError(401, "auth:errors.google_token_invalid");

  const existing = await prisma.user.findUnique({
    where: { email },
    select: {
      id: true,
      full_name: true,
      email: true,
      phone: true,
      is_active: true,
      deleted_at: true,
      role: { select: { id: true, name: true } },
      wallet: true,
    },
  });

  if (existing) {
    if (existing.deleted_at)
      throw new HttpError(401, "auth:errors.unauthorized");
    if (!existing.is_active)
      throw new HttpError(403, "auth:errors.account_disabled");
    if (!ALLOWED_ROLE_IDS.includes(existing.role.id))
      throw new HttpError(401, "auth:errors.user_not_found");
    // Block login when the user's wallet has been frozen (by an admin, or by the
    // anti-abuse guard on phone/email changes). frozen_at is the freeze flag; the
    // freeze_reason is surfaced in `data` so the client can show why.
    if (existing.wallet?.frozen_at) {
      throw new HttpError(403, "auth:errors.wallet_frozen", "WALLET_FROZEN", {
        reason: existing.wallet.freeze_reason,
        frozenAt: existing.wallet.frozen_at,
      });
    }

    await prisma.user.update({
      where: { id: existing.id },
      data: {
        login_type: "GOOGLE",
        ...(googleId ? { google_id: googleId } : {}),
        ...(personal_photo ? { personal_photo } : {}),
        ...(full_name ? { full_name } : {}),
        last_login_at: new Date(),
      },
    });

    const token = signAccessToken({ userId: existing.id });

    return {
      token,
      user: {
        id: existing.id,
        full_name: full_name ?? existing.full_name,
        email: existing.email,
        phone: existing.phone,
        role: existing.role.name,
      },
      isNew: false,
    };
  }

  // New user — role is always CUSTOMER by design, no check needed
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

  const created = await prisma.user.create({
    data: {
      email,
      full_name: full_name ?? "Google User",
      personal_photo: personal_photo ?? null,
      google_id: googleId ?? null,
      login_type: "GOOGLE",
      role_id: input.role_id ?? role.id,
      is_email_verified: true,
      badge_id: input.badge_id ?? badge_id,
      wallet: { create: { owner_type: "CUSTOMER" } },
    },
    select: {
      id: true,
      full_name: true,
      email: true,
      phone: true,
      role: { select: { name: true } },
    },
  });

  const token = signAccessToken({ userId: created.id });

  return {
    token,
    user: {
      id: created.id,
      full_name: created.full_name,
      email: created.email,
      phone: created.phone,
      role: created.role.name,
    },
    isNew: true,
  };
}

export async function linkAppleService(userId: number, input: LinkAppleInput) {
  const claims = await verifyAppleToken({
    idToken: input.idToken,
    clientId: env.AUTH_APPLE_CLIENT_ID,
    nonce: input.nonce,
  });

  const appleId = claims.sub;
  const email = typeof claims.email === "string" ? claims.email : undefined;

  if (!appleId) throw new HttpError(401, "auth:errors.apple_token_invalid");

  const existingAppleUser = await prisma.user.findFirst({
    where: { apple_id: appleId, id: { not: userId } },
  });
  if (existingAppleUser) {
    throw new HttpError(400, "auth:errors.apple_already_linked");
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { email: true },
  });
  if (!user) throw new HttpError(401, "auth:errors.unauthorized");

  await prisma.user.update({
    where: { id: userId },
    data: {
      apple_id: appleId,
      email: user.email ?? email,
      login_type: "APPLE",
    },
  });

  return { ok: true as const };
}

export async function linkGoogleService(
  userId: number,
  input: LinkGoogleInput,
) {
  let ticket;
  try {
    ticket = await client.verifyIdToken({
      idToken: input.idToken,
      audience: [
        env.GOOGLE_WEB_CLIENT_ID,
        env.GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID,
        env.GOOGLE_FLUTTER_COURIER_CLIENT_ID,
        env.GOOGLE_FLUTTER_CUSTOMER_PROD_CLIENT_ID,
        env.GOOGLE_FLUTTER_COURIER_PROD_CLIENT_ID,
        env.GOOGLE_FLUTTER_COURIER_IOS_CLIENT_ID,
      ],
    });
  } catch (error: any) {
    throw new HttpError(401, "auth:errors.google_token_invalid");
  }

  const payload = ticket.getPayload();
  const email = payload?.email ?? undefined;
  const googleId = payload?.sub ?? undefined;

  if (!googleId) throw new HttpError(401, "auth:errors.google_token_invalid");

  const existingGoogleUser = await prisma.user.findFirst({
    where: { google_id: googleId, id: { not: userId } },
  });
  if (existingGoogleUser) {
    throw new HttpError(400, "auth:errors.google_already_linked");
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { email: true },
  });
  if (!user) throw new HttpError(401, "auth:errors.unauthorized");

  await prisma.user.update({
    where: { id: userId },
    data: {
      google_id: googleId,
      email: user.email ?? email,
      login_type: "GOOGLE",
    },
  });

  return { ok: true as const };
}
