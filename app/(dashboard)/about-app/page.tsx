"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { fetchAboutApp, updateAboutApp, type AboutApp } from "@/lib/about-app";
import { useT } from "@/contexts/LanguageContext";
import { Info, RefreshCw, Save, Pencil } from "lucide-react";
import toast from "react-hot-toast";
import RichTextEditor from "@/components/ui/rich-text-editor";

type Tab = "contact" | "social" | "content" | "policies";

const FIELD_CONFIGS: any = {
  contact: [
    { key: "phone", type: "text" },
    { key: "email", type: "text" },
    { key: "whatsapp", type: "text" },
    { key: "customer_support_number", type: "text" },
    { key: "vodafon_cash_number", type: "text" },
    { key: "instapay_number", type: "text" },
  ],
  social: [
    { key: "facebook", type: "text" },
    { key: "youtube", type: "text" },
    { key: "instagram", type: "text" },
    { key: "twitter", type: "text" },
    { key: "tiktok", type: "text" },
    { key: "snapchat", type: "text" },
    { key: "pinterest", type: "text" },
    { key: "linkedin", type: "text" },
    { key: "reddit", type: "text" },
    { key: "telegram", type: "text" },
  ],
  content: [
    { key: "about", type: "bilingual" },
    { key: "mission", type: "bilingual" },
    { key: "vision", type: "bilingual" },
    { key: "digital_card", type: "bilingual" },
    { key: "delete_account", type: "bilingual" },
  ],
  policies: [
    { key: "terms", type: "bilingual", rows: 8 },
    { key: "privacy_policy", type: "bilingual", rows: 8 },
    { key: "courier_terms", type: "bilingual", rows: 8 },
    { key: "courier_privacy_policy", type: "bilingual", rows: 8 },
  ],
};

