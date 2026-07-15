"use client";
import { useState, useEffect, useMemo } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import {
  fetchSettings,
  updateSettings,
  type AppSettings,
} from "@/lib/settings";
import { useT } from "@/contexts/LanguageContext";
import {
  Settings as SettingsIcon,
  RefreshCw,
  Save,
  Pencil,
  CreditCard,
  CheckCircle2,
  XCircle,
} from "lucide-react";
import toast from "react-hot-toast";

type Tab =
  | "general"
  | "delivery"
  | "security"
  | "points"
  | "apps"
  | "payments"
  | "tokens"
  | "customer_home_products";

interface FieldConfig {
  key: string;
  label: string;
  type: "number" | "text" | "boolean";
  note?: string;
  section?: string;
}

const FIELD_CONFIGS: any = {
  general: [
    { key: "vat", type: "number" },
    { key: "cancellation_fee_ratio", type: "number" },
    { key: "courier_cancellation_fee_ratio", type: "number" },
    { key: "seller_commission_per_order", type: "number" },
    { key: "seller_commission_per_courier_download", type: "number" },
    { key: "seller_commission_per_customer_download", type: "number" },
    { key: "courier_max_selected_areas", type: "number" },
    { key: "proposal_waiting_time_minutes", type: "number" },
    { key: "order_expiration_time_minutes", type: "number" },
    { key: "max_order_retry_count", type: "number" },
    { key: "min_platform_fee", type: "number", note: "stored in cents" },
    { key: "skip_otp", type: "boolean" },
    { key: "login_as_guest", type: "boolean" },
    { key: "permanent_delete", type: "boolean" },
    { key: "live_payment", type: "boolean" },
    { key: "chat_enable_send_images", type: "boolean" },
  ],
  delivery: [
    { key: "min_delivery_distance", type: "text" },
    { key: "min_delivery_fee", type: "number", cents: true, note: "in EGP" },
    { key: "delivery_price_for_each_1km", type: "number" },
    { key: "delivery_fee_ratio", type: "number" },
    {
      key: "customer_budget_cash_on_delivery_limit",
      type: "number",
      cents: true,
      note: "in EGP",
    },
    { key: "max_orders_per_trip", type: "number" },
  ],
  customer_shopping: [
    {
      key: "customer_shopping_min_price_for_one_order",
      type: "number",
      cents: true,
      note: "in EGP",
    },
    {
      key: "customer_shopping_max_price_for_one_order",
      type: "number",
      cents: true,
      note: "in EGP",
    },
  ],
  fee_base: [
    { key: "fee_base_distance_km", type: "number" },
    { key: "fee_base_platform_cents", type: "number" },
    { key: "fee_base_courier_cents", type: "number" },
    { key: "fee_extra_platform_per_km", type: "number" },
    { key: "fee_extra_courier_per_km", type: "number" },
    { key: "peak_time_fee_ratio", type: "number" },
  ],
  security: [
    { key: "login_attempts", type: "number" },
    { key: "login_attempt_duration_minutes", type: "number" },
    { key: "register_attempts", type: "number" },
    { key: "register_attempt_duration_minutes", type: "number" },
    { key: "update_password_attempts", type: "number" },
    { key: "update_password_attempt_duration_minutes", type: "number" },
    { key: "forget_password_attempts", type: "number" },
    { key: "forget_password_attempt_duration_minutes", type: "number" },
    { key: "verify_account_attempt_duration_minutes", type: "number" },
    { key: "verify_account_attempts", type: "number" },
    { key: "change_account_attempt_duration_minutes", type: "number" },
    { key: "change_account_attempts", type: "number" },
    { key: "change_account_freeze_threshold", type: "number" },
    { key: "change_account_freeze_window_days", type: "number" },
    { key: "global_api_attempts", type: "number" },
    { key: "global_api_duration_minutes", type: "number" },
    { key: "otp_length", type: "number" },
    { key: "otp_resend_duration_seconds", type: "number" },
    { key: "otp_validity_duration_minutes", type: "number" },
  ],
  points: {
    courier: [
      { key: "courier_number_of_points_required_per_1egp", type: "number" },
      {
        key: "courier_number_of_delivered_orders_required_per_reward_batch",
        type: "number",
      },
      {
        key: "courier_number_of_points_awarded_per_completed_order_batch",
        type: "number",
      },
      { key: "courier_points_validity_days", type: "number" },
      { key: "courier_points_minimum_rating_threshold", type: "number" },
      { key: "courier_points_expiration_notification_days", type: "number" },
    ],
    customer: [
      { key: "customer_number_of_points_required_per_1egp", type: "number" },
      {
        key: "customer_number_of_delivered_orders_required_per_reward_batch",
        type: "number",
      },
      {
        key: "customer_number_of_points_awarded_per_completed_order_batch",
        type: "number",
      },
      { key: "customer_points_validity_days", type: "number" },
      { key: "customer_points_minimum_rating_threshold", type: "number" },
      { key: "customer_points_expiration_notification_days", type: "number" },
      {
        key: "customer_points_cashback_percentage_per_orders_batch",
        type: "number",
      },
    ],
  },
  apps: [
    { key: "app_android_url", type: "text" },
    { key: "app_android_version", type: "text" },
    { key: "app_ios_url", type: "text" },
    { key: "app_ios_version", type: "text" },
    { key: "courier_app_url_android", type: "text" },
    { key: "courier_app_version_android", type: "text" },
    { key: "courier_app_url_ios", type: "text" },
    { key: "courier_app_version_ios", type: "text" },
  ],
  tokens: [
    { key: "courier_access_token_expires_in", type: "text" },
    { key: "courier_refresh_token_expires_in", type: "text" },
    { key: "supplier_access_token_expires_in", type: "text" },
    { key: "supplier_refresh_token_expires_in", type: "text" },
  ],
  customer_home_products: [
    { key: "customer_home_products_radius_km", type: "number" },
    { key: "customer_home_products_same_governorate", type: "boolean" },
    { key: "customer_home_products_cheapest_per_product", type: "boolean" },
    { key: "home_categories_grid_limit", type: "number" },
  ],
};

