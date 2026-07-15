import fs from "node:fs";
import path from "node:path";
import i18next from "i18next";
import { HttpError } from "@/lib/httpError";
import { getAvailableApps, getApp, getNamespaces, getFilePath, type I18nApp } from "./admin.i18n.registry";
import { flatten, setPath } from "./admin.i18n.utils";
import { fetchRemoteNamespace, updateRemoteNamespace } from "./admin.i18n.remote";
import { commitAndPushLocaleFiles } from "./admin.i18n.git";
import type { UpdateI18nNamespaceDTO } from "./admin.i18n.validation";

function readJson(filePath: string): Record<string, unknown> {
  if (!fs.existsSync(filePath)) return {};
  const raw = fs.readFileSync(filePath, "utf-8");
  return raw.trim() ? JSON.parse(raw) : {};
}

function writeJson(filePath: string, data: Record<string, unknown>): void {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf-8");
}

export function listApps() {
  return getAvailableApps().map((app) => ({ key: app.key, label: app.label }));
}

export function listNamespaces(appKey: string) {
  const app = getApp(appKey);
  if (!app) throw new HttpError(404, "admin-i18n:errors.app_not_found");
  return getNamespaces(app);
}

async function getRemoteNamespaceContent(app: I18nApp, namespace: string) {
  const { rows } = await fetchRemoteNamespace(app.baseUrl!, app.internalPath!);
  return { app: app.key, namespace, rows };
}

export async function getNamespaceContent(appKey: string, namespace: string) {
  const app = getApp(appKey);
  if (!app) throw new HttpError(404, "admin-i18n:errors.app_not_found");

  const namespaces = getNamespaces(app);
  if (!namespaces.includes(namespace))
    throw new HttpError(404, "admin-i18n:errors.namespace_not_found");

  if (app.mode === "remote") return getRemoteNamespaceContent(app, namespace);

  const en = flatten(readJson(getFilePath(app, namespace, "en")));
  const ar = flatten(readJson(getFilePath(app, namespace, "ar")));

  const keys = Array.from(new Set([...Object.keys(en), ...Object.keys(ar)])).sort();
  const rows = keys.map((key) => ({ key, en: en[key] ?? "", ar: ar[key] ?? "" }));

  return { app: app.key, namespace, rows };
}

export async function updateNamespaceContent(input: UpdateI18nNamespaceDTO) {
  const app = getApp(input.app);
  if (!app) throw new HttpError(404, "admin-i18n:errors.app_not_found");

  const namespaces = getNamespaces(app);
  if (!namespaces.includes(input.namespace))
    throw new HttpError(404, "admin-i18n:errors.namespace_not_found");

  if (app.mode === "remote") {
    const { rows } = await updateRemoteNamespace(app.baseUrl!, app.internalPath!, input.updates);
    return { app: app.key, namespace: input.namespace, rows };
  }

  const enPath = getFilePath(app, input.namespace, "en");
  const arPath = getFilePath(app, input.namespace, "ar");

  const enData = readJson(enPath);
  const arData = readJson(arPath);

  for (const update of input.updates) {
    if (update.en !== undefined) setPath(enData, update.key, update.en);
    if (update.ar !== undefined) setPath(arData, update.key, update.ar);
  }

  writeJson(enPath, enData);
  writeJson(arPath, arData);

  // Mirror into the dist copy (if running from a build) so the currently
  // running process reflects the change immediately, without waiting for
  // the next build to copy src -> dist.
  if (app.distDir && app.dir !== app.distDir && fs.existsSync(app.distDir)) {
    writeJson(path.join(app.distDir, "en", `${input.namespace}.json`), enData);
    writeJson(path.join(app.distDir, "ar", `${input.namespace}.json`), arData);
  }

  // i18next caches loaded namespaces in memory — writing the JSON files alone
  // doesn't change what req.t() returns until the process restarts. Reload the
  // affected namespace into the running instance so changes apply immediately.
  await i18next.reloadResources(["en", "ar"], [input.namespace]);

  await commitAndPushLocaleFiles(
    [enPath, arPath],
    `chore(i18n): update ${app.key}/${input.namespace} translations via admin dashboard`,
  );

  return getNamespaceContent(input.app, input.namespace);
}
