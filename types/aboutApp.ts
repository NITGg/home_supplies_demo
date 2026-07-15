export interface AboutApp {
  id: number;
  terms: string;
  terms_ar: string;
  privacy_policy: string;
  privacy_policy_ar: string;
  courier_terms: string;
  courier_terms_ar: string;
  courier_privacy_policy: string;
  courier_privacy_policy_ar: string;
  delete_account: string | null;
  delete_account_ar: string | null;
  about: string | null;
  about_ar: string | null;
  mission: string | null;
  mission_ar: string | null;
  vision: string | null;
  vision_ar: string | null;
  digital_card: string | null;
  digital_card_ar: string | null;
  phone: string;
  email: string;
  whatsapp: string;
  facebook: string;
  youtube: string;
  instagram: string;
  twitter: string;
  tiktok: string;
  snapchat: string;
  pinterest: string;
  linkedin: string;
  reddit: string;
  telegram: string;
  vodafon_cash_number: string;
  instapay_number: string;
  customer_support_number: string;
  attempts_login?: string | number;
  duration_attempts_login_minutes?: string | number;
  vat?: string | number;
}

export interface AboutAppResponse {
  about_app: AboutApp;
}

export type UpdateAboutAppPayload = Omit<
  AboutApp,
  "id" | "vodafon_cash_number" | "instapay_number" | "customer_support_number"
>;
