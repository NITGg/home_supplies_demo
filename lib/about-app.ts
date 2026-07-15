import api from "./api";

export interface AboutApp {
  id?: number;
  terms?: string | null;
  terms_ar?: string | null;
  privacy_policy?: string | null;
  privacy_policy_ar?: string | null;
  courier_terms?: string | null;
  courier_terms_ar?: string | null;
  courier_privacy_policy?: string | null;
  courier_privacy_policy_ar?: string | null;
  delete_account?: string | null;
  delete_account_ar?: string | null;
  about?: string | null;
  about_ar?: string | null;
  mission?: string | null;
  mission_ar?: string | null;
  vision?: string | null;
  vision_ar?: string | null;
  digital_card?: string | null;
  digital_card_ar?: string | null;
  phone?: string | null;
  email?: string | null;
  whatsapp?: string | null;
  customer_support_number?: string | null;
  vodafon_cash_number?: string | null;
  instapay_number?: string | null;
  facebook?: string | null;
  youtube?: string | null;
  instagram?: string | null;
  twitter?: string | null;
  tiktok?: string | null;
  snapchat?: string | null;
  pinterest?: string | null;
  linkedin?: string | null;
  reddit?: string | null;
  telegram?: string | null;
}

export async function fetchAboutApp(): Promise<AboutApp> {
  const res = await api.get<{ about_app: AboutApp }>("/about-app");
  return res.data.about_app;
}

export async function updateAboutApp(data: Partial<AboutApp>): Promise<void> {
  await api.put("/about-app", data);
}
