"use client";
import { useState, useMemo, useCallback, useRef } from "react";
import { translations, type Lang } from "@/lib/i18n";
import {
  Search, ChevronDown, ChevronUp, Copy, Check, ChevronsDown, ChevronsUp,
  Globe, Pencil, X, RotateCcw, Save, AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import toast from "react-hot-toast";

// ── Category definitions ──────────────────────────────────────────────────────
const CATEGORIES: Record<string, { label: string; labelAr: string; color: string; dot: string }> = {
  brand:        { label: "Brand & App",        labelAr: "الهوية والتطبيق",        color: "bg-violet-50 border-violet-200",   dot: "bg-violet-500" },
  nav:          { label: "Navigation",          labelAr: "التنقل",                 color: "bg-blue-50 border-blue-200",       dot: "bg-blue-500" },
  common:       { label: "Common UI",           labelAr: "واجهة مشتركة",           color: "bg-slate-50 border-slate-200",     dot: "bg-slate-500" },
  auth:         { label: "Authentication",      labelAr: "المصادقة",               color: "bg-pink-50 border-pink-200",       dot: "bg-pink-500" },
  categories:   { label: "Categories Page",     labelAr: "صفحة التصنيفات",         color: "bg-orange-50 border-orange-200",   dot: "bg-orange-500" },
  catForm:      { label: "Category Form",       labelAr: "نموذج التصنيف",          color: "bg-amber-50 border-amber-200",     dot: "bg-amber-500" },
  products:     { label: "Products Page",       labelAr: "صفحة المنتجات",          color: "bg-teal-50 border-teal-200",       dot: "bg-teal-500" },
  prodForm:     { label: "Product Form",        labelAr: "نموذج المنتج",           color: "bg-cyan-50 border-cyan-200",       dot: "bg-cyan-500" },
  supplierProd: { label: "Supplier Products",   labelAr: "منتجات الموردين",         color: "bg-emerald-50 border-emerald-200", dot: "bg-emerald-500" },
  offers:       { label: "Offers",              labelAr: "العروض",                  color: "bg-green-50 border-green-200",     dot: "bg-green-500" },
  users:        { label: "Users Page",          labelAr: "صفحة المستخدمين",         color: "bg-indigo-50 border-indigo-200",   dot: "bg-indigo-500" },
  userForm:     { label: "User Form",           labelAr: "نموذج المستخدم",          color: "bg-purple-50 border-purple-200",   dot: "bg-purple-500" },
  brands:       { label: "Brands Page",         labelAr: "صفحة البراندات",          color: "bg-rose-50 border-rose-200",       dot: "bg-rose-500" },
  brandForm:    { label: "Brand Form",          labelAr: "نموذج البراند",           color: "bg-fuchsia-50 border-fuchsia-200", dot: "bg-fuchsia-500" },
  orders:       { label: "Orders Page",         labelAr: "صفحة الطلبات",           color: "bg-sky-50 border-sky-200",         dot: "bg-sky-500" },
  suppliers:    { label: "Suppliers Page",      labelAr: "صفحة الموردين",           color: "bg-lime-50 border-lime-200",       dot: "bg-lime-500" },
  coupons:      { label: "Coupons Page",        labelAr: "صفحة الكوبونات",          color: "bg-yellow-50 border-yellow-200",   dot: "bg-yellow-500" },
  couponForm:   { label: "Coupon Form",         labelAr: "نموذج الكوبون",           color: "bg-orange-50 border-orange-200",   dot: "bg-orange-400" },
  ads:          { label: "Ads Page",            labelAr: "صفحة الإعلانات",          color: "bg-red-50 border-red-200",         dot: "bg-red-500" },
  adForm:       { label: "Ad Form",             labelAr: "نموذج الإعلان",           color: "bg-pink-50 border-pink-200",       dot: "bg-pink-400" },
  translations: { label: "Translations UI",     labelAr: "واجهة الترجمات",          color: "bg-gray-50 border-gray-200",       dot: "bg-gray-500" },
};

interface TranslationRow { key: string; en: string; ar: string }

function buildGroups(): Record<string, TranslationRow[]> {
  const en = translations.EN;
  const ar = translations.AR;
  const groups: Record<string, TranslationRow[]> = {};
  Object.keys(en).forEach(key => {
    const prefix = key.includes(".") ? key.split(".")[0] : key;
    const group = CATEGORIES[prefix] ? prefix : "other";
    if (!groups[group]) groups[group] = [];
    groups[group].push({ key, en: en[key], ar: ar[key] ?? "" });
  });
  const order = [...Object.keys(CATEGORIES), "other"];
  return Object.fromEntries(order.filter(g => groups[g]).map(g => [g, groups[g]]));
}

const ALL_GROUPS = buildGroups();
const TOTAL_KEYS = Object.values(ALL_GROUPS).reduce((sum, rows) => sum + rows.length, 0);

// ── Page ─────────────────────────────────────────────────────────────────────
export default function TranslationsPage() {
  const { t, lang, overrides, setOverride, resetOverride, clearOverrides } = useT();
  const [search, setSearch]   = useState("");
  const [copied, setCopied]   = useState<string | null>(null);
  const [open, setOpen]       = useState<Set<string>>(new Set(Object.keys(ALL_GROUPS)));
  const [editMode, setEditMode] = useState(false);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const isAr = lang === "AR";

  // Count total overrides across both languages
  const modifiedCount = Object.values(overrides).reduce(
    (sum, langOverrides) => sum + Object.keys(langOverrides).length, 0
  );

  const filtered = useMemo(() => {
    if (!search.trim()) return ALL_GROUPS;
    const q = search.toLowerCase();
    const result: typeof ALL_GROUPS = {};
    Object.entries(ALL_GROUPS).forEach(([group, rows]) => {
      const matched = rows.filter(r =>
        r.key.toLowerCase().includes(q) ||
        r.en.toLowerCase().includes(q) ||
        r.ar.includes(q)
      );
      if (matched.length) result[group] = matched;
    });
    return result;
  }, [search]);

  const filteredTotal = Object.values(filtered).reduce((s, r) => s + r.length, 0);
  const groupCount    = Object.keys(filtered).length;

  function toggleGroup(g: string) {
    setOpen(prev => {
      const next = new Set(prev);
      if (next.has(g)) next.delete(g); else next.add(g);
      return next;
    });
  }
  function collapseAll() { setOpen(new Set()); }
  function expandAll()   { setOpen(new Set(Object.keys(filtered))); }

  const copyKey = useCallback((key: string) => {
    navigator.clipboard.writeText(key).then(() => {
      setCopied(key);
      setTimeout(() => setCopied(null), 1500);
    });
  }, []);

  function handleSave(key: string, enVal: string, arVal: string) {
    const baseEn = translations.EN[key] ?? "";
    const baseAr = translations.AR[key] ?? "";
    if (enVal !== baseEn) setOverride("EN", key, enVal);
    else resetOverride("EN", key);
    if (arVal !== baseAr) setOverride("AR", key, arVal);
    else resetOverride("AR", key);
    setEditingKey(null);
    toast.success("Saved!");
  }

  function handleReset(key: string) {
    resetOverride("EN", key);
    resetOverride("AR", key);
    toast.success("Reset to default");
  }

  function handleClearAll() {
    clearOverrides();
    setConfirmReset(false);
    toast.success("All overrides cleared");
  }

  return (
    <div className="p-6 space-y-6">

      {/* ── Header ── */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Globe size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("translations.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("translations.subtitle")}</p>
        </div>

        <div className="flex items-center gap-3 flex-wrap">
          {/* Stats */}
          <div className="bg-indigo-50 border border-indigo-100 rounded-xl px-4 py-2 text-center">
            <p className="text-2xl font-bold text-indigo-700">{TOTAL_KEYS}</p>
            <p className="text-xs text-indigo-400">{t("translations.totalKeys")}</p>
          </div>
          {modifiedCount > 0 && (
            <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-2 text-center">
              <p className="text-2xl font-bold text-amber-600">{modifiedCount}</p>
              <p className="text-xs text-amber-500">{t("translations.modified")}</p>
            </div>
          )}
          {/* Edit mode toggle */}
          <button
            onClick={() => { setEditMode(v => !v); setEditingKey(null); }}
            className={cn(
              "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium border transition",
              editMode
                ? "bg-indigo-600 text-white border-indigo-600 hover:bg-indigo-700"
                : "bg-white text-gray-700 border-gray-300 hover:bg-gray-50"
            )}>
            <Pencil size={15} />
            {t("translations.editMode")}
          </button>
          {modifiedCount > 0 && (
            <button
              onClick={() => setConfirmReset(true)}
              className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm border border-red-200 text-red-600 hover:bg-red-50 transition">
              <RotateCcw size={14} />
              {t("translations.resetAll")}
            </button>
          )}
        </div>
      </div>

      {/* ── Edit mode info bar ── */}
      {editMode && (
        <div className="flex items-start gap-3 bg-indigo-50 border border-indigo-200 rounded-xl px-4 py-3 text-sm text-indigo-700">
          <AlertCircle size={16} className="shrink-0 mt-0.5" />
          <span>{t("translations.overridesNote")}</span>
        </div>
      )}

      {/* ── Reset confirm ── */}
      {confirmReset && (
        <div className="flex items-center gap-4 bg-red-50 border border-red-200 rounded-xl px-5 py-3">
          <span className="text-sm text-red-700 flex-1">Reset all {modifiedCount} override(s)?</span>
          <button onClick={handleClearAll} className="px-4 py-1.5 bg-red-600 text-white text-sm rounded-lg hover:bg-red-700 transition">
            {t("common.yes")}, Reset All
          </button>
          <button onClick={() => setConfirmReset(false)} className="px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900">
            {t("common.cancel")}
          </button>
        </div>
      )}

      {/* ── Search & Controls ── */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[260px]">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder={t("translations.searchPlaceholder")}
            className="w-full pl-9 pr-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
          />
          {search && (
            <button onClick={() => setSearch("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">×</button>
          )}
        </div>
        {search && (
          <span className="text-sm text-gray-500 bg-gray-100 px-3 py-1.5 rounded-lg">
            {filteredTotal} / {TOTAL_KEYS}
          </span>
        )}
        <div className="flex items-center gap-1 ml-auto">
          <button onClick={expandAll}
            className="flex items-center gap-1.5 px-3 py-2 text-xs border border-gray-300 rounded-lg hover:bg-gray-50 transition text-gray-600">
            <ChevronsDown size={13} /> {t("translations.expandAll")}
          </button>
          <button onClick={collapseAll}
            className="flex items-center gap-1.5 px-3 py-2 text-xs border border-gray-300 rounded-lg hover:bg-gray-50 transition text-gray-600">
            <ChevronsUp size={13} /> {t("translations.collapseAll")}
          </button>
        </div>
      </div>

      {/* ── No results ── */}
      {groupCount === 0 && (
        <div className="text-center py-20 border-2 border-dashed border-gray-200 rounded-2xl">
          <Globe size={36} className="text-gray-300 mx-auto mb-3" />
          <p className="text-gray-400">{t("translations.noResults")}</p>
          <button onClick={() => setSearch("")} className="mt-3 text-sm text-indigo-600 hover:underline">
            {t("common.cancel")}
          </button>
        </div>
      )}

      {/* ── Groups ── */}
      <div className="space-y-4">
        {Object.entries(filtered).map(([group, rows]) => {
          const meta  = CATEGORIES[group] ?? { label: group, labelAr: group, color: "bg-gray-50 border-gray-200", dot: "bg-gray-400" };
          const label = isAr ? meta.labelAr : meta.label;
          const isOpen = open.has(group);
          const groupModified = rows.filter(r => overrides.EN?.[r.key] || overrides.AR?.[r.key]).length;

          return (
            <div key={group} className={cn("border rounded-2xl overflow-hidden", meta.color)}>
              <button
                onClick={() => toggleGroup(group)}
                className="w-full flex items-center justify-between px-5 py-3.5 hover:brightness-95 transition text-left">
                <div className="flex items-center gap-3">
                  <span className={cn("w-2.5 h-2.5 rounded-full shrink-0", meta.dot)} />
                  <span className="font-semibold text-gray-800 text-sm">{label}</span>
                  <span className="text-xs bg-white/70 border border-white/50 text-gray-500 px-2 py-0.5 rounded-full font-medium">
                    {rows.length}
                  </span>
                  {groupModified > 0 && (
                    <span className="text-xs bg-amber-100 text-amber-700 border border-amber-200 px-2 py-0.5 rounded-full font-medium">
                      {groupModified} edited
                    </span>
                  )}
                </div>
                {isOpen
                  ? <ChevronUp size={16} className="text-gray-400 shrink-0" />
                  : <ChevronDown size={16} className="text-gray-400 shrink-0" />}
              </button>

              {isOpen && (
                <div className="bg-white border-t border-gray-100">
                  <div className={cn(
                    "grid gap-2 px-5 py-2 border-b border-gray-50 text-xs font-semibold text-gray-400 uppercase tracking-wide",
                    editMode ? "grid-cols-12" : "grid-cols-12"
                  )}>
                    <div className="col-span-3">{t("translations.key")}</div>
                    <div className={editMode ? "col-span-4" : "col-span-4"}>{t("translations.english")}</div>
                    <div className={editMode ? "col-span-4" : "col-span-4"}>{t("translations.arabic")}</div>
                    <div className="col-span-1" />
                  </div>
                  {rows.map((row, idx) => (
                    <TRow
                      key={row.key}
                      row={row}
                      idx={idx}
                      isCopied={copied === row.key}
                      onCopy={() => copyKey(row.key)}
                      search={search}
                      editMode={editMode}
                      isEditing={editingKey === row.key}
                      onEdit={() => setEditingKey(row.key)}
                      onCancel={() => setEditingKey(null)}
                      onSave={(enVal, arVal) => handleSave(row.key, enVal, arVal)}
                      onReset={() => handleReset(row.key)}
                      enOverride={overrides.EN?.[row.key]}
                      arOverride={overrides.AR?.[row.key]}
                    />
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── TRow ──────────────────────────────────────────────────────────────────────
function TRow({
  row, idx, isCopied, onCopy, search, editMode, isEditing,
  onEdit, onCancel, onSave, onReset, enOverride, arOverride,
}: {
  row: TranslationRow; idx: number;
  isCopied: boolean; onCopy: () => void; search: string;
  editMode: boolean; isEditing: boolean;
  onEdit: () => void; onCancel: () => void;
  onSave: (en: string, ar: string) => void;
  onReset: () => void;
  enOverride?: string; arOverride?: string;
}) {
  const enRef = useRef<HTMLTextAreaElement>(null);
  const arRef = useRef<HTMLTextAreaElement>(null);
  const isModified = !!(enOverride !== undefined || arOverride !== undefined);

  const displayEn = enOverride ?? row.en;
  const displayAr = arOverride ?? row.ar;

  function handleSaveClick() {
    const enVal = enRef.current?.value ?? displayEn;
    const arVal = arRef.current?.value ?? displayAr;
    onSave(enVal, arVal);
  }

  if (isEditing) {
    return (
      <div className={cn(
        "px-5 py-3 border-b border-gray-100 border-l-4 border-l-indigo-400 bg-indigo-50/30",
      )}>
        <div className="grid grid-cols-12 gap-3 mb-3">
          <div className="col-span-3 font-mono text-xs text-indigo-600 pt-1 select-all truncate" title={row.key}>
            {row.key}
          </div>
          <div className="col-span-4">
            <textarea
              ref={enRef}
              defaultValue={displayEn}
              rows={2}
              className="w-full text-sm border border-indigo-300 rounded-lg px-3 py-2 resize-none focus:ring-2 focus:ring-indigo-500 outline-none"
              placeholder="English…"
            />
          </div>
          <div className="col-span-4" dir="rtl">
            <textarea
              ref={arRef}
              defaultValue={displayAr}
              rows={2}
              className="w-full text-sm border border-indigo-300 rounded-lg px-3 py-2 resize-none focus:ring-2 focus:ring-indigo-500 outline-none text-right"
              placeholder="Arabic…"
            />
          </div>
          <div className="col-span-1" />
        </div>
        <div className="flex items-center gap-2 ps-[25%]">
          <button onClick={handleSaveClick}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-600 text-white text-xs rounded-lg hover:bg-indigo-700 transition">
            <Save size={12} /> Save
          </button>
          {isModified && (
            <button onClick={onReset}
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs border border-amber-300 text-amber-700 rounded-lg hover:bg-amber-50 transition">
              <RotateCcw size={12} /> Reset
            </button>
          )}
          <button onClick={onCancel}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs text-gray-500 hover:text-gray-800 transition">
            <X size={12} /> Cancel
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={cn(
      "grid grid-cols-12 gap-2 px-5 py-2.5 text-sm items-start border-b border-gray-50 group hover:bg-indigo-50/40 transition-colors",
      idx % 2 === 0 ? "bg-white" : "bg-gray-50/30",
      isModified && "border-l-4 border-l-amber-400",
    )}>
      {/* Key */}
      <div className="col-span-3 font-mono text-xs text-indigo-600 truncate pt-0.5 select-all flex items-center gap-1.5" title={row.key}>
        <Highlight text={row.key} q={search} />
        {isModified && (
          <span className="text-[10px] bg-amber-100 text-amber-600 px-1.5 py-0.5 rounded font-medium shrink-0">
            edited
          </span>
        )}
      </div>

      {/* English */}
      <div className="col-span-4 text-gray-800 leading-relaxed">
        <Highlight text={displayEn} q={search} />
        {enOverride !== undefined && (
          <div className="text-[11px] text-gray-400 line-through mt-0.5">{row.en}</div>
        )}
      </div>

      {/* Arabic */}
      <div className="col-span-4 text-gray-700 leading-relaxed text-right" dir="rtl">
        <Highlight text={displayAr} q={search} />
        {arOverride !== undefined && (
          <div className="text-[11px] text-gray-400 line-through mt-0.5">{row.ar}</div>
        )}
      </div>

      {/* Actions */}
      <div className="col-span-1 flex justify-end items-center gap-1 pt-0.5">
        {editMode && (
          <button
            onClick={onEdit}
            title="Edit"
            className="p-1.5 rounded-lg text-gray-300 hover:text-indigo-600 hover:bg-indigo-50 transition opacity-0 group-hover:opacity-100">
            <Pencil size={13} />
          </button>
        )}
        <button
          onClick={onCopy}
          title="Copy key"
          className={cn(
            "p-1.5 rounded-lg text-gray-300 hover:text-indigo-600 hover:bg-indigo-50 transition opacity-0 group-hover:opacity-100",
            isCopied && "text-green-600 opacity-100"
          )}>
          {isCopied ? <Check size={13} /> : <Copy size={13} />}
        </button>
      </div>
    </div>
  );
}

// ── Highlight ─────────────────────────────────────────────────────────────────
function Highlight({ text, q }: { text: string; q: string }) {
  if (!q.trim() || !text) return <>{text}</>;
  const idx = text.toLowerCase().indexOf(q.toLowerCase());
  if (idx === -1) return <>{text}</>;
  return (
    <>
      {text.slice(0, idx)}
      <mark className="bg-yellow-200 text-yellow-900 rounded px-0.5">{text.slice(idx, idx + q.length)}</mark>
      {text.slice(idx + q.length)}
    </>
  );
}