export default function SettingsPage() {
  const { t } = useT();
  const [tab, setTab] = useState<Tab>("general");
  const [form, setForm] = useState<Partial<AppSettings>>({});
  const [original, setOriginal] = useState<Partial<AppSettings>>({});
  const [dirty, setDirty] = useState(false);
  const [editMode, setEditMode] = useState(false);
  const [touchedFields, setTouchedFields] = useState<Set<string>>(new Set());

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["app-settings"],
    queryFn: fetchSettings,
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
      const allConfigs = [
        ...FIELD_CONFIGS.general,
        ...FIELD_CONFIGS.delivery,
        ...FIELD_CONFIGS.customer_shopping,
        ...FIELD_CONFIGS.fee_base,
        ...FIELD_CONFIGS.security,
        ...FIELD_CONFIGS.points.courier,
        ...FIELD_CONFIGS.points.customer,
        ...FIELD_CONFIGS.apps,
        ...FIELD_CONFIGS.tokens,
        ...FIELD_CONFIGS.customer_home_products,
      ];

      const gatewayKeys = [
        "paymob_enabled",
        "kashier_enabled",
        "easykash_enabled",
      ];

      touchedFields.forEach((key) => {
        let val = form[key as keyof AppSettings];
        const config = allConfigs.find((c) => c.key === key);

        if (gatewayKeys.includes(key) || config?.type === "boolean") {
          payload[key] = Boolean(val);
        } else if (config?.type === "number") {
          payload[key] = val === null || val === "" ? null : Number(val);
        } else {
          payload[key] = val;
        }
      });

      console.log("Updating settings with sanitized fields:", payload);
      return updateSettings(payload);
    },
    onSuccess: () => {
      toast.success(t("settings.saved"));
      setOriginal(form);
      setDirty(false);
      setTouchedFields(new Set());
      setEditMode(false);
      refetch();
    },
    onError: () => toast.error(t("settings.saveFailed")),
  });

  function set<K extends keyof AppSettings>(key: K, value: AppSettings[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
    setDirty(true);
    setTouchedFields((prev) => new Set(prev).add(key as string));
  }

  const TABS: { key: Tab; label: string }[] = [
    { key: "general", label: t("settings.tabGeneral") },
    { key: "delivery", label: t("settings.tabDelivery") },
    { key: "security", label: t("settings.tabSecurity") },
    { key: "points", label: t("settings.tabPoints") },
    { key: "apps", label: t("settings.tabApps") },
    { key: "payments", label: "Payments" },
    { key: "tokens", label: t("settings.tabTokens") },
    { key: "customer_home_products", label: "Customer Home Products" },
  ];

  const allKnownKeys = useMemo(() => {
    const keys = new Set<string>();
    Object.values(FIELD_CONFIGS).forEach((config: any) => {
      if (Array.isArray(config)) {
        config.forEach((f) => keys.add(f.key));
      } else {
        Object.values(config).forEach((subConfig: any) => {
          if (Array.isArray(subConfig)) {
            subConfig.forEach((f) => keys.add(f.key));
          }
        });
      }
    });
    return keys;
  }, []);

  const dynamicFields = useMemo(() => {
    if (!data) return [];
    const internalKeys = ["id", "created_at", "updated_at", "last_attempt"];
    return Object.keys(data).filter(
      (key) => !allKnownKeys.has(key) && !internalKeys.includes(key),
    );
  }, [data, allKnownKeys]);

  const isFieldChanged = (key: string) =>
    touchedFields.has(key) &&
    form[key as keyof typeof form] !== original[key as keyof typeof original];

  const formatLabel = (label: string) => {
    // Return the raw key name in lowercase
    return label.toLowerCase();
  };

  const renderField = (config: {
    key: string;
    type: string;
    note?: string;
    cents?: boolean;
  }) => {
    const value = form[config.key as keyof AppSettings];
    const changed = isFieldChanged(config.key);

    // Always use the backend key name as the basis for the label
    const displayLabel = formatLabel(config.key);

    if (config.type === "boolean") {
      return (
        <ToggleField
          key={config.key}
          label={displayLabel}
          value={!!value}
          onChange={(v) => set(config.key as keyof AppSettings, v)}
          disabled={!editMode}
          changed={changed}
        />
      );
    }
    if (config.type === "text") {
      return (
        <TextField
          key={config.key}
          label={displayLabel}
          value={(value as string) ?? ""}
          onChange={(v) => set(config.key as keyof AppSettings, v)}
          disabled={!editMode}
          changed={changed}
        />
      );
    }
    if (config.cents) {
      const egpValue =
        value === null || value === undefined || (value as any) === ""
          ? (value as any)
          : Number(value) / 100;
      return (
        <NumField
          key={config.key}
          label={displayLabel}
          value={egpValue as number | null | undefined}
          onChange={(v) =>
            set(
              config.key as keyof AppSettings,
              (v === null ? null : Math.round(v * 100)) as any,
            )
          }
          note={config.note}
          disabled={!editMode}
          changed={changed}
        />
      );
    }
    return (
      <NumField
        key={config.key}
        label={displayLabel}
        value={value as number | null | undefined}
        onChange={(v) => set(config.key as keyof AppSettings, v)}
        note={config.note}
        disabled={!editMode}
        changed={changed}
      />
    );
  };

  const renderDynamicFields = (currentConfig: any) => {
    // Only render dynamic fields in General tab to avoid duplicates, or if requested by user logic
    if (currentConfig !== FIELD_CONFIGS.general) return null;

    if (dynamicFields.length === 0) return null;

    return (
      <>
        <div className="col-span-full mt-6 mb-2">
          <h3 className="text-sm font-bold text-gray-400 uppercase tracking-widest">
            {t("settings.otherSettings")}
          </h3>
          <div className="h-px bg-gray-100 w-full mt-2"></div>
        </div>
        {dynamicFields.map((key) => {
          const val = (data as any)[key];
          const type =
            typeof val === "boolean"
              ? "boolean"
              : typeof val === "number"
                ? "number"
                : "text";
          return renderField({ key, type: type as any });
        })}
      </>
    );
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <SettingsIcon size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("settings.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">{t("settings.subtitle")}</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50"
          >
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
              <button
                key={key}
                onClick={() => setTab(key)}
                className={`px-5 py-2.5 text-sm font-medium border-b-2 transition ${tab === key ? "border-indigo-600 text-indigo-600" : "border-transparent text-gray-500 hover:text-gray-700"}`}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="bg-white rounded-2xl border border-gray-200 p-6 shadow-sm space-y-5 max-w-4xl">
            {tab === "general" && (
              <FieldGrid>
                {FIELD_CONFIGS.general.map(renderField)}
                {renderDynamicFields(FIELD_CONFIGS.general)}
              </FieldGrid>
            )}

            {tab === "delivery" && (
              <div className="space-y-6">
                <Section title={t("settings.tabDelivery")}>
                  {FIELD_CONFIGS.delivery.map(renderField)}
                </Section>
                <Section title={t("settings.feeBaseDistance")}>
                  {FIELD_CONFIGS.fee_base.map(renderField)}
                </Section>
                <Section title="customer shopping">
                  {FIELD_CONFIGS.customer_shopping.map(renderField)}
                </Section>
                <FieldGrid>
                  {renderDynamicFields([
                    ...FIELD_CONFIGS.delivery,
                    ...FIELD_CONFIGS.fee_base,
                  ])}
                </FieldGrid>
              </div>
            )}

            {tab === "security" && (
              <FieldGrid>
                {FIELD_CONFIGS.security.map(renderField)}
                {renderDynamicFields(FIELD_CONFIGS.security)}
              </FieldGrid>
            )}

            {tab === "points" && (
              <div className="space-y-6">
                <Section title={t("settings.courierPoints")}>
                  {FIELD_CONFIGS.points.courier.map(renderField)}
                </Section>
                <Section title={t("settings.customerPoints")}>
                  {FIELD_CONFIGS.points.customer.map(renderField)}
                </Section>
                <FieldGrid>
                  {renderDynamicFields(FIELD_CONFIGS.points)}
                </FieldGrid>
              </div>
            )}

            {tab === "apps" && (
              <FieldGrid>
                {FIELD_CONFIGS.apps.map(renderField)}
                {renderDynamicFields(FIELD_CONFIGS.apps)}
              </FieldGrid>
            )}

            {tab === "tokens" && (
              <FieldGrid>
                {FIELD_CONFIGS.tokens.map(renderField)}
                {renderDynamicFields(FIELD_CONFIGS.tokens)}
              </FieldGrid>
            )}

            {tab === "customer_home_products" && (
              <FieldGrid>
                {FIELD_CONFIGS.customer_home_products.map(renderField)}
              </FieldGrid>
            )}

            {tab === "payments" && (
              <div className="grid gap-3">
                <div className="flex items-center gap-2">
                  <CreditCard size={16} className="text-indigo-500" />
                  <h3 className="text-sm font-semibold text-gray-700">
                    Payment Gateways
                  </h3>
                </div>
                <p className="text-xs text-gray-500">
                  Enable or disable payment providers. At least one gateway must
                  remain active.
                </p>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <GatewayCard
                    name="Paymob"
                    description="Credit / debit cards via Paymob Egypt"
                    enabled={!!form.paymob_enabled}
                    onChange={(v) =>
                      set("paymob_enabled" as keyof AppSettings, v as any)
                    }
                    disabled={!editMode}
                    changed={isFieldChanged("paymob_enabled")}
                  />
                  <GatewayCard
                    name="Kashier"
                    description="Credit / debit cards and mobile wallets via Kashier"
                    enabled={!!form.kashier_enabled}
                    onChange={(v) =>
                      set("kashier_enabled" as keyof AppSettings, v as any)
                    }
                    disabled={!editMode}
                    changed={isFieldChanged("kashier_enabled")}
                  />
                  <GatewayCard
                    name="EasyKash"
                    description="Credit / debit cards and mobile wallets via EasyKash"
                    enabled={!!form.easykash_enabled}
                    onChange={(v) =>
                      set("easykash_enabled" as keyof AppSettings, v as any)
                    }
                    disabled={!editMode}
                    changed={isFieldChanged("easykash_enabled")}
                  />
                </div>

                {/* Validation warning */}
                {!form.paymob_enabled &&
                  !form.kashier_enabled &&
                  !form.easykash_enabled && (
                    <div className="flex items-center gap-2 p-3 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
                      <XCircle size={15} className="shrink-0" />
                      At least one payment gateway must be enabled. Users will
                      be unable to top up their wallets otherwise.
                    </div>
                  )}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

function FieldGrid({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-5">
      {children}
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-4">
      <h4 className="text-xs font-bold uppercase tracking-wider text-gray-400 mb-3 flex items-center gap-2">
        <span>{title}</span>
        <div className="h-px bg-gray-100 flex-1"></div>
      </h4>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-5">
        {children}
      </div>
    </div>
  );
}

function NumField({
  label,
  value,
  onChange,
  note,
  disabled,
  changed,
}: {
  label: string;
  value: number | null | undefined;
  onChange: (v: number | null) => void;
  note?: string;
  disabled?: boolean;
  changed?: boolean;
}) {
  return (
    <div className="space-y-1.5 group">
      <div className="flex justify-between items-center">
        <label
          className={`text-xs font-semibold transition-colors ${changed ? "text-indigo-600" : "text-gray-500"}`}
        >
          {label}
          {changed && (
            <span className="ml-1 text-[10px] bg-indigo-100 text-indigo-600 px-1.5 py-0.5 rounded-full font-bold">
              MODIFIED
            </span>
          )}
        </label>
        {note && (
          <span className="text-[10px] text-gray-400 italic">({note})</span>
        )}
      </div>
      <input
        type="number"
        step="any"
        value={value ?? ""}
        onChange={(e) =>
          onChange(e.target.value === "" ? null : Number(e.target.value))
        }
        disabled={disabled}
        className={`input w-full transition-all ${disabled ? "bg-gray-50 text-gray-400 border-gray-200" : ""} ${changed ? "border-indigo-300 ring-2 ring-indigo-50 bg-indigo-50/20" : ""}`}
      />
    </div>
  );
}

function TextField({
  label,
  value,
  onChange,
  disabled,
  changed,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  disabled?: boolean;
  changed?: boolean;
}) {
  return (
    <div className="space-y-1.5 group">
      <label
        className={`text-xs font-semibold transition-colors ${changed ? "text-indigo-600" : "text-gray-500"}`}
      >
        {label}
        {changed && (
          <span className="ml-1 text-[10px] bg-indigo-100 text-indigo-600 px-1.5 py-0.5 rounded-full font-bold">
            MODIFIED
          </span>
        )}
      </label>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        className={`input w-full transition-all ${disabled ? "bg-gray-50 text-gray-400 border-gray-200" : ""} ${changed ? "border-indigo-300 ring-2 ring-indigo-50 bg-indigo-50/20" : ""}`}
      />
    </div>
  );
}

function ToggleField({
  label,
  value,
  onChange,
  disabled,
  changed,
}: {
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  changed?: boolean;
}) {
  return (
    <div
      className={`flex items-center justify-between py-2 px-3 rounded-xl transition-all ${changed ? "bg-indigo-50/50 ring-1 ring-indigo-100" : "hover:bg-gray-50"}`}
    >
      <div className="flex flex-col">
        <span
          className={`text-sm font-medium transition-colors ${changed ? "text-indigo-700" : "text-gray-700"}`}
        >
          {label}
        </span>
        {changed && (
          <span className="text-[9px] text-indigo-500 font-bold uppercase tracking-tighter">
            Changed
          </span>
        )}
      </div>
      <button
        type="button"
        disabled={disabled}
        onClick={() => onChange(!value)}
        className={`relative inline-flex h-6 w-11 items-center rounded-full transition ${value ? "bg-indigo-600" : "bg-gray-200"} ${disabled ? "opacity-40 cursor-not-allowed" : ""}`}
      >
        <span
          className={`inline-block h-4 w-4 transform rounded-full bg-white transition ${value ? "translate-x-6" : "translate-x-1"}`}
        />
      </button>
    </div>
  );
}

function GatewayCard({
  name,
  description,
  enabled,
  onChange,
  disabled,
  changed,
}: Readonly<{
  name: string;
  description: string;
  enabled: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  changed?: boolean;
}>) {
  return (
    <div
      className={`relative flex flex-col gap-3 p-4 rounded-2xl border transition-all ${
        enabled
          ? "border-green-200 bg-green-50/40"
          : "border-gray-200 bg-gray-50/40"
      } ${changed ? "ring-2 ring-indigo-200" : ""}`}
    >
      {/* Status badge */}
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-gray-900">{name}</span>
        <span
          className={`flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full ${
            enabled
              ? "bg-green-100 text-green-700"
              : "bg-gray-100 text-gray-500"
          }`}
        >
          {enabled ? (
            <>
              <CheckCircle2 size={11} /> Active
            </>
          ) : (
            <>
              <XCircle size={11} /> Inactive
            </>
          )}
        </span>
      </div>

      <p className="text-xs text-gray-500 leading-relaxed">{description}</p>

      {/* Toggle */}
      <div className="flex items-center justify-between pt-1 border-t border-gray-100">
        <span className="text-xs text-gray-400">
          {enabled ? "Disable gateway" : "Enable gateway"}
        </span>
        <button
          type="button"
          disabled={disabled}
          onClick={() => onChange(!enabled)}
          className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
            enabled ? "bg-green-500" : "bg-gray-200"
          } ${disabled ? "opacity-40 cursor-not-allowed" : "cursor-pointer"}`}
        >
          <span
            className={`inline-block size-4 transform rounded-full bg-white shadow transition-transform ${
              enabled
                ? "ltr:translate-x-6 rtl:-translate-x-6"
                : "ltr:translate-x-1 rtl:-translate-x-1"
            }`}
          />
        </button>
      </div>

      {changed && (
        <span className="absolute top-0.5 inset-e-12 text-[9px] bg-indigo-100 text-indigo-600 px-1.5 py-0.5 rounded-full font-bold uppercase">
          Modified
        </span>
      )}
    </div>
  );
}
