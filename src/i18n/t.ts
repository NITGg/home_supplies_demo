import { Lang } from "@/types/express";
import i18next from "i18next";

export function t(lang: Lang, key: string, opts?: Record<string, unknown>) {
  return i18next.t(key, { lng: lang, ...opts });
}
