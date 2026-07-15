import api from "./api";

export interface I18nApp {
  key: string;
  label: string;
}

export interface I18nRow {
  key: string;
  en: string;
  ar: string;
}

export interface I18nNamespaceContent {
  app: string;
  namespace: string;
  rows: I18nRow[];
}

export async function fetchI18nApps() {
  const res = await api.get<{ data: { apps: I18nApp[] } }>("/admin/i18n/apps");
  return res.data.data.apps;
}

export async function fetchI18nNamespaces(app: string) {
  const res = await api.get<{ data: { namespaces: string[] } }>(`/admin/i18n/${app}/namespaces`);
  return res.data.data.namespaces;
}

export async function fetchI18nNamespaceContent(app: string, namespace: string) {
  const res = await api.get<{ data: I18nNamespaceContent }>(`/admin/i18n/${app}/${namespace}`);
  return res.data.data;
}

export interface I18nUpdate {
  key: string;
  en?: string;
  ar?: string;
}

export async function updateI18nNamespace(app: string, namespace: string, updates: I18nUpdate[]) {
  const res = await api.put<{ data: I18nNamespaceContent }>(`/admin/i18n/${app}/${namespace}`, { updates });
  return res.data.data;
}