// All keys defined in FIELD_CONFIGS (including _ar versions for bilingual)
const KNOWN_KEYS = new Set([
  "id", "created_at", "updated_at",
  ...FIELD_CONFIGS.contact.map((f: any) => f.key),
  ...FIELD_CONFIGS.social.map((f: any) => f.key),
  ...FIELD_CONFIGS.content.flatMap((f: any) => [f.key, `${f.key}_ar`]),
  ...FIELD_CONFIGS.policies.flatMap((f: any) => [f.key, `${f.key}_ar`]),
]);
export default function AboutAppPage() {
  const { t } = useT();
  const [tab, setTab] = useState<Tab>("contact");
  const [form, setForm] = useState<Partial<AboutApp>>({});
  const [original, setOriginal] = useState<Partial<AboutApp>>({});
  const [dirty, setDirty] = useState(false);
  const [editMode, setEditMode] = useState(false);
  const [touchedFields, setTouchedFields] = useState<Set<string>>(new Set());

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["about-app"],
    queryFn: fetchAboutApp,
    staleTime: 5 * 60 * 1000,
  });

  useEffect(() => {
    if (data) {
      setForm(data);
      setOriginal(data);
      setDirty(false);
      setEditMode(false);
      setTouchedFields(new Set());
    }
  }, [data]);

  const mut = useMutation({
    mutationFn: () => {
      const payload: any = {};
      touchedFields.forEach(key => {
        payload[key] = (form as any)[key];
      });
      console.log("Updating About App with modified fields:", payload);
      return updateAboutApp(payload);
    },
    onSuccess: () => {
      toast.success(t("aboutApp.saved"));
      setOriginal(form);
      setDirty(false);
      setTouchedFields(new Set());
      setEditMode(false);
      refetch();
    },
    onError: () => toast.error(t("aboutApp.saveFailed")),
  });

  function set<K extends keyof AboutApp>(key: K, value: AboutApp[K]) {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setTouchedFields(prev => new Set(prev).add(key as string));
  }

  const TABS: { key: Tab; label: string }[] = [
    { key: "contact", label: t("aboutApp.tabContact") },
    { key: "social", label: t("aboutApp.tabSocial") },
    { key: "content", label: t("aboutApp.tabContent") },
    { key: "policies", label: t("aboutApp.tabPolicies") },
  ];

  const isFieldChanged = (key: string) => touchedFields.has(key) && (form as any)[key] !== (original as any)[key];

  const formatLabel = (label: string) => {
    return label.toLowerCase();
  };

  const renderField = (config: any) => {
    const changed = isFieldChanged(config.key);
    const displayLabel = formatLabel(config.key);

    if (config.type === "bilingual") {
      const changedAr = isFieldChanged(`${config.key}_ar`);
      return (
        <BilingualTA
          key={config.key}
          label={displayLabel}
          enVal={(form as any)[config.key] ?? ""}
          arVal={(form as any)[`${config.key}_ar`] ?? ""}
          onEnChange={v => set(config.key as keyof AboutApp, v)}
          onArChange={v => set(`${config.key}_ar` as keyof AboutApp, v)}
          rows={config.rows}
          disabled={!editMode}
          changed={changed}
          changedAr={changedAr}
        />
      );
    }

    return (
      <TF
        key={config.key}
        label={displayLabel}
        value={(form as any)[config.key] ?? ""}
        onChange={v => set(config.key as keyof AboutApp, v)}
        disabled={!editMode}
        changed={changed}
      />
    );
  };

  const renderDynamicFields = (currentConfig: any) => {
    if (!data) return null;
    if (tab !== "contact") return null;

    const dynamicKeys = Object.keys(data).filter(key => !KNOWN_KEYS.has(key));
    if (dynamicKeys.length === 0) return null;

    return (
      <>
        <div className="col-span-full mt-6 mb-2">
          <h3 className="text-xs font-bold text-gray-400 uppercase tracking-widest">{t("settings.otherSettings")}</h3>
          <div className="h-px bg-gray-100 w-full mt-2"></div>
        </div>
        {dynamicKeys.map(key => renderField({ key, type: "text" }))}
      </>
    );
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Info size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("aboutApp.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("aboutApp.subtitle")}</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => refetch()} disabled={isFetching}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
            <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
            {t("common.refresh")}
          </button>
          
          <button 
            onClick={() => {
              if (editMode) {
                setForm(original);
                setDirty(false);
                setTouchedFields(new Set());
              }
              setEditMode(!editMode);
            }}
            className={`flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-medium transition ${editMode ? "bg-amber-50 text-amber-700 border border-amber-200" : "bg-gray-100 text-gray-700 hover:bg-gray-200"}`}
          >
            {editMode ? <RefreshCw size={15} /> : <Pencil size={15} />}
            {editMode ? t("common.cancel") : t("common.edit")}
          </button>

          <button 
            onClick={() => mut.mutate()} 
            disabled={!dirty || mut.isPending || !editMode}
            className="flex items-center gap-2 px-5 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
          >
            <Save size={15} />
            {mut.isPending ? t("common.saving") : t("common.saveChanges")}
          </button>
        </div>
      </div>

      {isLoading && (
        <div className="h-64 flex items-center justify-center">
          <RefreshCw size={24} className="animate-spin text-gray-400" />
        </div>
      )}

      {!isLoading && (
        <>
          <div className="flex border-b border-gray-200 gap-1 flex-wrap">
            {TABS.map(({ key, label }) => (
              <button key={key} onClick={() => setTab(key)}
                className={`px-5 py-2.5 text-sm font-medium border-b-2 transition ${tab === key ? "border-indigo-600 text-indigo-600" : "border-transparent text-gray-500 hover:text-gray-700"}`}>
                {label}
              </button>
            ))}
          </div>

          <div className="bg-white rounded-2xl border border-gray-200 p-6 shadow-sm space-y-5 max-w-4xl">
            {tab === "contact" && (
              <FieldGrid>
                {FIELD_CONFIGS.contact.map(renderField)}
                {renderDynamicFields(FIELD_CONFIGS.contact)}
              </FieldGrid>
            )}

            {tab === "social" && (
              <FieldGrid>
                {FIELD_CONFIGS.social.map(renderField)}
                {renderDynamicFields(FIELD_CONFIGS.social)}
              </FieldGrid>
            )}

            {tab === "content" && (
              <div className="space-y-6">
                {FIELD_CONFIGS.content.map(renderField)}
                <FieldGrid>
                  {renderDynamicFields(FIELD_CONFIGS.content)}
                </FieldGrid>
              </div>
            )}

            {tab === "policies" && (
              <div className="space-y-6">
                {FIELD_CONFIGS.policies.map(renderField)}
                <FieldGrid>
                  {renderDynamicFields(FIELD_CONFIGS.policies)}
                </FieldGrid>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

function FieldGrid({ children }: { children: React.ReactNode }) {
  return <div className="grid grid-cols-1 md:grid-cols-2 gap-5">{children}</div>;
}

function TF({ label, value, onChange, disabled, changed }: { label: string; value: string; onChange: (v: string) => void; disabled?: boolean; changed?: boolean }) {
  return (
    <div className="space-y-1.5 group">
      <label className={`text-xs font-semibold transition-colors ${changed ? "text-indigo-600" : "text-gray-500"}`}>
        {label}
        {changed && <span className="ml-1 text-[10px] bg-indigo-100 text-indigo-600 px-1.5 py-0.5 rounded-full font-bold">MODIFIED</span>}
      </label>
      <input 
        type="text" 
        value={value} 
        onChange={e => onChange(e.target.value)} 
        disabled={disabled}
        className={`input w-full transition-all ${disabled ? "bg-gray-50 text-gray-400 border-gray-200" : ""} ${changed ? "border-indigo-300 ring-2 ring-indigo-50 bg-indigo-50/20" : ""}`} 
      />
    </div>
  );
}

function BilingualTA({
  label, enVal, arVal, onEnChange, onArChange, rows = 4, disabled, changed, changedAr
}: { 
  label: string; enVal: string; arVal: string; onEnChange: (v: string) => void; onArChange: (v: string) => void; 
  rows?: number; disabled?: boolean; changed?: boolean; changedAr?: boolean 
}) {
  return (
    <div className={`space-y-3 p-4 rounded-2xl transition-all ${changed || changedAr ? "bg-indigo-50/30 ring-1 ring-indigo-100" : ""}`}>
      <div className="flex items-center gap-2">
        <h4 className={`text-xs font-bold uppercase tracking-wider ${changed || changedAr ? "text-indigo-600" : "text-gray-500"}`}>{label}</h4>
        {(changed || changedAr) && <span className="text-[10px] bg-indigo-100 text-indigo-600 px-1.5 py-0.5 rounded-full font-bold">MODIFIED</span>}
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className={`space-y-1.5 rounded-xl transition-all ${changed ? "ring-2 ring-indigo-100 p-1" : ""}`}>
          <label className="text-[10px] font-medium text-gray-400 uppercase">English</label>
          <RichTextEditor
            value={enVal}
            onChange={onEnChange}
            disabled={disabled}
            dir="ltr"
            minHeight={(rows ?? 4) * 28}
            placeholder="—"
          />
        </div>
        <div className={`space-y-1.5 rounded-xl transition-all ${changedAr ? "ring-2 ring-indigo-100 p-1" : ""}`}>
          <label className="text-[10px] font-medium text-gray-400 uppercase">العربية</label>
          <RichTextEditor
            value={arVal}
            onChange={onArChange}
            disabled={disabled}
            dir="rtl"
            minHeight={(rows ?? 4) * 28}
            placeholder="—"
          />
        </div>
      </div>
    </div>
  );
}
