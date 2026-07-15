import { z } from "zod";

const textNullable = z.string().optional().nullable();
const linkNullable = z.string().max(200).optional().nullable();

export const upsertAboutAppSchema = z.object({
  terms: textNullable,
  terms_ar: textNullable,
  courier_terms: textNullable,
  courier_terms_ar: textNullable,
  about: textNullable,
  about_ar: textNullable,
  privacy_policy: textNullable,
  privacy_policy_ar: textNullable,
  courier_privacy_policy: textNullable,
  courier_privacy_policy_ar: textNullable,
  mission: textNullable,
  mission_ar: textNullable,
  vision: textNullable,
  vision_ar: textNullable,
  digital_card: textNullable,
  digital_card_ar: textNullable,
  phone: z.string().optional().nullable(),
  email: z.email().optional().nullable(),
  facebook: linkNullable,
  instagram: linkNullable,
  linkedin: linkNullable,
  pinterest: linkNullable,
  reddit: linkNullable,
  snapchat: linkNullable,
  telegram: linkNullable,
  tiktok: linkNullable,
  twitter: linkNullable,
  whatsapp: linkNullable,
  youtube: linkNullable,
  delete_account: textNullable,
  delete_account_ar: textNullable,
});

export type UpsertAboutAppInput = z.infer<typeof upsertAboutAppSchema>;
