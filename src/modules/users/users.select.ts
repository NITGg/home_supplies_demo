import { Prisma } from "@prisma/client";

export const userSafeSelect = Prisma.validator<Prisma.UserSelect>()({
  id: true,
  role_id: true,
  badge_id: true,
  full_name: true,
  email: true,
  phone: true,
  personal_photo: true,
  gender: true,
  lang: true,
  is_email_verified: true,
  is_phone_verified: true,
  is_active: true,
  created_at: true,
  updated_at: true,
  deleted_at: true,
  role: { select: { id: true, name: true, name_ar: true } },
  badge: { select: { id: true, name: true, name_ar: true, image: true } },
});

export type UserSafeDTO = Prisma.UserGetPayload<{ select: typeof userSafeSelect }>;
