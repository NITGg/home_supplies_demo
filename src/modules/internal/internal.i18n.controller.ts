import { Router, Request, Response } from "express";
import fs from "node:fs";
import path from "node:path";
import { flatten, setPath } from "./internal.i18n.utils";
import { commitAndPushLocaleFiles } from "./internal.i18n.git";

// Internal-only endpoints — read/update this app's locale files (en.json / ar.json).
// Called server-to-server by the admin backend's i18n management module.
// No public auth needed, same as courier's internal endpoints.

const router = Router();

// `__dirname` points into `dist/src/modules/internal` when running the built
// app, so writing relative to it would hit `dist/src/core/locals` — a copy
// that `npm run build` overwrites from `src/**/*.json` on every deploy,
// silently discarding any edits made through this endpoint while running the
// built app. `src/core/locals` is the source of truth (git-tracked, and what
// `copyfiles` copies into dist on build), so always read/write it from the
// project root, and additionally mirror writes into the dist copy (if
// present) so the currently running process reflects the change immediately.
const SRC_LOCALES_DIR = path.join(process.cwd(), "src/core/locals");
const DIST_LOCALES_DIR = path.join(process.cwd(), "dist/src/core/locals");
const LOCALES_DIR = fs.existsSync(SRC_LOCALES_DIR) ? SRC_LOCALES_DIR : DIST_LOCALES_DIR;

function readJson(filePath: string): Record<string, unknown> {
  if (!fs.existsSync(filePath)) return {};
  const raw = fs.readFileSync(filePath, "utf-8");
  return raw.trim() ? JSON.parse(raw) : {};
}

function writeJson(filePath: string, data: Record<string, unknown>): void {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf-8");
}

// Writes to the source-of-truth file and, if the app is running from a build,
// also mirrors the change into the dist copy so it takes effect immediately.
function writeLocale(filename: string, data: Record<string, unknown>): void {
  writeJson(path.join(LOCALES_DIR, filename), data);
  if (LOCALES_DIR !== DIST_LOCALES_DIR && fs.existsSync(DIST_LOCALES_DIR)) {
    writeJson(path.join(DIST_LOCALES_DIR, filename), data);
  }
}

router.get("/", (_req: Request, res: Response) => {
  const en = flatten(readJson(path.join(LOCALES_DIR, "en.json")));
  const ar = flatten(readJson(path.join(LOCALES_DIR, "ar.json")));
  const keys = Array.from(new Set([...Object.keys(en), ...Object.keys(ar)])).sort();
  const rows = keys.map((key) => ({ key, en: en[key] ?? "", ar: ar[key] ?? "" }));
  res.json({ rows });
});

router.put("/", async (req: Request, res: Response) => {
  const updates: { key: string; en?: string; ar?: string }[] = req.body?.updates ?? [];
  const enData = readJson(path.join(LOCALES_DIR, "en.json"));
  const arData = readJson(path.join(LOCALES_DIR, "ar.json"));

  for (const update of updates) {
    if (update.en !== undefined) setPath(enData, update.key, update.en);
    if (update.ar !== undefined) setPath(arData, update.key, update.ar);
  }

  writeLocale("en.json", enData);
  writeLocale("ar.json", arData);

  await commitAndPushLocaleFiles(
    [path.join(LOCALES_DIR, "en.json"), path.join(LOCALES_DIR, "ar.json")],
    "chore(i18n): update supplier translations via admin dashboard",
  );

  const en = flatten(enData);
  const ar = flatten(arData);
  const keys = Array.from(new Set([...Object.keys(en), ...Object.keys(ar)])).sort();
  const rows = keys.map((key) => ({ key, en: en[key] ?? "", ar: ar[key] ?? "" }));
  res.json({ rows });
});

export default router;
