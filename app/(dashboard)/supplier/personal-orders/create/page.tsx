"use client";

import { useState, useMemo, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import api, { supplierApi } from "@/lib/api";
import { getCurrentUserId } from "@/lib/auth";
import { useRole } from "@/hooks/useRole";
import { useT } from "@/contexts/LanguageContext";
import LocationPickerMap from "@/components/maps/LocationPickerMap";
import {
  isPointInArea,
  areaCentroid,
  findAreaContainingPoint,
  type RawBoundaries,
} from "@/lib/areaBoundary";
import toast from "react-hot-toast";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import {
  ShoppingBag,
  Truck,
  MapPin,
  Wallet,
  Banknote,
  Calendar,
  Clock,
  Image as ImageIcon,
  X,
  Loader2,
  CheckCircle,
  AlertCircle,
  Navigation,
  Info,
  PackagePlus,
} from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────
interface Area {
  id: number;
  name: string;
  name_ar?: string | null;
  boundaries?: RawBoundaries;
  governorate?: { id: number; name: string; name_ar?: string | null } | null;
}

interface GovernorateWithAreas {
  id: number;
  name: string;
  name_ar?: string | null;
  areas?: Area[];
}

interface AppSettings {
  customer_budget_cash_on_delivery_limit?: number | null; // cents
}

interface OrderPreview {
  totalFee?: number; // cents — total delivery cost incl. VAT
  deliveryFee?: number; // cents
  payableAmount?: number; // cents
  distanceM?: number; // meters
}

type Mode = "shopping" | "shipping";
type PaymentChoice = "CASH" | "WALLET";
type ScheduleChoice = "now" | "schedule";

interface LocationState {
  areaId: number | null;
  description: string;
  lat: string;
  long: string;
}

const EMPTY_LOCATION: LocationState = { areaId: null, description: "", lat: "", long: "" };

// ── Helpers ───────────────────────────────────────────────────────────────────
function fmtEGP(cents: number) {
  return `${(cents / 100).toFixed(2)} EGP`;
}

function fmtKm(m: number) {
  return `${(m / 1000).toFixed(1)} km`;
}

function locationComplete(l: LocationState) {
  return (
    l.areaId != null &&
    l.description.trim().length > 0 &&
    l.lat.trim().length > 0 &&
    l.long.trim().length > 0
  );
}

// ── Reusable location block (area + map + manual coords + description) ─────────
// Enforces "select area first → then pick a point", and validates the picked
// point against the selected area's boundaries (Task 4).
function LocationFields({
  value,
  onChange,
  areas,
  loadingAreas,
  disabled = false,
}: {
  value: LocationState;
  onChange: (next: LocationState) => void;
  areas: Area[];
  loadingAreas: boolean;
  disabled?: boolean;
}) {
  const { t, isRTL } = useT();
  const set = (patch: Partial<LocationState>) => onChange({ ...value, ...patch });

  // Per-field "touched" — a field only turns red once the user has interacted
  // with it (blurred the select/textarea), never before they reach it.
  const [touched, setTouched] = useState({ area: false, desc: false });

  const latNum = value.lat.trim() ? Number(value.lat) : null;
  const longNum = value.long.trim() ? Number(value.long) : null;
  const hasPoint =
    latNum != null && longNum != null && Number.isFinite(latNum) && Number.isFinite(longNum);

  const selectedArea = useMemo(
    () => areas.find((a) => a.id === value.areaId) ?? null,
    [areas, value.areaId],
  );
  const centroid = useMemo(
    () => (selectedArea ? areaCentroid(selectedArea.boundaries) : null),
    [selectedArea],
  );

  const noAreaSelected = value.areaId == null;
  const mapDisabled = disabled || noAreaSelected;
  const outsideArea =
    !!selectedArea &&
    hasPoint &&
    !isPointInArea(latNum as number, longNum as number, selectedArea.boundaries);

  // Field-level problems — only after the user has engaged this location block.
  // Touching the area select counts as engaging the block, so the (required)
  // map point and address get flagged too even if not directly focused.
  const engaged = touched.area || touched.desc;
  const areaError = touched.area && noAreaSelected;
  const pointError = engaged && !noAreaSelected && !hasPoint;
  const descError = engaged && value.description.trim().length === 0;

  return (
    <div className="space-y-3">
      {/* Area — must be chosen before a point can be selected */}
      <div>
        <label className="block text-xs font-medium text-gray-700 mb-1">
          {t("sp.createOrder.area")} *
        </label>
        {loadingAreas ? (
          <div className="flex items-center gap-2 text-gray-400 text-sm">
            <Loader2 className="w-4 h-4 animate-spin" />
            {t("sp.createOrder.loadingAreas")}
          </div>
        ) : (
          <select
            disabled={disabled}
            value={value.areaId ?? ""}
            onChange={(e) => set({ areaId: Number(e.target.value) || null })}
            onBlur={() => setTouched((p) => ({ ...p, area: true }))}
            className={`w-full text-sm border rounded-lg px-3 py-2 focus:ring-2 bg-white disabled:bg-gray-100 ${
              areaError
                ? "border-red-300 focus:ring-red-400 focus:border-red-400"
                : "border-gray-300 focus:ring-indigo-400 focus:border-indigo-400"
            }`}
          >
            <option value="">{t("sp.createOrder.selectArea")}</option>
            {areas.map((a) => (
              <option key={a.id} value={a.id}>
                {isRTL && a.name_ar ? a.name_ar : a.name}
                {a.governorate
                  ? ` — ${isRTL && a.governorate.name_ar ? a.governorate.name_ar : a.governorate.name}`
                  : ""}
              </option>
            ))}
          </select>
        )}
        {areaError && (
          <p className="mt-1 text-[11px] text-red-600">{t("sp.createOrder.required")}</p>
        )}
      </div>

      {/* Map picker — locked until an area is selected */}
      <div>
        <label className="block text-xs font-medium text-gray-700 mb-1">
          {t("sp.createOrder.pickOnMap")}
        </label>
        <LocationPickerMap
          lat={latNum}
          long={longNum}
          centerLat={centroid?.lat ?? null}
          centerLong={centroid?.lng ?? null}
          disabled={mapDisabled}
          onChange={(lat, long) =>
            set({ lat: lat.toFixed(6), long: long.toFixed(6) })
          }
        />
        {noAreaSelected && (
          <p className="mt-1 flex items-center gap-1 text-[11px] text-amber-600">
            <Info className="w-3 h-3" />
            {t("sp.createOrder.selectAreaFirst")}
          </p>
        )}
        {pointError && (
          <p className="mt-1 flex items-center gap-1 text-[11px] text-red-600">
            <AlertCircle className="w-3 h-3" />
            {t("sp.createOrder.errPickPoint")}
          </p>
        )}
      </div>

      {/* Latitude/Longitude are filled automatically from the map picker — hidden. */}

      {/* Outside-area validation error */}
      {outsideArea && (
        <div className="flex items-start gap-2 px-3 py-2 bg-red-50 border border-red-200 rounded-xl">
          <AlertCircle className="w-4 h-4 text-red-500 shrink-0 mt-0.5" />
          <p className="text-xs text-red-600">{t("sp.createOrder.outsideArea")}</p>
        </div>
      )}

      {/* Address description */}
      <div>
        <label className="block text-xs font-medium text-gray-700 mb-1">
          {t("sp.createOrder.addressDescription")} *
        </label>
        <textarea
          rows={2}
          disabled={disabled}
          value={value.description}
          onChange={(e) => set({ description: e.target.value })}
          onBlur={() => setTouched((p) => ({ ...p, desc: true }))}
          placeholder={t("sp.createOrder.addressPlaceholder")}
          className={`w-full text-sm border rounded-lg px-3 py-2 focus:ring-2 resize-none disabled:bg-gray-100 ${
            descError
              ? "border-red-300 focus:ring-red-400 focus:border-red-400"
              : "border-gray-300 focus:ring-indigo-400 focus:border-indigo-400"
          }`}
        />
        {descError && (
          <p className="mt-1 text-[11px] text-red-600">{t("sp.createOrder.required")}</p>
        )}
      </div>
    </div>
  );
}

// ── Section card wrapper ──────────────────────────────────────────────────────
function SectionCard({
  icon: Icon,
  title,
  children,
}: {
  icon: React.ElementType;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
      <h2 className="text-base font-semibold text-gray-800 mb-4 flex items-center gap-2">
        <Icon className="w-4 h-4 text-indigo-500" />
        {title}
      </h2>
      {children}
    </section>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────
export default function CreateOrderPage() {
  const { t, isRTL, lang } = useT();
  const router = useRouter();

  // NOTE (Task 1): The supplier frontend currently only exposes the "Shipping"
  // flow. The "Shopping" flow is kept intact (tab option, budget field, cash/
  // wallet choice, COD-limit logic below) but hidden here — it will be reused
  // in the admin dashboard. Default the mode to "shipping" while shopping is off.
  const [mode, setMode] = useState<Mode>("shopping");
  const [productDescription, setProductDescription] = useState("");
  const [budgetEgp, setBudgetEgp] = useState("");

  const [productImage, setProductImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  // "Near Me" → use the device's current GPS location as the pickup point (Task 2)
  const [nearMe, setNearMe] = useState(false);
  const [locatingMe, setLocatingMe] = useState(false);
  const [pickup, setPickup] = useState<LocationState>(EMPTY_LOCATION);
  const [delivery, setDelivery] = useState<LocationState>(EMPTY_LOCATION);

  const [paymentChoice, setPaymentChoice] = useState<PaymentChoice>("CASH");
  const [scheduleChoice, setScheduleChoice] = useState<ScheduleChoice>("now");
  const [scheduleAt, setScheduleAt] = useState("");

  const [submitting, setSubmitting] = useState(false);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // ── Fetch governorates + areas (with boundaries) ─────────────────────────────
  const { data: govData, isLoading: loadingAreas } = useQuery({
    queryKey: ["create-order-governorates-areas"],
    queryFn: () =>
      api
        .get("/governorates", {
          params: { includes: "areas", is_active: true, "areas[is_active]": true },
        })
        .then((r) => r.data),
  });

  const areas: Area[] = useMemo(() => {
    const govs: GovernorateWithAreas[] = govData?.governorates ?? [];
    const flat: Area[] = [];
    for (const g of govs) {
      for (const a of g.areas ?? []) {
        flat.push({
          ...a,
          governorate: { id: g.id, name: g.name, name_ar: g.name_ar },
        });
      }
    }
    return flat;
  }, [govData]);

  // ── Fetch COD limit from app settings ────────────────────────────────────────
  const { data: settings } = useQuery({
    queryKey: ["app-settings-cod"],
    queryFn: () => api.get<{ settings: AppSettings }>("/app-settings").then((r) => r.data.settings),
  });

  const codLimitCents = settings?.customer_budget_cash_on_delivery_limit ?? null;

  // ── Current supplier's shopping budget bounds ────────────────────────────────
  // shopping_min/max_price_for_one_order are stored as cents — shown/compared in EGP.
  const { user } = useRole();
  const supplierUserId = user?.id ?? getCurrentUserId();
  const { data: supplierProfile } = useQuery({
    queryKey: ["supplier-profile-shopping-limits", supplierUserId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/get-profile/${supplierUserId}`);
      return res.data?.data?.user ?? res.data?.data;
    },
    enabled: !!supplierUserId,
    staleTime: 5 * 60 * 1000,
  });

  const shoppingMinEgp: number | null =
    supplierProfile?.supplier?.shopping_min_price_for_one_order != null
      ? supplierProfile.supplier.shopping_min_price_for_one_order / 100
      : null;
  const shoppingMaxEgp: number | null =
    supplierProfile?.supplier?.shopping_max_price_for_one_order != null
      ? supplierProfile.supplier.shopping_max_price_for_one_order / 100
      : null;

  // shopping_budget_fee is a percentage (e.g. 5 = 5%) added on top of the entered budget.
  const shoppingBudgetFee: number =
    supplierProfile?.supplier?.shopping_budget_fee ?? 0;

  // ── Derived budget / payment ─────────────────────────────────────────────────
  // The supplier types an amount; the actual order budget adds the fee on top:
  //   total = entered + entered * (shopping_budget_fee / 100)
  const enteredBudgetEgp = useMemo(() => {
    const egp = parseFloat(budgetEgp);
    return Number.isFinite(egp) && egp > 0 ? egp : 0;
  }, [budgetEgp]);

  const budgetFeeEgp = enteredBudgetEgp * (shoppingBudgetFee / 100);
  const totalBudgetEgp = enteredBudgetEgp + budgetFeeEgp;

  const budgetCents = useMemo(() => {
    if (mode === "shipping") return 1;
    if (enteredBudgetEgp <= 0) return 0;
    return Math.round(totalBudgetEgp * 100);
  }, [mode, enteredBudgetEgp, totalBudgetEgp]);

  // Budget must fall within the supplier's configured shopping range. The range
  // is applied to the *total* budget (entered amount + service fee), not the
  // amount the supplier types in.
  const budgetOutOfRange = useMemo(() => {
    if (mode !== "shopping") return false;
    if (!Number.isFinite(parseFloat(budgetEgp)) || enteredBudgetEgp <= 0) return false;
    if (shoppingMinEgp != null && totalBudgetEgp < shoppingMinEgp) return true;
    if (shoppingMaxEgp != null && totalBudgetEgp > shoppingMaxEgp) return true;
    return false;
  }, [mode, budgetEgp, enteredBudgetEgp, totalBudgetEgp, shoppingMinEgp, shoppingMaxEgp]);

  const exceedsCodLimit =
    mode === "shopping" && codLimitCents != null && budgetCents > codLimitCents;

  // Effective payment method actually sent to the API
  const effectivePayment: PaymentChoice = useMemo(() => {
    if (mode === "shipping") return "WALLET";
    if (paymentChoice === "WALLET") return "WALLET";
    return exceedsCodLimit ? "WALLET" : "CASH";
  }, [mode, paymentChoice, exceedsCodLimit]);

  // ── "Near Me": capture current GPS location as pickup ────────────────────────
  function handleNearMeToggle(checked: boolean) {
    setNearMe(checked);
    if (!checked) return;

    if (typeof navigator === "undefined" || !navigator.geolocation) {
      toast.error(t("sp.createOrder.geoUnsupported"));
      setNearMe(false);
      return;
    }

    setLocatingMe(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        const detected = findAreaContainingPoint(lat, lng, areas);
        setPickup((p) => ({
          ...p,
          lat: lat.toFixed(6),
          long: lng.toFixed(6),
          areaId: detected?.id ?? p.areaId,
        }));
        setLocatingMe(false);
        if (!detected) toast(t("sp.createOrder.areaNotDetected"));
      },
      () => {
        toast.error(t("sp.createOrder.geoDenied"));
        setNearMe(false);
        setLocatingMe(false);
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  // ── Image handling ──────────────────────────────────────────────────────────
  function handleImageChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    if (imagePreview) URL.revokeObjectURL(imagePreview);
    setProductImage(file);
    setImagePreview(URL.createObjectURL(file));
  }

  function removeImage() {
    if (imagePreview) URL.revokeObjectURL(imagePreview);
    setProductImage(null);
    setImagePreview(null);
    if (fileInputRef.current) fileInputRef.current.value = "";
  }

  // Revoke object URL on unmount
  useEffect(() => {
    return () => {
      if (imagePreview) URL.revokeObjectURL(imagePreview);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Boundary-aware validity for a location ───────────────────────────────────
  const pointValidFor = useCallback(
    (loc: LocationState): boolean => {
      if (!locationComplete(loc)) return false;
      const area = areas.find((a) => a.id === loc.areaId);
      if (!area) return true; // area data not loaded yet → permissive
      return isPointInArea(Number(loc.lat), Number(loc.long), area.boundaries);
    },
    [areas],
  );

  // ── Order preview (estimated delivery fee) ───────────────────────────────────
  const [preview, setPreview] = useState<OrderPreview | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState(false);

  const canPreview =
    pointValidFor(delivery) &&
    pointValidFor(pickup) &&
    (mode === "shipping" || budgetCents > 0);

  const fetchPreview = useCallback(async () => {
    setPreviewLoading(true);
    setPreviewError(false);
    try {
      const body = {
        type: "CUSTOM_PICKUP",
        product_description: "product_description",
        budget: mode === "shipping" ? 1 : budgetCents,
        payment_method: effectivePayment,
        pickup_area_id: pickup.areaId,
        pickup_address_description: pickup.description.trim(),
        pickup_lat: Number(pickup.lat),
        pickup_long: Number(pickup.long),
        delivery_area_id: delivery.areaId,
        delivery_address_description: delivery.description.trim(),
        delivery_lat: Number(delivery.lat),
        delivery_long: Number(delivery.long),
      };
      const res = await api.post("/orders/preview", body, {
        params: { lang: lang.toLowerCase() },
      });
      setPreview((res.data?.preview ?? res.data) as OrderPreview);
    } catch {
      setPreview(null);
      setPreviewError(true);
    } finally {
      setPreviewLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    mode,
    budgetCents,
    effectivePayment,
    pickup.areaId,
    pickup.description,
    pickup.lat,
    pickup.long,
    delivery.areaId,
    delivery.description,
    delivery.lat,
    delivery.long,
    lang,
  ]);

  // Debounced preview refresh whenever the relevant inputs change
  useEffect(() => {
    if (!canPreview) {
      setPreview(null);
      setPreviewError(false);
      return;
    }
    const id = setTimeout(fetchPreview, 600);
    return () => clearTimeout(id);
  }, [canPreview, fetchPreview]);

  // ── Whole-form validity (Task 3) ─────────────────────────────────────────────
  const scheduleValid =
    scheduleChoice === "now" ||
    (!!scheduleAt && new Date(scheduleAt).getTime() > Date.now());

  const isFormValid =
    productDescription.trim().length >= 10 &&
    (mode === "shipping" || budgetCents > 0) &&
    !budgetOutOfRange &&
    (mode !== "shipping" || !!productImage) &&
    pointValidFor(delivery) &&
    pointValidFor(pickup) &&
    scheduleValid;

  // ── Per-field problems — each shown only after that field has been touched ─────
  const descriptionError = productDescription.trim().length < 10;
  const budgetError = mode === "shopping" && (budgetCents <= 0 || budgetOutOfRange);
  const imageError = mode === "shipping" && !productImage;
  const scheduleError = !scheduleValid;

  // Track which top-level fields the user has interacted with so we only mark
  // the field in front of them — never fields they haven't reached yet.
  const [touched, setTouched] = useState({
    description: false,
    budget: false,
    image: false,
    schedule: false,
  });
  const markTouched = (k: keyof typeof touched) =>
    setTouched((p) => (p[k] ? p : { ...p, [k]: true }));

  // Bumping this key remounts the LocationFields so their internal "touched"
  // state is cleared after a successful submit/reset.
  const [locationsKey, setLocationsKey] = useState(0);

  // A general hint near the disabled button — shown once the user has touched
  // any field and the form is still invalid.
  const anyTouched =
    touched.description || touched.budget || touched.image || touched.schedule;
  const showHint = anyTouched && !isFormValid;

  // ── Validation messages (used as a submit safety-net) ────────────────────────
  function validate(): string | null {
    if (productDescription.trim().length < 10) return t("sp.createOrder.errDescription");
    if (mode === "shopping" && budgetCents <= 0) return t("sp.createOrder.errBudget");
    if (mode === "shopping" && budgetOutOfRange) return t("sp.createOrder.errBudgetRange");
    if (mode === "shipping" && !productImage) return t("sp.createOrder.errImageRequired");
    if (!locationComplete(delivery)) return t("sp.createOrder.errDelivery");
    if (!pointValidFor(delivery)) return t("sp.createOrder.errDeliveryOutside");
    if (!locationComplete(pickup)) return t("sp.createOrder.errPickup");
    if (!pointValidFor(pickup)) return t("sp.createOrder.errPickupOutside");
    if (scheduleChoice === "schedule") {
      if (!scheduleAt) return t("sp.createOrder.errScheduleRequired");
      if (new Date(scheduleAt).getTime() <= Date.now()) return t("sp.createOrder.errScheduleFuture");
    }
    return null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  async function handleSubmit() {
    const error = validate();
    if (error) {
      toast.error(error);
      return;
    }

    setSubmitting(true);
    try {
      const fd = new FormData();
      fd.append("type", "CUSTOM_PICKUP");
      fd.append("product_description", productDescription.trim());
      fd.append("budget", mode === "shipping" ? "1" : String(budgetCents));

      // Pickup
      fd.append("pickup_area_id", String(pickup.areaId));
      fd.append("pickup_address_description", pickup.description.trim());
      fd.append("pickup_lat", pickup.lat.trim());
      fd.append("pickup_long", pickup.long.trim());

      // Delivery
      fd.append("delivery_area_id", String(delivery.areaId));
      fd.append("delivery_address_description", delivery.description.trim());
      fd.append("delivery_lat", delivery.lat.trim());
      fd.append("delivery_long", delivery.long.trim());

      fd.append("payment_method", effectivePayment);

      if (productImage) fd.append("product_image", productImage);

      if (scheduleChoice === "schedule") {
        fd.append("is_order_scheduled", "true");
        fd.append("order_schedule_at", new Date(scheduleAt).toISOString());
      }

      await api.post("/orders", fd, {
        headers: { "Content-Type": "multipart/form-data" },
        params: { lang: lang.toLowerCase() },
      });

      toast.success(t("sp.createOrder.success"));

      // Navigate to the active personal orders page after creating.
      router.push("/supplier/personal-orders/active");
    } catch (err: any) {
      const msg =
        err?.response?.data?.message ??
        err?.response?.data?.error ??
        t("sp.createOrder.errSubmit");
      toast.error(msg);
    } finally {
      setSubmitting(false);
    }
  }

  // ── Local datetime min (now) ─────────────────────────────────────────────────
  const nowLocal = useMemo(() => {
    const d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  }, []);

  // Mode tabs. The "Shopping" option is intentionally commented out for the
  // supplier frontend (Task 1) — re-enable it for the admin dashboard.
  const modeTabs: { key: Mode; label: string; icon: React.ElementType }[] = [
    { key: "shipping", label: t("sp.createOrder.tabShipping"), icon: Truck },
    { key: "shopping", label: t("sp.createOrder.tabShopping"), icon: ShoppingBag },
  ];

  return (
    <div className="max-w-3xl mx-auto px-4 py-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-11 h-11 rounded-2xl bg-indigo-50 flex items-center justify-center">
          <PackagePlus className="w-5 h-5 text-indigo-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t("sp.createOrder.title")}</h1>
          <p className="text-sm text-gray-500">{t("sp.createOrder.subtitle")}</p>
        </div>
      </div>

      {/* Mode tabs */}
      <div className="flex gap-3">
        {modeTabs.map(({ key, label, icon: Icon }) => {
          const active = mode === key;
          return (
            <button
              key={key}
              type="button"
              onClick={() => setMode(key)}
              className={`flex-1 flex items-center justify-center gap-2 p-4 rounded-2xl border-2 transition-all font-medium ${
                active
                  ? "border-indigo-500 bg-indigo-50 text-indigo-700"
                  : "border-gray-200 hover:border-gray-300 text-gray-600"
              }`}
            >
              <Icon className="w-5 h-5" />
              {label}
            </button>
          );
        })}
      </div>

      {/* Product details */}
      <SectionCard icon={ImageIcon} title={t("sp.createOrder.productDetails")}>
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">
              {t("sp.createOrder.productDescription")} *
            </label>
            <textarea
              rows={3}
              value={productDescription}
              onChange={(e) => setProductDescription(e.target.value)}
              onBlur={() => markTouched("description")}
              placeholder={t("sp.createOrder.productDescriptionPlaceholder")}
              className={`w-full text-sm border rounded-lg px-3 py-2 focus:ring-2 resize-none ${
                touched.description && descriptionError
                  ? "border-red-300 focus:ring-red-400 focus:border-red-400"
                  : "border-gray-300 focus:ring-indigo-400 focus:border-indigo-400"
              }`}
            />
            <p
              className={`mt-1 text-[11px] ${
                touched.description && descriptionError ? "text-red-600" : "text-gray-400"
              }`}
            >
              {touched.description && descriptionError
                ? t("sp.createOrder.errDescription")
                : t("sp.createOrder.minChars")}
            </p>
          </div>

          {/* Budget — shopping only (hidden while shopping is disabled) */}
          {mode === "shopping" && (
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                {t("sp.createOrder.budget")} *
              </label>
              <div className="relative">
                <input
                  type="number"
                  min={shoppingMinEgp ?? 0}
                  max={shoppingMaxEgp ?? undefined}
                  step="0.01"
                  value={budgetEgp}
                  onChange={(e) => setBudgetEgp(e.target.value)}
                  onBlur={() => markTouched("budget")}
                  placeholder="50"
                  className={`w-full text-sm border rounded-lg px-3 py-2 pe-14 focus:ring-2 ${
                    budgetOutOfRange || (touched.budget && budgetError)
                      ? "border-red-300 focus:ring-red-400 focus:border-red-400"
                      : "border-gray-300 focus:ring-indigo-400 focus:border-indigo-400"
                  }`}
                />
                <span className="absolute inset-y-0 end-3 flex items-center text-xs text-gray-400">
                  EGP
                </span>
              </div>
              {touched.budget && budgetError && (
                <p className="mt-1 text-[11px] text-red-600">
                  {budgetOutOfRange
                    ? t("sp.createOrder.errBudgetRange")
                    : t("sp.createOrder.errBudget")}
                </p>
              )}

              {/* Fee breakdown — the service fee is added on top of the entered budget */}
              {shoppingBudgetFee > 0 && enteredBudgetEgp > 0 && (
                <div className="mt-2 space-y-1 rounded-lg bg-gray-50 border border-gray-200 px-3 py-2 text-xs text-gray-600">
                  <div className="flex items-center justify-between">
                    <span>{t("sp.createOrder.budgetEntered")}</span>
                    <span className="tabular-nums">
                      {enteredBudgetEgp.toFixed(2)} EGP
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>
                      {t("sp.createOrder.budgetFee")} (
                      {shoppingBudgetFee}%)
                    </span>
                    <span className="tabular-nums">
                      +{budgetFeeEgp.toFixed(2)} EGP
                    </span>
                  </div>
                  <div className="flex items-center justify-between border-t border-gray-200 pt-1 font-semibold text-gray-900">
                    <span>{t("sp.createOrder.budgetTotal")}</span>
                    <span className="tabular-nums">
                      {totalBudgetEgp.toFixed(2)} EGP
                    </span>
                  </div>
                  <p
                    className={`flex items-center gap-1 text-[11px] ${
                      budgetOutOfRange ? "text-red-600" : "text-amber-600"
                    }`}
                  >
                    <Info className="w-3 h-3" />
                    {t("sp.createOrder.budgetRange")}: {shoppingMinEgp ?? 0} –{" "}
                    {shoppingMaxEgp ?? "∞"} EGP
                  </p>
                </div>
              )}
            </div>
          )}

          {/* Product image */}
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">
              {t("sp.createOrder.productImage")}
              {mode === "shipping" ? " *" : ` (${t("sp.createOrder.optional")})`}
            </label>
            {imagePreview ? (
              <div className="relative inline-block">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={imagePreview}
                  alt="preview"
                  className="w-28 h-28 rounded-xl object-cover border border-gray-200"
                />
                <button
                  type="button"
                  onClick={removeImage}
                  className="absolute -top-2 -end-2 w-6 h-6 rounded-full bg-red-500 text-white flex items-center justify-center shadow"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            ) : (
              <label
                onClick={() => markTouched("image")}
                className={`flex flex-col items-center justify-center gap-1.5 w-full py-6 border-2 border-dashed rounded-xl cursor-pointer transition ${
                  touched.image && imageError
                    ? "border-red-300 bg-red-50/40 hover:border-red-400"
                    : "border-gray-300 hover:border-indigo-400 hover:bg-indigo-50/40"
                }`}
              >
                <ImageIcon
                  className={`w-6 h-6 ${touched.image && imageError ? "text-red-400" : "text-gray-400"}`}
                />
                <span className="text-xs text-gray-500">{t("sp.createOrder.uploadImage")}</span>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept={ALLOWED_IMAGE_ACCEPT}
                  onChange={handleImageChange}
                  className="hidden"
                />
              </label>
            )}
            {touched.image && imageError && (
              <p className="mt-1 text-[11px] text-red-600">
                {t("sp.createOrder.errImageRequired")}
              </p>
            )}
          </div>
        </div>
      </SectionCard>

      {/* Locations */}
      <SectionCard icon={MapPin} title={t("sp.createOrder.locations")}>
        {/* Pickup */}
        <div className="mb-5">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-gray-700">
              {t("sp.createOrder.pickupLocation")}
            </h3>
            <label className="flex items-center gap-1.5 text-xs text-gray-600 cursor-pointer">
              <input
                type="checkbox"
                checked={nearMe}
                onChange={(e) => handleNearMeToggle(e.target.checked)}
                className="rounded text-indigo-500 focus:ring-indigo-400"
              />
              <Navigation className="w-3.5 h-3.5 text-indigo-500" />
              {t("sp.createOrder.nearMe")}
              {locatingMe && <Loader2 className="w-3.5 h-3.5 animate-spin text-indigo-500" />}
            </label>
          </div>

          {nearMe && (
            <div className="mb-3 flex items-start gap-2 px-3 py-2 bg-indigo-50 border border-indigo-200 rounded-xl">
              <Info className="w-4 h-4 text-indigo-500 shrink-0 mt-0.5" />
              <p className="text-xs text-indigo-700">{t("sp.createOrder.nearMeHint")}</p>
            </div>
          )}

          <LocationFields
            key={`pickup-${locationsKey}`}
            value={pickup}
            onChange={setPickup}
            areas={areas}
            loadingAreas={loadingAreas}
          />
        </div>

        {/* Delivery */}
        <div>
          <h3 className="text-sm font-semibold text-gray-700 mb-2">
            {t("sp.createOrder.deliveryLocation")}
          </h3>
          <LocationFields
            key={`delivery-${locationsKey}`}
            value={delivery}
            onChange={setDelivery}
            areas={areas}
            loadingAreas={loadingAreas}
          />
        </div>
      </SectionCard>

      {/* Payment */}
      <SectionCard icon={Wallet} title={t("sp.createOrder.payment")}>
        {mode === "shipping" ? (
          <div className="flex items-center gap-3 p-4 rounded-xl border-2 border-indigo-500 bg-indigo-50 text-indigo-700">
            <Wallet className="w-5 h-5" />
            <div>
              <p className="text-sm font-medium">{t("sp.createOrder.wallet")}</p>
              <p className="text-[11px] text-indigo-500">{t("sp.createOrder.shippingWalletOnly")}</p>
            </div>
          </div>
        ) : (
          /* Shopping payment (Cash/Wallet) — retained for the admin dashboard */
          <>
            <div className="grid grid-cols-2 gap-3">
              {(
                [
                  { key: "CASH", label: t("sp.createOrder.cod"), icon: Banknote },
                  { key: "WALLET", label: t("sp.createOrder.wallet"), icon: Wallet },
                ] as { key: PaymentChoice; label: string; icon: React.ElementType }[]
              ).map(({ key, label, icon: Icon }) => {
                const active = paymentChoice === key;
                const disabledCash = key === "CASH" && exceedsCodLimit;
                return (
                  <button
                    key={key}
                    type="button"
                    disabled={disabledCash}
                    onClick={() => setPaymentChoice(key)}
                    className={`flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all ${
                      active && !disabledCash
                        ? "border-indigo-500 bg-indigo-50 text-indigo-700"
                        : "border-gray-200 hover:border-gray-300 text-gray-600"
                    } ${disabledCash ? "opacity-50 cursor-not-allowed" : ""}`}
                  >
                    <Icon className="w-6 h-6" />
                    <span className="text-sm font-medium">{label}</span>
                  </button>
                );
              })}
            </div>

            {exceedsCodLimit && (
              <div className="mt-3 flex items-start gap-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-xl">
                <AlertCircle className="w-4 h-4 text-amber-500 shrink-0 mt-0.5" />
                <p className="text-xs text-amber-700">
                  {t("sp.createOrder.codLimitExceeded")}
                  {codLimitCents != null ? ` (${fmtEGP(codLimitCents)})` : ""}
                </p>
              </div>
            )}
          </>
        )}
      </SectionCard>

      {/* Schedule */}
      <SectionCard icon={Calendar} title={t("sp.createOrder.timing")}>
        <div className="grid grid-cols-2 gap-3">
          {(
            [
              { key: "now", label: t("sp.createOrder.orderNow"), icon: Clock },
              { key: "schedule", label: t("sp.createOrder.schedule"), icon: Calendar },
            ] as { key: ScheduleChoice; label: string; icon: React.ElementType }[]
          ).map(({ key, label, icon: Icon }) => {
            const active = scheduleChoice === key;
            return (
              <button
                key={key}
                type="button"
                onClick={() => setScheduleChoice(key)}
                className={`flex items-center justify-center gap-2 p-3 rounded-xl border-2 transition-all ${
                  active
                    ? "border-indigo-500 bg-indigo-50 text-indigo-700"
                    : "border-gray-200 hover:border-gray-300 text-gray-600"
                }`}
              >
                <Icon className="w-5 h-5" />
                <span className="text-sm font-medium">{label}</span>
              </button>
            );
          })}
        </div>

        {scheduleChoice === "schedule" && (
          <div className="mt-4">
            <label className="block text-xs font-medium text-gray-700 mb-1">
              {t("sp.createOrder.scheduleAt")} *
            </label>
            <input
              type="datetime-local"
              min={nowLocal}
              value={scheduleAt}
              onChange={(e) => setScheduleAt(e.target.value)}
              onBlur={() => markTouched("schedule")}
              className={`w-full text-sm border rounded-lg px-3 py-2 focus:ring-2 ${
                touched.schedule && scheduleError
                  ? "border-red-300 focus:ring-red-400 focus:border-red-400"
                  : "border-gray-300 focus:ring-indigo-400 focus:border-indigo-400"
              }`}
            />
            {touched.schedule && scheduleError && (
              <p className="mt-1 text-[11px] text-red-600">
                {scheduleAt
                  ? t("sp.createOrder.errScheduleFuture")
                  : t("sp.createOrder.errScheduleRequired")}
              </p>
            )}
          </div>
        )}
      </SectionCard>

      {/* Fee preview */}
      {canPreview && (
        <SectionCard icon={Truck} title={t("sp.createOrder.feePreview")}>
          {previewLoading ? (
            <div className="flex items-center gap-2 text-gray-400 py-2">
              <Loader2 className="w-4 h-4 animate-spin" />
              <span className="text-sm">{t("sp.createOrder.calculatingFees")}</span>
            </div>
          ) : previewError ? (
            <div className="flex items-center gap-2 px-3 py-2 bg-red-50 border border-red-200 rounded-xl">
              <AlertCircle className="w-4 h-4 text-red-400" />
              <p className="text-xs text-red-600">{t("sp.createOrder.feePreviewError")}</p>
            </div>
          ) : preview ? (
            <div className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-gray-500">{t("sp.createOrder.estimatedDeliveryFee")}</span>
                <span className="font-semibold text-gray-900">
                  {fmtEGP(preview.totalFee ?? preview.deliveryFee ?? 0)}
                </span>
              </div>
              {preview.distanceM != null && preview.distanceM > 0 && (
                <div className="flex items-center gap-1.5 text-[11px] text-gray-400">
                  <Navigation className="w-3 h-3" />
                  {t("sp.createOrder.estimatedDistance")}: {fmtKm(preview.distanceM)}
                </div>
              )}
            </div>
          ) : null}
        </SectionCard>
      )}

      {/* Hint explaining why the button is disabled — points to highlighted fields */}
      {showHint && (
        <div className="flex items-start gap-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-xl">
          <AlertCircle className="w-4 h-4 text-amber-500 shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">{t("sp.createOrder.completeHighlighted")}</p>
        </div>
      )}

      {/* Submit — disabled until all required fields are valid (Task 3) */}
      <button
        type="button"
        onClick={handleSubmit}
        disabled={submitting || !isFormValid}
        className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-indigo-600 text-white rounded-xl font-semibold hover:bg-indigo-700 disabled:opacity-60 disabled:cursor-not-allowed transition-colors"
      >
        {submitting ? (
          <>
            <Loader2 className="w-4 h-4 animate-spin" />
            {t("sp.createOrder.submitting")}
          </>
        ) : (
          <>
            <CheckCircle className="w-4 h-4" />
            {t("sp.createOrder.submit")}
          </>
        )}
      </button>
    </div>
  );
}
