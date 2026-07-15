import fs from "node:fs";
import path from "node:path";

export type I18nAppMode = "namespaced" | "remote";

export interface I18nApp {
  key: string;
  label: string;
  /**
   * "namespaced": dir/{lng}/{ns}.json — files local to this server (backend's own locales).
   * "remote": another app's own server exposes its locale file over an internal HTTP API,
   * since that app may be deployed separately with its own folder structure/build.
   */
  mode: I18nAppMode;
  dir?: string;
  /**
   * Built-app copy of `dir` (e.g. `dist/i18n/locales`). `npm run build` copies
   * `src/i18n/locales` -> `dist/i18n/locales`, overwriting it — so when running
   * from `dist`, writes must still target `src/i18n/locales` (source of truth)
   * and additionally mirror into `distDir` so the running process picks them
   * up immediately without waiting for the next build.
   */
  distDir?: string;
  baseUrl?: string;
  internalPath?: string;
}

const SRC_LOCALES_DIR = path.join(process.cwd(), "src/i18n/locales");
const DIST_LOCALES_DIR = path.join(process.cwd(), "dist/i18n/locales");

export const I18N_APPS: I18nApp[] = [
  {
    key: "admin",
    label: "Admin API",
    mode: "namespaced",
    dir: fs.existsSync(SRC_LOCALES_DIR) ? SRC_LOCALES_DIR : DIST_LOCALES_DIR,
    distDir: DIST_LOCALES_DIR,
  },
  {
    key: "courier",
    label: "Courier App",
    mode: "remote",
    baseUrl: process.env.COURIER_API_BASE_URL ?? "http://localhost:3003",
    internalPath: "/internal/i18n",
  },
  {
    key: "supplier",
    label: "Supplier App",
    mode: "remote",
    baseUrl: process.env.SUPPLIER_API_BASE_URL ?? "http://localhost:3004",
    internalPath: "/internal/i18n",
  },
];

/** Apps usable in the current deployment: namespaced apps need their locale dir on disk. */
export function getAvailableApps(): I18nApp[] {
  return I18N_APPS.filter(
    (app) => app.mode === "remote" || (app.dir && fs.existsSync(app.dir)),
  );
}

export function getApp(key: string): I18nApp | undefined {
  return getAvailableApps().find((app) => app.key === key);
}

/** List the namespaces available for an app, based on its mode. */
export function getNamespaces(app: I18nApp): string[] {
  if (app.mode === "remote" || !app.dir) return ["default"];

  const enDir = path.join(app.dir, "en");
  if (!fs.existsSync(enDir)) return [];

  return fs
    .readdirSync(enDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => f.replace(/\.json$/, ""))
    .sort();
}

/** Resolve the absolute file path for a given app/namespace/language (namespaced apps only). */
export function getFilePath(
  app: I18nApp,
  namespace: string,
  lang: "en" | "ar",
): string {
  return path.join(app.dir!, lang, `${namespace}.json`);
}
