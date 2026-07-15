"use client";
import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from "react";
import { translations, type Lang } from "@/lib/i18n";

export type Overrides = Record<Lang, Record<string, string>>;
const OVERRIDES_KEY = "admin_i18n_overrides";

function loadOverrides(): Overrides {
  if (typeof window === "undefined") return { EN: {}, AR: {} };
  try {
    const raw = localStorage.getItem(OVERRIDES_KEY);
    if (!raw) return { EN: {}, AR: {} };
    const parsed = JSON.parse(raw);
    return { EN: parsed.EN ?? {}, AR: parsed.AR ?? {} };
  } catch { return { EN: {}, AR: {} }; }
}

interface LangContextValue {
  lang: Lang;
  setLang: (l: Lang) => void;
  isRTL: boolean;
  t: (key: string) => string;
  overrides: Overrides;
  setOverride: (lang: Lang, key: string, value: string) => void;
  resetOverride: (lang: Lang, key: string) => void;
  clearOverrides: () => void;
}

const LangContext = createContext<LangContextValue | null>(null);

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>("EN");
  const [overrides, setOverridesState] = useState<Overrides>({ EN: {}, AR: {} });

  useEffect(() => {
    const saved = localStorage.getItem("admin_lang") as Lang | null;
    if (saved === "AR" || saved === "EN") setLangState(saved);
    setOverridesState(loadOverrides());
  }, []);

  useEffect(() => {
    document.documentElement.dir  = lang === "AR" ? "rtl" : "ltr";
    document.documentElement.lang = lang === "AR" ? "ar"  : "en";
    localStorage.setItem("admin_lang", lang);
  }, [lang]);

  function setLang(l: Lang) { setLangState(l); }

  const setOverride = useCallback((l: Lang, key: string, value: string) => {
    setOverridesState(prev => {
      const next: Overrides = { ...prev, [l]: { ...prev[l], [key]: value } };
      localStorage.setItem(OVERRIDES_KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  const resetOverride = useCallback((l: Lang, key: string) => {
    setOverridesState(prev => {
      const updated = { ...prev[l] };
      delete updated[key];
      const next: Overrides = { ...prev, [l]: updated };
      localStorage.setItem(OVERRIDES_KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  const clearOverrides = useCallback(() => {
    const empty: Overrides = { EN: {}, AR: {} };
    setOverridesState(empty);
    localStorage.removeItem(OVERRIDES_KEY);
  }, []);

  const isRTL = lang === "AR";
  const t = (key: string) =>
    overrides[lang]?.[key] ?? translations[lang][key] ?? key;

  return (
    <LangContext.Provider value={{ lang, setLang, isRTL, t, overrides, setOverride, resetOverride, clearOverrides }}>
      {children}
    </LangContext.Provider>
  );
}

export function useT() {
  const ctx = useContext(LangContext);
  if (!ctx) throw new Error("useT must be used within LanguageProvider");
  return ctx;
}
