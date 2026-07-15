"use client";

import { useState, useMemo } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchI18nApps,
  fetchI18nNamespaces,
  fetchI18nNamespaceContent,
  updateI18nNamespace,
  type I18nUpdate,
} from "@/lib/system-i18n";
import { useT } from "@/contexts/LanguageContext";
import { Languages, Loader2, Save, Search, X } from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";

export default function AppTranslationsPage() {
  const { t } = useT();
  const qc = useQueryClient();

  const [selectedApp, setSelectedApp] = useState<string | null>(null);
  const [selectedNamespace, setSelectedNamespace] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [edits, setEdits] = useState<Record<string, { en?: string; ar?: string }>>({});
  const [saving, setSaving] = useState(false);

  const { data: apps, isLoading: appsLoading } = useQuery({
    queryKey: ["system-i18n-apps"],
    queryFn: fetchI18nApps,
    staleTime: 60_000,
  });

  const { data: namespaces, isLoading: namespacesLoading } = useQuery({
    queryKey: ["system-i18n-namespaces", selectedApp],
    queryFn: () => fetchI18nNamespaces(selectedApp!),
    enabled: !!selectedApp,
    staleTime: 60_000,
  });

  const { data: content, isLoading: contentLoading } = useQuery({
    queryKey: ["system-i18n-content", selectedApp, selectedNamespace],
    queryFn: () => fetchI18nNamespaceContent(selectedApp!, selectedNamespace!),
    enabled: !!selectedApp && !!selectedNamespace,
  });

  const rows = useMemo(() => {
    const all = content?.rows ?? [];
    if (!search.trim()) return all;
    const q = search.toLowerCase();
    return all.filter(
      (r) =>
        r.key.toLowerCase().includes(q) ||
        r.en.toLowerCase().includes(q) ||
        r.ar.includes(q),
    );
  }, [content, search]);

  const editedCount = Object.keys(edits).length;

  function selectApp(appKey: string) {
    setSelectedApp(appKey);
    setSelectedNamespace(null);
    setEdits({});
    setSearch("");
  }

  function selectNamespace(ns: string) {
    setSelectedNamespace(ns);
    setEdits({});
    setSearch("");
  }

  function setEdit(key: string, field: "en" | "ar", value: string) {
    setEdits((prev) => ({ ...prev, [key]: { ...prev[key], [field]: value } }));
  }

  async function handleSave() {
    if (!selectedApp || !selectedNamespace || editedCount === 0) return;
    const updates: I18nUpdate[] = Object.entries(edits).map(([key, v]) => ({ key, ...v }));
    setSaving(true);
    try {
      await updateI18nNamespace(selectedApp, selectedNamespace, updates);
      toast.success(t("translations.saved"));
      setEdits({});
      qc.invalidateQueries({ queryKey: ["system-i18n-content", selectedApp, selectedNamespace] });
    } catch (e: any) {
      toast.error(e?.response?.data?.message ?? "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="p-6 space-y-6">
      <div>
        <div className="flex items-center gap-2 mb-1">
          <Languages size={22} className="text-indigo-600" />
          <h1 className="text-2xl font-bold text-gray-900">{t("translations.appsTitle")}</h1>
        </div>
        <p className="text-sm text-gray-500">{t("translations.appsSubtitle")}</p>
      </div>

      <div className="grid grid-cols-12 gap-4">
        {/* Apps */}
        <div className="col-span-12 md:col-span-2 bg-white rounded-xl border border-gray-200 p-2 h-fit">
          {appsLoading ? (
            <div className="flex justify-center py-6"><Loader2 size={18} className="animate-spin text-indigo-400" /></div>
          ) : (
            (apps ?? []).map((app) => (
              <button
                key={app.key}
                onClick={() => selectApp(app.key)}
                className={cn(
                  "w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition mb-1",
                  selectedApp === app.key ? "bg-indigo-100 text-indigo-700" : "text-gray-600 hover:bg-gray-50",
                )}
              >
                {app.label}
              </button>
            ))
          )}
        </div>

        {/* Namespaces */}
        <div className="col-span-12 md:col-span-2 bg-white rounded-xl border border-gray-200 p-2 h-fit max-h-[70vh] overflow-y-auto">
          {!selectedApp ? (
            <p className="text-sm text-gray-400 p-3">{t("translations.selectApp")}</p>
          ) : namespacesLoading ? (
            <div className="flex justify-center py-6"><Loader2 size={18} className="animate-spin text-indigo-400" /></div>
          ) : (
            (namespaces ?? []).map((ns) => (
              <button
                key={ns}
                onClick={() => selectNamespace(ns)}
                className={cn(
                  "w-full text-left px-3 py-2 rounded-lg text-xs font-mono transition mb-1",
                  selectedNamespace === ns ? "bg-indigo-100 text-indigo-700" : "text-gray-600 hover:bg-gray-50",
                )}
              >
                {ns}
              </button>
            ))
          )}
        </div>

        {/* Content */}
        <div className="col-span-12 md:col-span-8 bg-white rounded-xl border border-gray-200">
          {!selectedApp || !selectedNamespace ? (
            <div className="p-10 text-center text-gray-400 text-sm">{t("translations.selectNamespace")}</div>
          ) : contentLoading ? (
            <div className="flex justify-center py-10"><Loader2 size={20} className="animate-spin text-indigo-400" /></div>
          ) : (
            <>
              <div className="flex items-center gap-3 p-4 border-b border-gray-100">
                <div className="relative flex-1">
                  <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder={t("translations.searchPlaceholder")}
                    className="w-full pl-9 pr-4 py-2 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                  {search && (
                    <button onClick={() => setSearch("")} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                      <X size={14} />
                    </button>
                  )}
                </div>
                {editedCount > 0 && (
                  <span className="text-xs bg-amber-100 text-amber-700 px-2 py-1 rounded-full font-medium">
                    {editedCount} {t("translations.modified")}
                  </span>
                )}
                <button
                  onClick={handleSave}
                  disabled={editedCount === 0 || saving}
                  className="flex items-center gap-1.5 px-4 py-2 bg-indigo-600 text-white text-sm rounded-xl hover:bg-indigo-700 disabled:opacity-50 transition"
                >
                  {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                  {t("common.save")}
                </button>
              </div>

              <div className="grid grid-cols-12 gap-2 px-5 py-2 border-b border-gray-50 text-xs font-semibold text-gray-400 uppercase tracking-wide">
                <div className="col-span-3">{t("translations.key")}</div>
                <div className="col-span-4">{t("translations.english")}</div>
                <div className="col-span-5">{t("translations.arabic")}</div>
              </div>

              <div className="max-h-[60vh] overflow-y-auto">
                {rows.length === 0 ? (
                  <div className="p-10 text-center text-gray-400 text-sm">{t("translations.noResults")}</div>
                ) : (
                  rows.map((row, idx) => {
                    const edit = edits[row.key];
                    const isModified = !!edit;
                    return (
                      <div
                        key={row.key}
                        className={cn(
                          "grid grid-cols-12 gap-2 px-5 py-2 text-sm items-start border-b border-gray-50",
                          idx % 2 === 0 ? "bg-white" : "bg-gray-50/30",
                          isModified && "border-l-4 border-l-amber-400",
                        )}
                      >
                        <div className="col-span-3 font-mono text-xs text-indigo-600 pt-2 break-all select-all">{row.key}</div>
                        <div className="col-span-4">
                          <textarea
                            defaultValue={row.en}
                            rows={2}
                            onChange={(e) => setEdit(row.key, "en", e.target.value)}
                            className="w-full text-sm border border-gray-200 rounded-lg px-2 py-1.5 resize-none focus:ring-2 focus:ring-indigo-500 outline-none"
                          />
                        </div>
                        <div className="col-span-5" dir="rtl">
                          <textarea
                            defaultValue={row.ar}
                            rows={2}
                            onChange={(e) => setEdit(row.key, "ar", e.target.value)}
                            className="w-full text-sm border border-gray-200 rounded-lg px-2 py-1.5 resize-none text-right focus:ring-2 focus:ring-indigo-500 outline-none"
                          />
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
