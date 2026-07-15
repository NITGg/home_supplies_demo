"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import api from "@/lib/api";
import { fetchCategory } from "@/lib/categories";
import { useRole } from "@/hooks/useRole";
import { getCurrentUserId } from "@/lib/auth";
import {
  Package2, RefreshCw, Search, ChevronLeft, ChevronRight,
  Plus, Pencil, Trash2, X, ToggleLeft, ToggleRight,
  Loader2, ShoppingBag, Tag, Percent, ChevronDown, ChevronUp,
  Clock, Star, Package, TrendingUp,
} from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";

// ── Helpers ───────────────────────────────────────────────────────────────────
/** Parse images field — DB stores it as JSON string, single URL, or null */
function firstImage(images: any): string | null {
  if (!images) return null;
  if (Array.isArray(images) && images.length > 0) return images[0];
  if (typeof images === "string") {
    const s = images.trim();
    if (s.startsWith("[")) {
      try {
        const arr = JSON.parse(s);
        return Array.isArray(arr) && arr.length > 0 ? arr[0] : null;
      } catch { /* fall through */ }
    }
    if (s.startsWith("http")) return s;
  }
  return null;
}

function fmt(n: number | null | undefined) {
  if (n == null) return "—";
  return `${(n / 100).toFixed(2)} EGP`;
}
function toCents(v: string | number | undefined) {
  if (v === "" || v == null) return undefined;
  return Math.round(Number(v) * 100);
}

const today = () => new Date().toISOString().slice(0, 10);
const nextMonth = () => {
  const d = new Date(); d.setMonth(d.getMonth() + 1);
  return d.toISOString().slice(0, 10);
};

// ── Types ─────────────────────────────────────────────────────────────────────
interface Product {
  id: number; name: string; name_ar?: string; images?: any;
  category_id?: number;
  category?: { id?: number; name?: string; has_window?: boolean };
  has_window?: boolean;
}

const DAYS_OF_WEEK = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

type OrderWindow = { day_of_week: number; time_from: string; time_to: string };
type DeliveryWindow = { day_of_week: number; time_from: string; time_to: string; max_orders: string };

/** Does the product's category require ordering/delivery windows? */
function categoryHasWindow(p: Product | null | undefined): boolean {
  return !!(p?.category?.has_window ?? p?.has_window);
}

// Defaults used when a supplier leaves windows empty: available every day, all day.
const FULL_TIME_FROM = "00:00";
const FULL_TIME_TO = "23:59";
const fullWeekOrderWindows = (): OrderWindow[] =>
  DAYS_OF_WEEK.map((_, i) => ({ day_of_week: i, time_from: FULL_TIME_FROM, time_to: FULL_TIME_TO }));
const fullWeekDeliveryWindows = (): DeliveryWindow[] =>
  DAYS_OF_WEEK.map((_, i) => ({ day_of_week: i, time_from: FULL_TIME_FROM, time_to: FULL_TIME_TO, max_orders: "9999" }));

interface SupplierProduct {
  id: number; product_id: number; supplier_id: number;
  price: number | null; cost_price: number | null;
  stock: number; min_stock: number;
  is_active: boolean; is_featured: boolean;
  rating: number | null; total_reviews: number;
  pickup_ready_duration: number | null;
  estimated_time_from: number | null; estimated_time_to: number | null;
  max_amount_for_one_order: number | null; min_amount_for_one_order: number | null;
  max_amount_for_one_user: number | null; min_amount_for_one_user: number | null;
  reserved_in_carts_amount: number | null;
  product?: Product;
}

interface Offer {
  id: number; supplier_product_id: number;
  offer_type: "PERCENT" | "FIXED_CENTS" | null;
  offer_value: number | null;
  start_date: string | null; end_date: string | null;
  is_active: boolean | null;
  created_by_role: "ADMIN" | "SUPPLIER" | null;
}

type OfferPayload = {
  supplier_product_id: number;
  offer_type: "PERCENT" | "FIXED_CENTS";
  offer_value: number;
  start_date: string; end_date: string;
  is_active?: boolean;
};

type ListingForm = {
  price: string; cost_price: string;
  stock: string; min_stock: string;
  pickup_ready_duration: string;
  estimated_time_from: string; estimated_time_to: string;
  max_amount_for_one_order: string; min_amount_for_one_order: string;
  max_amount_for_one_user: string; min_amount_for_one_user: string;
  is_active: boolean; is_featured: boolean;
  order_windows: OrderWindow[];
  delivery_windows: DeliveryWindow[];
};

const emptyListingForm = (): ListingForm => ({
  price: "", cost_price: "",
  stock: "0", min_stock: "0",
  pickup_ready_duration: "",
  estimated_time_from: "", estimated_time_to: "",
  max_amount_for_one_order: "", min_amount_for_one_order: "1",
  max_amount_for_one_user: "", min_amount_for_one_user: "1",
  is_active: true, is_featured: false,
  order_windows: [], delivery_windows: [],
});

function spToForm(sp: SupplierProduct): ListingForm {
  const c = (v: number | null | undefined) => v != null ? (v / 100).toFixed(2) : "";
  return {
    price: c(sp.price), cost_price: c(sp.cost_price),
    stock: String(sp.stock), min_stock: String(sp.min_stock),
    pickup_ready_duration: sp.pickup_ready_duration != null ? String(sp.pickup_ready_duration) : "",
    estimated_time_from: sp.estimated_time_from != null ? String(sp.estimated_time_from) : "",
    estimated_time_to: sp.estimated_time_to != null ? String(sp.estimated_time_to) : "",
    max_amount_for_one_order: sp.max_amount_for_one_order != null ? String(sp.max_amount_for_one_order) : "",
    min_amount_for_one_order: sp.min_amount_for_one_order != null ? String(sp.min_amount_for_one_order) : "1",
    max_amount_for_one_user: sp.max_amount_for_one_user != null ? String(sp.max_amount_for_one_user) : "",
    min_amount_for_one_user: sp.min_amount_for_one_user != null ? String(sp.min_amount_for_one_user) : "1",
    is_active: sp.is_active, is_featured: sp.is_featured,
    order_windows: (() => {
      const raw = (sp as any).order_windows ?? (sp as any).orderWindows;
      return Array.isArray(raw)
        ? raw.map((w: any) => ({
            day_of_week: Number(w.day_of_week),
            time_from: hhmm(w.time_from),
            time_to: hhmm(w.time_to),
          }))
        : [];
    })(),
    delivery_windows: (() => {
      const raw = (sp as any).delivery_windows ?? (sp as any).deliveryWindows;
      return Array.isArray(raw)
        ? raw.map((w: any) => ({
            day_of_week: Number(w.day_of_week),
            time_from: hhmm(w.time_from),
            time_to: hhmm(w.time_to),
            max_orders: w.max_orders != null ? String(w.max_orders) : "",
          }))
        : [];
    })(),
  };
}

/** Normalize a time string to HH:MM for <input type="time"> (API may send "08:00:00") */
function hhmm(t: string | null | undefined): string {
  if (!t) return "";
  return String(t).slice(0, 5);
}

// ── Shared: Order / Delivery windows editor ───────────────────────────────────
function WindowsEditor({ order_windows, delivery_windows, onChange }: {
  order_windows: OrderWindow[];
  delivery_windows: DeliveryWindow[];
  onChange: (p: Partial<Pick<ListingForm, "order_windows" | "delivery_windows">>) => void;
}) {
  const inp = "w-full min-w-0 border border-gray-300 rounded-lg px-2 py-1.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white";
  const lbl = "block text-xs font-medium text-gray-600 mb-1";

  const addOrder = () =>
    onChange({ order_windows: [...order_windows, { day_of_week: 0, time_from: "08:00", time_to: "12:00" }] });
  const updateOrder = (i: number, p: Partial<OrderWindow>) =>
    onChange({ order_windows: order_windows.map((w, idx) => idx === i ? { ...w, ...p } : w) });
  const removeOrder = (i: number) =>
    onChange({ order_windows: order_windows.filter((_, idx) => idx !== i) });

  const addDelivery = () =>
    onChange({ delivery_windows: [...delivery_windows, { day_of_week: 0, time_from: "09:00", time_to: "18:00", max_orders: "10" }] });
  const updateDelivery = (i: number, p: Partial<DeliveryWindow>) =>
    onChange({ delivery_windows: delivery_windows.map((w, idx) => idx === i ? { ...w, ...p } : w) });
  const removeDelivery = (i: number) =>
    onChange({ delivery_windows: delivery_windows.filter((_, idx) => idx !== i) });

  const DaySelect = ({ value, onSelect }: { value: number; onSelect: (v: number) => void }) => (
    <select value={value} onChange={e => onSelect(Number(e.target.value))} className={inp}>
      {DAYS_OF_WEEK.map((d, i) => <option key={i} value={i}>{d}</option>)}
    </select>
  );

  return (
    <div className="space-y-4 rounded-xl border border-indigo-100 bg-indigo-50/30 p-3">
      <div className="flex items-center gap-2 text-indigo-700">
        <Clock size={14} />
        <span className="text-sm font-semibold">Scheduling Windows</span>
      </div>

      {/* Order windows */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className={lbl + " !mb-0"}>Order Windows</span>
          <button type="button" onClick={addOrder}
            className="flex items-center gap-1 text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-2 py-1 rounded-lg transition">
            <Plus size={11} /> Add
          </button>
        </div>
        {order_windows.length === 0 && <p className="text-xs text-gray-400">No order windows added.</p>}
        {order_windows.map((w, i) => (
          <div key={i} className="bg-white rounded-lg border border-gray-100 p-2 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-gray-500">Window {i + 1}</span>
              <button type="button" onClick={() => removeOrder(i)} className="p-1 text-red-500 hover:bg-red-50 rounded-lg"><Trash2 size={14} /></button>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div className="col-span-2"><label className={lbl}>Day</label><DaySelect value={w.day_of_week} onSelect={v => updateOrder(i, { day_of_week: v })} /></div>
              <div><label className={lbl}>From</label><input type="time" className={inp} value={w.time_from} onChange={e => updateOrder(i, { time_from: e.target.value })} /></div>
              <div><label className={lbl}>To</label><input type="time" className={inp} value={w.time_to} onChange={e => updateOrder(i, { time_to: e.target.value })} /></div>
            </div>
          </div>
        ))}
      </div>

      {/* Delivery windows */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className={lbl + " !mb-0"}>Delivery Windows</span>
          <button type="button" onClick={addDelivery}
            className="flex items-center gap-1 text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-2 py-1 rounded-lg transition">
            <Plus size={11} /> Add
          </button>
        </div>
        {delivery_windows.length === 0 && <p className="text-xs text-gray-400">No delivery windows added.</p>}
        {delivery_windows.map((w, i) => (
          <div key={i} className="bg-white rounded-lg border border-gray-100 p-2 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-gray-500">Window {i + 1}</span>
              <button type="button" onClick={() => removeDelivery(i)} className="p-1 text-red-500 hover:bg-red-50 rounded-lg"><Trash2 size={14} /></button>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div className="col-span-2"><label className={lbl}>Day</label><DaySelect value={w.day_of_week} onSelect={v => updateDelivery(i, { day_of_week: v })} /></div>
              <div><label className={lbl}>From</label><input type="time" className={inp} value={w.time_from} onChange={e => updateDelivery(i, { time_from: e.target.value })} /></div>
              <div><label className={lbl}>To</label><input type="time" className={inp} value={w.time_to} onChange={e => updateDelivery(i, { time_to: e.target.value })} /></div>
              <div className="col-span-2"><label className={lbl}>Max Orders</label><input type="number" min="0" className={inp} placeholder="10" value={w.max_orders} onChange={e => updateDelivery(i, { max_orders: e.target.value })} /></div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Shared: Listing fields form ───────────────────────────────────────────────
function ListingFields({ form, onChange, markupRatio, hasWindow = false, hideStockLimits = false }: {
  form: ListingForm;
  onChange: (p: Partial<ListingForm>) => void;
  markupRatio?: number;
  hasWindow?: boolean;
  hideStockLimits?: boolean;
}) {
  const inp = "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white";
  const lbl = "block text-xs font-medium text-gray-600 mb-1";
  const n = (key: keyof ListingForm) => (e: React.ChangeEvent<HTMLInputElement>) =>
    onChange({ [key]: e.target.value });

  const costNum = parseFloat(form.cost_price);
  const computedPrice =
    markupRatio && !isNaN(costNum) && costNum > 0
      ? (costNum * markupRatio).toFixed(2)
      : null;

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        <div><label className={lbl}>Cost Price (EGP)</label>
          <input type="number" step="0.01" min="0" className={inp} placeholder="0.00"
            value={form.cost_price} onChange={n("cost_price")} /></div>
        <div>
          <label className={lbl}>Selling Price (EGP) <span className="text-gray-400 font-normal">· set by admin</span></label>
          <div className="w-full border border-gray-200 bg-gray-50 rounded-lg px-3 py-2 text-sm text-gray-500 cursor-not-allowed select-none flex items-center justify-between">
            <span>{computedPrice ? `${computedPrice} EGP` : form.price ? `${form.price} EGP` : "—"}</span>
            {computedPrice && (
              <span className="text-xs text-indigo-400">auto (cost × {markupRatio}×)</span>
            )}
          </div>
        </div>
      </div>
      {(!hideStockLimits || !hasWindow) && (
        <div className="grid grid-cols-2 gap-3">
          <div><label className={lbl}>Stock</label>
            <input type="number" min="0" className={inp} placeholder="0"
              value={form.stock} onChange={n("stock")} /></div>
          {!hideStockLimits && (
            <div><label className={lbl}>Min Stock Alert</label>
              <input type="number" min="0" className={inp} placeholder="0"
                value={form.min_stock} onChange={n("min_stock")} /></div>
          )}
        </div>
      )}
      {hasWindow ? (
        <WindowsEditor
          order_windows={form.order_windows}
          delivery_windows={form.delivery_windows}
          onChange={onChange}
        />
      ) : (
        <div className="grid grid-cols-2 gap-3">
          <div><label className={lbl}>Est. Time From (min)</label>
            <input type="number" min="0" className={inp} placeholder="15"
              value={form.estimated_time_from} onChange={n("estimated_time_from")} /></div>
          <div><label className={lbl}>Est. Time To (min)</label>
            <input type="number" min="0" className={inp} placeholder="30"
              value={form.estimated_time_to} onChange={n("estimated_time_to")} /></div>
        </div>
      )}
      {!hideStockLimits && (
        <div className="grid grid-cols-2 gap-3">
          <div><label className={lbl}>Min per Order</label>
            <input type="number" min="1" className={inp} placeholder="1"
              value={form.min_amount_for_one_order} onChange={n("min_amount_for_one_order")} /></div>
          <div><label className={lbl}>Max per Order</label>
            <input type="number" min="1" className={inp} placeholder="—"
              value={form.max_amount_for_one_order} onChange={n("max_amount_for_one_order")} /></div>
        </div>
      )}
      {!hideStockLimits && (
        <div className="grid grid-cols-2 gap-3">
          <div><label className={lbl}>Min per User</label>
            <input type="number" min="1" className={inp} placeholder="1"
              value={form.min_amount_for_one_user} onChange={n("min_amount_for_one_user")} /></div>
          <div><label className={lbl}>Max per User</label>
            <input type="number" min="1" className={inp} placeholder="—"
              value={form.max_amount_for_one_user} onChange={n("max_amount_for_one_user")} /></div>
        </div>
      )}
      <div className="flex flex-wrap gap-5 pt-1">
        {([["is_active", "Active (visible)"]] as [keyof ListingForm, string][]).map(([key, label]) => (
          <label key={key} className="flex items-center gap-2 cursor-pointer select-none">
            <input type="checkbox" checked={!!form[key]}
              onChange={e => onChange({ [key]: e.target.checked } as any)}
              className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
            <span className="text-sm text-gray-700">{label}</span>
          </label>
        ))}
      </div>
    </div>
  );
}

function formToPayload(form: ListingForm, hasWindow = false, markupRatio?: number) {
  const costCents = toCents(form.cost_price);
  // Selling price is admin-set via markup ratio: always derive from cost × markup when possible.
  const priceCents =
    costCents != null && markupRatio
      ? Math.round(costCents * markupRatio)
      : (form.price ? toCents(form.price) : undefined);
  return {
    price: priceCents,
    cost_price: costCents,
    stock: Number(form.stock),
    min_stock: Number(form.min_stock),
    is_active: form.is_active,
    is_featured: form.is_featured,
    ...(form.pickup_ready_duration ? { pickup_ready_duration: Number(form.pickup_ready_duration) } : {}),
    // When the category uses scheduling windows, send windows instead of est. times
    ...(hasWindow
      ? {
          order_windows: form.order_windows.map(w => ({
            day_of_week: Number(w.day_of_week),
            time_from: w.time_from,
            time_to: w.time_to,
          })),
          delivery_windows: form.delivery_windows.map(w => ({
            day_of_week: Number(w.day_of_week),
            time_from: w.time_from,
            time_to: w.time_to,
            max_orders: Number(w.max_orders) || 0,
          })),
        }
      : {
          ...(form.estimated_time_from ? { estimated_time_from: Number(form.estimated_time_from) } : {}),
          ...(form.estimated_time_to ? { estimated_time_to: Number(form.estimated_time_to) } : {}),
        }),
    ...(form.min_amount_for_one_order ? { min_amount_for_one_order: Number(form.min_amount_for_one_order) } : {}),
    ...(form.max_amount_for_one_order ? { max_amount_for_one_order: Number(form.max_amount_for_one_order) } : {}),
    ...(form.min_amount_for_one_user ? { min_amount_for_one_user: Number(form.min_amount_for_one_user) } : {}),
    ...(form.max_amount_for_one_user ? { max_amount_for_one_user: Number(form.max_amount_for_one_user) } : {}),
  };
}

/**
 * Convert user-entered display value → API value (cents or percent).
 * - PERCENT: value is the raw percentage number (e.g. 15 → send 15)
 * - FIXED_CENTS: user enters EGP (e.g. 50) → send 5000 piastres
 */
function offerDisplayToApi(displayValue: number, offerType: "PERCENT" | "FIXED_CENTS"): number {
  if (offerType === "FIXED_CENTS") return Math.round(displayValue * 100);
  return displayValue; // PERCENT: send as-is
}

/** Format an offer value for badge/list display */
function fmtOfferValue(offer: Pick<Offer, "offer_type" | "offer_value">): string {
  if (!offer.offer_value) return "—";
  if (offer.offer_type === "PERCENT") return `${offer.offer_value}%`;
  if (offer.offer_type === "FIXED_CENTS") return `-${(offer.offer_value / 100).toFixed(2)} EGP`;
  return String(offer.offer_value);
}

// ── Shared: Offer fields form ─────────────────────────────────────────────────
// NOTE: offer_value in this form is the DISPLAY value (EGP for FIXED_CENTS, % for PERCENT).
// Call offerDisplayToApi() before sending to the API.
function OfferFields({ form, onChange }: {
  form: Partial<OfferPayload & { _displayValue?: number }>;
  onChange: (p: Partial<OfferPayload>) => void;
}) {
  const inp = "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white";
  const lbl = "block text-xs font-medium text-gray-600 mb-1";
  const isFixed = form.offer_type === "FIXED_CENTS";

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>Discount Type</label>
          <select value={form.offer_type ?? "PERCENT"}
            onChange={e => onChange({ offer_type: e.target.value as any, offer_value: 0 })}
            className={inp}>
            <option value="PERCENT">Percentage (%)</option>
            <option value="FIXED_CENTS">Fixed Amount (EGP)</option>
          </select>
        </div>
        <div>
          <label className={lbl}>
            {isFixed ? "Amount (EGP)" : "Percentage (%)"}
          </label>
          <div className="relative">
            <input
              type="number"
              step={isFixed ? "0.01" : "0.5"}
              min="0"
              max={isFixed ? undefined : "100"}
              placeholder={isFixed ? "50.00" : "15"}
              value={form.offer_value ?? ""}
              onChange={e => onChange({ offer_value: Number(e.target.value) })}
              className={inp + " pr-10"}
            />
            <span className="absolute inset-y-0 right-3 flex items-center text-xs text-gray-400 pointer-events-none">
              {isFixed ? "EGP" : "%"}
            </span>
          </div>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div><label className={lbl}>Start Date *</label>
          <input type="date" value={form.start_date ?? ""}
            onChange={e => onChange({ start_date: e.target.value })} className={inp} /></div>
        <div><label className={lbl}>End Date *</label>
          <input type="date" value={form.end_date ?? ""}
            onChange={e => onChange({ end_date: e.target.value })} className={inp} /></div>
      </div>
      <label className="flex items-center gap-2 cursor-pointer select-none">
        <input type="checkbox" checked={!!form.is_active}
          onChange={e => onChange({ is_active: e.target.checked })}
          className="rounded border-gray-300 text-green-600 focus:ring-green-500" />
        <span className="text-sm text-gray-700">Active offer</span>
      </label>
    </div>
  );
}

// ── Offers section for one supplier product ───────────────────────────────────
function OffersSection({ sp }: { sp: SupplierProduct }) {
  const qc = useQueryClient();

  // ── Add state ──────────────────────────────────────────────────────────────
  const [adding, setAdding] = useState(false);
  const emptyAddForm = (): OfferPayload => ({
    supplier_product_id: sp.id,
    offer_type: "PERCENT", offer_value: 0,
    start_date: today(), end_date: nextMonth(), is_active: true,
  });
  const [addForm, setAddForm] = useState<OfferPayload>(emptyAddForm);

  // ── Edit state ─────────────────────────────────────────────────────────────
  const [editingOfferId, setEditingOfferId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState<Partial<OfferPayload>>({});

  // ── Delete confirm state ───────────────────────────────────────────────────
  const [deleteId, setDeleteId] = useState<number | null>(null);

  // ── Query ──────────────────────────────────────────────────────────────────
  const { data: offers = [], isLoading } = useQuery<Offer[]>({
    queryKey: ["offers-sp", sp.id],
    queryFn: async () => {
      const res = await supplierApi.get("/product/offers", {
        params: { supplier_product_id: sp.id, limit: 9999 },
      });
      const d = res.data?.data ?? res.data;
      if (Array.isArray(d)) return d;
      if (Array.isArray(d?.offers)) return d.offers;
      return [];
    },
    staleTime: 30_000,
  });

  // ── Mutations ──────────────────────────────────────────────────────────────
  const createMut = useMutation({
    mutationFn: (p: OfferPayload) =>
      supplierApi.post("/product/offers", {
        ...p,
        offer_value: offerDisplayToApi(p.offer_value, p.offer_type),
        start_date: p.start_date, end_date: p.end_date,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["offers-sp", sp.id] });
      toast.success("Offer created");
      setAdding(false);
      setAddForm(emptyAddForm());
    },
    onError: (e: any) =>
      toast.error(e.response?.data?.message || e.response?.data?.errors?.[0]?.message || "Error"),
  });

  const updateMut = useMutation({
    mutationFn: ({ id, patch }: { id: number; patch: Partial<OfferPayload> }) =>
      supplierApi.patch(`/product/offers/${id}`, {
        ...patch,
        ...(patch.offer_value !== undefined && patch.offer_type
          ? { offer_value: offerDisplayToApi(patch.offer_value, patch.offer_type) }
          : patch.offer_value !== undefined
          ? { offer_value: patch.offer_value } // type unchanged — server keeps existing
          : {}),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["offers-sp", sp.id] });
      toast.success("Offer updated");
      setEditingOfferId(null);
      setEditForm({});
    },
    onError: (e: any) =>
      toast.error(e.response?.data?.message || e.response?.data?.errors?.[0]?.message || "Error"),
  });

  const deleteMut = useMutation({
    mutationFn: (id: number) => supplierApi.delete(`/product/offers/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["offers-sp", sp.id] });
      toast.success("Offer deleted");
      setDeleteId(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  function startEdit(offer: Offer) {
    // Pre-populate edit form with current API values converted back to display values
    const displayValue =
      offer.offer_value == null
        ? 0
        : offer.offer_type === "FIXED_CENTS"
        ? offer.offer_value / 100 // piastres → EGP
        : offer.offer_value;      // percent stays as-is

    setEditingOfferId(offer.id);
    setEditForm({
      offer_type: offer.offer_type ?? "PERCENT",
      offer_value: displayValue,
      start_date: offer.start_date?.slice(0, 10) ?? today(),
      end_date: offer.end_date?.slice(0, 10) ?? nextMonth(),
      is_active: offer.is_active ?? true,
    });
  }

  const productName = sp.product?.name ?? `Product #${sp.product_id}`;

  return (
    <div className="border border-gray-200 rounded-xl overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-gray-50 border-b border-gray-100">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full bg-indigo-100 flex items-center justify-center text-xs font-bold text-indigo-700 shrink-0">
            {productName.charAt(0).toUpperCase()}
          </div>
          <span className="text-sm font-semibold text-gray-800 truncate max-w-[200px]">{productName}</span>
          <span className="text-xs bg-white border border-gray-200 text-gray-500 px-2 py-0.5 rounded-full shrink-0">
            {offers.length} offer{offers.length !== 1 ? "s" : ""}
          </span>
          {sp.price != null && (
            <span className="text-xs text-green-600 font-medium">{fmt(sp.price)}</span>
          )}
        </div>
        {!adding && editingOfferId === null && (
          <button onClick={() => setAdding(true)}
            className="flex items-center gap-1.5 text-xs bg-green-600 hover:bg-green-700 text-white px-2.5 py-1.5 rounded-lg transition">
            <Plus size={12} /> Add Offer
          </button>
        )}
      </div>

      <div className="bg-white">
        {/* ── Add form ── */}
        {adding && (
          <div className="border-b border-gray-100 p-4 bg-green-50/30">
            <div className="flex items-center justify-between mb-3">
              <h4 className="text-sm font-semibold text-green-700">New Offer</h4>
              <button onClick={() => { setAdding(false); setAddForm(emptyAddForm()); }}
                className="p-1 hover:bg-green-100 rounded-lg"><X size={15} /></button>
            </div>
            <OfferFields form={addForm} onChange={p => setAddForm(f => ({ ...f, ...p } as OfferPayload))} />
            <div className="flex gap-2 mt-3">
              <button onClick={() => { setAdding(false); setAddForm(emptyAddForm()); }}
                className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">Cancel</button>
              <button onClick={() => createMut.mutate(addForm)} disabled={createMut.isPending}
                className="flex-1 bg-green-600 hover:bg-green-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
                {createMut.isPending ? "Saving…" : "Add Offer"}
              </button>
            </div>
          </div>
        )}

        {isLoading && (
          <div className="p-4 space-y-2">
            {[0, 1].map(i => <div key={i} className="h-12 bg-gray-100 rounded-lg animate-pulse" />)}
          </div>
        )}

        {!isLoading && offers.length === 0 && !adding && (
          <div className="py-8 text-center text-gray-400 text-sm">
            <Percent size={24} className="mx-auto mb-2 text-gray-300" /> No offers yet
          </div>
        )}

        {offers.map(offer => {
          const isSupplierOwned = offer.created_by_role === "SUPPLIER";
          const isEditing = editingOfferId === offer.id;

          return (
            <div key={offer.id} className="border-b border-gray-50 last:border-0">
              {/* ── Inline edit form ── */}
              {isEditing ? (
                <div className="p-4 bg-indigo-50/30 border-b border-indigo-100">
                  <div className="flex items-center justify-between mb-3">
                    <h4 className="text-sm font-semibold text-indigo-700 flex items-center gap-1.5">
                      <Pencil size={13} /> Edit Offer
                    </h4>
                    <button onClick={() => { setEditingOfferId(null); setEditForm({}); }}
                      className="p-1 hover:bg-indigo-100 rounded-lg"><X size={15} /></button>
                  </div>
                  <OfferFields
                    form={editForm as Partial<OfferPayload>}
                    onChange={p => setEditForm(f => ({ ...f, ...p }))}
                  />
                  <div className="flex gap-2 mt-3">
                    <button onClick={() => { setEditingOfferId(null); setEditForm({}); }}
                      className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">
                      Cancel
                    </button>
                    <button
                      onClick={() => updateMut.mutate({ id: offer.id, patch: editForm as Partial<OfferPayload> })}
                      disabled={updateMut.isPending}
                      className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
                      {updateMut.isPending ? "Saving…" : "Save Changes"}
                    </button>
                  </div>
                </div>
              ) : (
                /* ── Offer row ── */
                <div className="flex items-center gap-3 px-4 py-3 hover:bg-gray-50 transition">
                  <div className={cn(
                    "w-11 h-11 rounded-xl flex items-center justify-center shrink-0 text-xs font-bold text-center leading-tight",
                    offer.offer_type === "PERCENT" ? "bg-green-100 text-green-700" : "bg-blue-100 text-blue-700",
                  )}>
                    {fmtOfferValue(offer)}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium",
                        offer.is_active ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500")}>
                        {offer.is_active ? "Active" : "Inactive"}
                      </span>
                      <span className="text-xs text-gray-400">
                        {offer.offer_type === "PERCENT" ? "Percentage" : "Fixed (EGP)"}
                      </span>
                      {!isSupplierOwned && (
                        <span className="text-xs px-2 py-0.5 bg-amber-50 text-amber-600 rounded-full border border-amber-100">
                          Admin offer · read-only
                        </span>
                      )}
                    </div>
                    {offer.start_date && (
                      <p className="text-xs text-gray-400 mt-0.5">
                        {new Date(offer.start_date).toLocaleDateString()}
                        {offer.end_date && ` → ${new Date(offer.end_date).toLocaleDateString()}`}
                      </p>
                    )}
                  </div>

                  {/* Actions — supplier-owned only */}
                  <div className="flex items-center gap-1 shrink-0">
                    {isSupplierOwned ? (
                      deleteId === offer.id ? (
                        <>
                          <button onClick={() => deleteMut.mutate(offer.id)} disabled={deleteMut.isPending}
                            className="px-2 py-1 bg-red-600 text-white text-xs rounded-lg disabled:opacity-60">Yes</button>
                          <button onClick={() => setDeleteId(null)}
                            className="px-2 py-1 border text-xs rounded-lg hover:bg-gray-50">No</button>
                        </>
                      ) : (
                        <>
                          {/* Edit */}
                          <button onClick={() => startEdit(offer)}
                            title="Edit offer"
                            className="p-1.5 hover:bg-indigo-50 text-indigo-500 rounded-lg transition">
                            <Pencil size={13} />
                          </button>
                          {/* Toggle active */}
                          <button
                            onClick={() => updateMut.mutate({ id: offer.id, patch: { is_active: !offer.is_active } })}
                            disabled={updateMut.isPending}
                            title={offer.is_active ? "Deactivate" : "Activate"}
                            className={cn("p-1.5 rounded-lg transition",
                              offer.is_active ? "hover:bg-gray-100 text-gray-500" : "hover:bg-green-50 text-green-600")}>
                            {offer.is_active ? <ToggleRight size={16} /> : <ToggleLeft size={16} />}
                          </button>
                          {/* Delete */}
                          <button onClick={() => setDeleteId(offer.id)}
                            className="p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition">
                            <Trash2 size={13} />
                          </button>
                        </>
                      )
                    ) : (
                      <span className="text-lg text-gray-300" title="Admin-created — read only">🔒</span>
                    )}
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Listing Card (My Listings tab) ────────────────────────────────────────────
function ListingCard({ sp, onEdit, isEditing, editForm, onFormChange, onSave, onCancelEdit, isSaving, onUnsupply, isUnsupplying, markupRatio }: {
  sp: SupplierProduct; onEdit: () => void;
  isEditing: boolean; editForm: ListingForm;
  onFormChange: (p: Partial<ListingForm>) => void;
  onSave: (hasWindow: boolean) => void; onCancelEdit: () => void; isSaving: boolean;
  onUnsupply: () => void; isUnsupplying: boolean;
  markupRatio?: number;
}) {
  const [expanded, setExpanded] = useState(false);
  const [confirmUnsupply, setConfirmUnsupply] = useState(false);
  const img = firstImage(sp.product?.images);
  const productName = sp.product?.name ?? `Product #${sp.product_id}`;

  // Resolve the product's category to know has_window (listing endpoint omits it)
  const catId = sp.product?.category?.id ?? sp.product?.category_id;
  const { data: cat } = useQuery({
    queryKey: ["category", catId],
    queryFn: () => fetchCategory(catId!),
    enabled: !!catId,
    staleTime: 5 * 60 * 1000,
  });
  const hasWindow = !!(cat?.has_window ?? categoryHasWindow(sp.product));

  // Load this listing's order/delivery windows (shown in info view + used for editing)
  const { data: windowsData } = useQuery({
    queryKey: ["sp-windows", sp.id],
    queryFn: async () => {
      const res = await supplierApi.get(
        `/product/get-supplier-product-delivery-windows/${sp.id}/${sp.supplier_id}`,
      );
      return res.data?.data ?? res.data;
    },
    enabled: (expanded || isEditing) && hasWindow,
    staleTime: 0,
    refetchOnWindowFocus: false,
  });
  const allWindows: any[] = Array.isArray(windowsData?.windows) ? windowsData.windows : [];
  const orderWins = allWindows.filter(w => w.window_type === "ORDER");
  const deliveryWins = allWindows.filter(w => w.window_type === "DELIVERY");

  return (
    <div className={cn("border rounded-xl overflow-hidden transition-all",
      isEditing ? "border-indigo-300 shadow-md" : "border-gray-200 hover:border-gray-300")}>
      <div className="flex items-center gap-3 px-4 py-3 bg-white">
        {/* Thumbnail */}
        {img ? (
          <img src={img} alt={productName} className="w-10 h-10 rounded-lg object-cover border border-gray-100 shrink-0" />
        ) : (
          <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
            <Package size={16} className="text-gray-300" />
          </div>
        )}

        {/* Name + category */}
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-gray-900 truncate">{productName}</p>
          {sp.product?.category?.name && <p className="text-xs text-gray-400">{sp.product.category.name}</p>}
          <p className={`text-xs font-medium mt-0.5 ${sp.is_active ? "text-green-600" : "text-gray-400"}`}>
            {sp.is_active ? "Active" : "Inactive"}
          </p>
        </div>

        {/* Quick price stats */}
        <div className="hidden md:flex items-center gap-4 text-xs">
          <div>
            <p className="text-gray-400">Cost (you pay)</p>
            <p className="text-indigo-700 font-semibold">{fmt(sp.cost_price)}</p>
          </div>
          <div>
            <p className="text-gray-400">Selling (customer)</p>
            <p className="text-green-700 font-semibold">{fmt(sp.price)}</p>
          </div>
          <div>
            <p className="text-gray-400">Stock</p>
            <p className={`font-semibold ${sp.stock < (sp.min_stock || 5) ? "text-red-500" : "text-gray-700"}`}>{sp.stock}</p>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-1 shrink-0">
          <button onClick={() => isEditing ? onCancelEdit() : onEdit()}
            className={cn("p-1.5 rounded-lg transition", isEditing ? "bg-indigo-100 text-indigo-700" : "hover:bg-indigo-50 text-indigo-600")}
            title={isEditing ? "Cancel edit" : "Edit"}>
            <Pencil size={14} />
          </button>
          <button onClick={() => setExpanded(e => !e)}
            className="p-1.5 hover:bg-gray-100 text-gray-400 rounded-lg transition">
            {expanded || isEditing ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
          </button>
        </div>
      </div>

      {(expanded || isEditing) && (
        <div className="border-t border-gray-100 p-4 bg-gray-50/40">
          {isEditing ? (
            <>
              <ListingFields form={editForm} onChange={onFormChange} markupRatio={markupRatio} hasWindow={hasWindow} />
              <div className="flex gap-2 mt-4">
                <button onClick={onCancelEdit}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">Cancel</button>
                <button onClick={() => onSave(hasWindow)} disabled={isSaving}
                  className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
                  {isSaving ? "Saving…" : "Save Changes"}
                </button>
              </div>
            </>
          ) : (
            <div className="space-y-3">
            <div className="grid grid-cols-2 gap-2 text-xs">
              {/* Price row — highlight both cost (supplier pays) and selling (customer pays) */}
              <div className="bg-indigo-50 rounded-lg border border-indigo-100 px-3 py-2">
                <p className="text-indigo-400 text-xs mb-0.5">Cost Price (you pay)</p>
                <p className="font-bold text-indigo-700">{fmt(sp.cost_price)}</p>
              </div>
              <div className="bg-green-50 rounded-lg border border-green-100 px-3 py-2">
                <p className="text-green-400 text-xs mb-0.5">Selling Price (customer pays)</p>
                <p className="font-bold text-green-700">{fmt(sp.price)}</p>
              </div>
              {[
                ["Stock", String(sp.stock)],
                ["Min Stock Alert", String(sp.min_stock)],
                ...(hasWindow ? [] : [
                  ["Est. Time From", sp.estimated_time_from != null ? `${sp.estimated_time_from} min` : "—"],
                  ["Est. Time To", sp.estimated_time_to != null ? `${sp.estimated_time_to} min` : "—"],
                ] as [string, string][]),
                ["Min/Order", String(sp.min_amount_for_one_order ?? "—")],
                ["Max/Order", String(sp.max_amount_for_one_order ?? "—")],
                ["Min/User", String(sp.min_amount_for_one_user ?? "—")],
                ["Max/User", String(sp.max_amount_for_one_user ?? "—")],
                ["Rating", sp.rating != null ? `⭐ ${sp.rating}` : "—"],
                ["Reviews", String(sp.total_reviews ?? 0)],
                ["Reserved in Carts", String(sp.reserved_in_carts_amount ?? 0)],
              ].map(([label, value]) => (
                <div key={label} className="bg-white rounded-lg border border-gray-100 px-3 py-2">
                  <p className="text-gray-400 text-xs mb-0.5">{label}</p>
                  <p className="font-semibold text-gray-800">{value}</p>
                </div>
              ))}
            </div>

            {/* Scheduling windows info (window categories only) */}
            {hasWindow && (
              <div className="rounded-xl border border-indigo-100 bg-indigo-50/30 p-3 space-y-3">
                <div className="flex items-center gap-2 text-indigo-700">
                  <Clock size={14} />
                  <span className="text-sm font-semibold">Scheduling Windows</span>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <p className="text-xs font-semibold text-gray-600 mb-1">Order Windows</p>
                    {orderWins.length === 0 ? (
                      <p className="text-xs text-gray-400">—</p>
                    ) : (
                      <ul className="space-y-1">
                        {orderWins.map((w, i) => (
                          <li key={w.id ?? i} className="text-xs bg-white rounded-lg border border-gray-100 px-2 py-1 flex items-center justify-between">
                            <span className="font-medium text-gray-700">{DAYS_OF_WEEK[w.day_of_week] ?? `Day ${w.day_of_week}`}</span>
                            <span className="text-gray-500">{hhmm(w.time_from)}–{hhmm(w.time_to)}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                  <div>
                    <p className="text-xs font-semibold text-gray-600 mb-1">Delivery Windows</p>
                    {deliveryWins.length === 0 ? (
                      <p className="text-xs text-gray-400">—</p>
                    ) : (
                      <ul className="space-y-1">
                        {deliveryWins.map((w, i) => (
                          <li key={w.id ?? i} className="text-xs bg-white rounded-lg border border-gray-100 px-2 py-1 flex items-center justify-between gap-2">
                            <span className="font-medium text-gray-700">{DAYS_OF_WEEK[w.day_of_week] ?? `Day ${w.day_of_week}`}</span>
                            <span className="text-gray-500">{hhmm(w.time_from)}–{hhmm(w.time_to)}</span>
                            <span className="text-indigo-600 font-medium shrink-0">max {w.max_orders ?? "—"}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* Un-supply (remove listing) — last in the details block */}
            <div className="pt-2 border-t border-gray-100 flex justify-end">
              {confirmUnsupply ? (
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">Remove this listing?</span>
                  <button onClick={onUnsupply} disabled={isUnsupplying}
                    className="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white text-xs font-medium rounded-lg disabled:opacity-60 flex items-center gap-1.5 transition">
                    {isUnsupplying ? <Loader2 size={12} className="animate-spin" /> : <Trash2 size={12} />} Yes, remove
                  </button>
                  <button onClick={() => setConfirmUnsupply(false)} disabled={isUnsupplying}
                    className="px-3 py-1.5 border border-gray-300 text-xs rounded-lg hover:bg-gray-50 transition">Cancel</button>
                </div>
              ) : (
                <button onClick={() => setConfirmUnsupply(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-red-600 border border-red-200 hover:bg-red-50 rounded-lg transition">
                  <Trash2 size={13} /> Un-supply this product
                </button>
              )}
            </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────
type Tab = "my" | "offers" | "browse";

export default function SupplierProductsPage() {
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("my");

  // My listings state
  const [myPage, setMyPage] = useState(1);
  const myLimit = 20;

  // Edit state
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editForms, setEditForms] = useState<Record<number, ListingForm>>({});

  // Browse state
  const [browsePage, setBrowsePage] = useState(1);
  const [keyword, setKeyword] = useState("");
  const browseLimit = 20;

  // Add listing modal
  const [addForProduct, setAddForProduct] = useState<Product | null>(null);
  const [addForm, setAddForm] = useState<ListingForm>(emptyListingForm());
  const [windowConfirm, setWindowConfirm] = useState<{ orderEmpty: boolean; deliveryEmpty: boolean } | null>(null);

  // Resolve the category of the product being supplied to know has_window
  // (the product list endpoint doesn't include has_window on the category)
  const addCategoryId = addForProduct?.category?.id ?? addForProduct?.category_id;
  const { data: addCategory } = useQuery({
    queryKey: ["category", addCategoryId],
    queryFn: () => fetchCategory(addCategoryId!),
    enabled: !!addForProduct && !!addCategoryId,
    staleTime: 5 * 60 * 1000,
  });
  const addHasWindow = !!(addCategory?.has_window ?? categoryHasWindow(addForProduct));

  // ── Supplier profile (for markup_ratio) ───────────────────────────────────
  const { user } = useRole();
  const profileUserId = user?.id ?? getCurrentUserId();
  const { data: profileData } = useQuery({
    queryKey: ["supplier-profile", profileUserId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/get-profile/${profileUserId}`);
      // shape: { data: { user: { ..., supplier: { markup_ratio } } } }
      return res.data?.data?.user ?? res.data?.data;
    },
    enabled: !!profileUserId,
    staleTime: 5 * 60 * 1000,
  });
  // markup_ratio lives at data.user.supplier.markup_ratio
  const markupRatio: number = profileData?.supplier?.markup_ratio ?? 1.3;
  // The current supplier's own id (supplier.id, not user.id) — used to scope "my" data.
  // The list endpoint returns every supplier's rows, so we filter by this.
  const currentSupplierId: number | undefined = profileData?.supplier?.id;

  // ── Queries ────────────────────────────────────────────────────────────────
  const { data: myData, isLoading: myLoading, refetch: refetchMy, isFetching: myFetching } = useQuery({
    queryKey: ["supplier-products", myPage],
    queryFn: async () => {
      const res = await supplierApi.get("/product/list-supplier-products", {
        params: { limit: myLimit, skip: (myPage - 1) * myLimit, includes: "product" },
      });
      return res.data?.data ?? res.data;
    },
    staleTime: 0, // always fresh after mutations
  });

  const { data: browseData, isLoading: browseLoading, isFetching: browseFetching, refetch: refetchBrowse } = useQuery({
    queryKey: ["all-products", browsePage, keyword],
    queryFn: async () => {
      const res = await supplierApi.get("/product/list-products", {
        params: { limit: browseLimit, skip: (browsePage - 1) * browseLimit, ...(keyword ? { keyword } : {}) },
      });
      return res.data?.data ?? res.data;
    },
    staleTime: 60_000,
    enabled: tab === "browse",
  });

  const myItems: SupplierProduct[] = Array.isArray(myData?.supplierProducts)
    ? myData.supplierProducts
    : [];
  const myTotal = myData?.totalSupplierProducts ?? myItems.length;
  const myPages = Math.ceil(myTotal / myLimit) || 1;

  const browseItems: Product[] = Array.isArray(browseData?.products) ? browseData.products : [];
  const browseTotal = browseData?.totalProducts ?? browseItems.length;
  const browsePages = Math.ceil(browseTotal / browseLimit) || 1;

  // Product IDs the CURRENT supplier already lists, from the page we have loaded.
  // Strictly scoped to our own supplier_id (the endpoint returns all suppliers' rows).
  const myProductIds = new Set(
    myItems.filter(sp => sp.supplier_id === currentSupplierId).map(sp => sp.product_id),
  );

  // Complete set of product IDs this supplier lists — drives the Browse "You supply this"
  // badge. The My Listings query above is paginated, so it can't be relied on across pages;
  // this fetches all of the current supplier's listings in one shot.
  const { data: suppliedProductIds } = useQuery({
    queryKey: ["supplied-product-ids", currentSupplierId],
    queryFn: async () => {
      const res = await supplierApi.get("/product/list-supplier-products", {
        params: { limit: 9999, supplier_id: currentSupplierId },
      });
      const data = res.data?.data ?? res.data;
      const list: SupplierProduct[] = Array.isArray(data?.supplierProducts) ? data.supplierProducts : [];
      // Filter client-side too, in case the endpoint ignores the supplier_id param.
      return new Set(
        list.filter(sp => sp.supplier_id === currentSupplierId).map(sp => sp.product_id),
      );
    },
    enabled: tab === "browse" && currentSupplierId != null,
    staleTime: 30_000,
  });

  // ── Load existing order/delivery windows for the listing being edited ───────
  const editingSp = myItems.find(sp => sp.id === editingId);
  const { data: editWindows } = useQuery({
    queryKey: ["sp-windows", editingId],
    queryFn: async () => {
      const res = await supplierApi.get(
        `/product/get-supplier-product-delivery-windows/${editingSp!.id}/${editingSp!.supplier_id}`,
      );
      return res.data?.data ?? res.data;
    },
    enabled: !!editingId && !!editingSp,
    staleTime: 0,
    refetchOnWindowFocus: false,
  });

  // Populate the edit form with fetched windows once they arrive
  useEffect(() => {
    if (!editingId || !Array.isArray(editWindows?.windows)) return;
    const order_windows: OrderWindow[] = editWindows.windows
      .filter((w: any) => w.window_type === "ORDER")
      .map((w: any) => ({ day_of_week: Number(w.day_of_week), time_from: hhmm(w.time_from), time_to: hhmm(w.time_to) }));
    const delivery_windows: DeliveryWindow[] = editWindows.windows
      .filter((w: any) => w.window_type === "DELIVERY")
      .map((w: any) => ({
        day_of_week: Number(w.day_of_week),
        time_from: hhmm(w.time_from),
        time_to: hhmm(w.time_to),
        max_orders: w.max_orders != null ? String(w.max_orders) : "",
      }));
    setEditForms(prev => ({ ...prev, [editingId]: { ...prev[editingId], order_windows, delivery_windows } }));
  }, [editWindows, editingId]);

  // ── Mutations ──────────────────────────────────────────────────────────────
  const addMut = useMutation({
    mutationFn: async ({ productId, form, hasWindow }: { productId: number; form: ListingForm; hasWindow: boolean }) => {
      const res = await supplierApi.post("/product/create-supplier-product", {
        product_id: productId,
        ...formToPayload(form, hasWindow, markupRatio),
      });
      // The create endpoint doesn't accept estimated_time_from/to — apply them via a follow-up update
      if (!hasWindow && (form.estimated_time_from || form.estimated_time_to)) {
        const created = res.data?.data ?? res.data;
        const newId =
          created?.id ?? created?.supplierProduct?.id ?? created?.supplier_product?.id;
        if (newId) {
          await supplierApi.patch(`/product/update-supplier-product/${newId}`, {
            ...(form.estimated_time_from ? { estimated_time_from: Number(form.estimated_time_from) } : {}),
            ...(form.estimated_time_to ? { estimated_time_to: Number(form.estimated_time_to) } : {}),
          });
        }
      }
    },
    onSuccess: () => {
      toast.success("Added to your listings");
      qc.invalidateQueries({ queryKey: ["supplier-products"] });
      qc.invalidateQueries({ queryKey: ["supplied-product-ids"] });
      setAddForProduct(null);
      setTab("my"); // switch to listings tab immediately
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to add"),
  });

  const updateMut = useMutation({
    mutationFn: async ({ id, form, hasWindow }: { id: number; form: ListingForm; hasWindow: boolean }) => {
      await supplierApi.patch(`/product/update-supplier-product/${id}`, formToPayload(form, hasWindow, markupRatio));
    },
    onSuccess: () => {
      toast.success("Updated successfully");
      qc.invalidateQueries({ queryKey: ["supplier-products"] });
      setEditingId(null);
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to update"),
  });

  const unsupplyMut = useMutation({
    mutationFn: async (id: number) => {
      await supplierApi.delete(`/product/delete-supplier-product/${id}`);
    },
    onSuccess: () => {
      toast.success("Removed from your listings");
      qc.invalidateQueries({ queryKey: ["supplier-products"] });
      qc.invalidateQueries({ queryKey: ["supplied-product-ids"] });
      setEditingId(null);
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to remove"),
  });

  function startEdit(sp: SupplierProduct) {
    setEditingId(sp.id);
    setEditForms(prev => ({ ...prev, [sp.id]: spToForm(sp) }));
  }

  function openAdd(p: Product) {
    setAddForProduct(p);
    setAddForm(emptyListingForm());
  }

  function submitAdd() {
    if (!addForProduct) return;
    if (addHasWindow) {
      const orderEmpty = addForm.order_windows.length === 0;
      const deliveryEmpty = addForm.delivery_windows.length === 0;
      if (orderEmpty || deliveryEmpty) {
        setWindowConfirm({ orderEmpty, deliveryEmpty });
        return;
      }
    }
    // Window products don't show a Stock field — default it to 50
    const form: ListingForm = addHasWindow ? { ...addForm, stock: "50" } : addForm;
    addMut.mutate({ productId: addForProduct.id, form, hasWindow: addHasWindow });
  }

  function confirmFillAndAdd() {
    if (!addForProduct || !windowConfirm) return;
    const form: ListingForm = {
      ...addForm,
      stock: "50", // window products: default stock
      order_windows: windowConfirm.orderEmpty ? fullWeekOrderWindows() : addForm.order_windows,
      delivery_windows: windowConfirm.deliveryEmpty ? fullWeekDeliveryWindows() : addForm.delivery_windows,
    };
    setWindowConfirm(null);
    addMut.mutate({ productId: addForProduct.id, form, hasWindow: addHasWindow });
  }

  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <Package2 size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">Products</h1>
            <p className="text-xs text-gray-500">Manage listings, prices, and discount offers</p>
          </div>
        </div>
        <button
          onClick={() => tab === "browse" ? refetchBrowse() : refetchMy()}
          disabled={tab === "browse" ? browseFetching : myFetching}
          className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={14} className={(tab === "browse" ? browseFetching : myFetching) ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Tabs */}
      <div className="flex bg-gray-100 rounded-xl p-1 gap-1 w-fit flex-wrap">
        {([
          ["my", "My Listings", Tag, myTotal],
          ["offers", "My Offers", Percent, null],
          ["browse", "Browse Products", ShoppingBag, null],
        ] as [Tab, string, any, number | null][]).map(([t, label, Icon, count]) => (
          <button key={t} onClick={() => setTab(t)}
            className={cn("flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition",
              tab === t ? "bg-white text-indigo-700 shadow-sm" : "text-gray-500 hover:text-gray-700")}>
            <Icon size={14} />
            {label}
            {count != null && count > 0 && (
              <span className="bg-indigo-100 text-indigo-700 text-xs px-1.5 py-0.5 rounded-full">{count}</span>
            )}
          </button>
        ))}
      </div>

      {/* ── MY LISTINGS ── */}
      {tab === "my" && (
        <>
          {/* Markup ratio info */}
          <div className="flex items-center gap-2 px-4 py-2.5 bg-indigo-50 border border-indigo-100 rounded-xl text-sm">
            <TrendingUp size={14} className="text-indigo-500 shrink-0" />
            <span className="text-indigo-700">
              Your agreed markup ratio is <strong>{markupRatio}×</strong>
              {" "}(+{((markupRatio - 1) * 100).toFixed(0)}% above cost price).
              Selling price is auto-computed when you enter cost price only.
            </span>
          </div>

          {myLoading ? (
            <div className="space-y-3">{Array.from({length:3}).map((_,i)=>(
              <div key={i} className="h-16 bg-white rounded-xl border border-gray-200 animate-pulse" />
            ))}</div>
          ) : myItems.length === 0 ? (
            <div className="text-center py-16 border-2 border-dashed border-gray-200 rounded-xl text-gray-400">
              <Tag size={40} className="mx-auto mb-3 opacity-30" />
              <p className="text-sm font-medium">No product listings yet</p>
              <p className="text-xs mt-1">Go to "Browse Products" to add yourself as a supplier</p>
            </div>
          ) : (
            <div className="space-y-3">
              {myItems.map(sp => (
                <ListingCard key={sp.id} sp={sp}
                  isEditing={editingId === sp.id}
                  editForm={editForms[sp.id] ?? emptyListingForm()}
                  onFormChange={p => setEditForms(prev => ({ ...prev, [sp.id]: { ...prev[sp.id], ...p } }))}
                  onEdit={() => startEdit(sp)}
                  onSave={(hasWindow) => updateMut.mutate({ id: sp.id, form: editForms[sp.id] ?? emptyListingForm(), hasWindow })}
                  onCancelEdit={() => setEditingId(null)}
                  isSaving={updateMut.isPending}
                  onUnsupply={() => unsupplyMut.mutate(sp.id)}
                  isUnsupplying={unsupplyMut.isPending && unsupplyMut.variables === sp.id}
                  markupRatio={markupRatio}
                />
              ))}
            </div>
          )}
          {myPages > 1 && (
            <div className="flex items-center justify-between">
              <p className="text-sm text-gray-500">Page {myPage} of {myPages} · {myTotal} listings</p>
              <div className="flex gap-2">
                <button onClick={() => setMyPage(p => Math.max(1, p - 1))} disabled={myPage === 1}
                  className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"><ChevronLeft size={16}/></button>
                <button onClick={() => setMyPage(p => Math.min(myPages, p + 1))} disabled={myPage === myPages}
                  className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"><ChevronRight size={16}/></button>
              </div>
            </div>
          )}
        </>
      )}

      {/* ── MY OFFERS ── */}
      {tab === "offers" && (
        <>
          {myItems.length === 0 ? (
            <div className="text-center py-16 border-2 border-dashed border-gray-200 rounded-xl text-gray-400">
              <Percent size={40} className="mx-auto mb-3 opacity-30" />
              <p className="text-sm font-medium">No product listings yet</p>
              <p className="text-xs mt-1">Add a product listing first, then create discount offers on it</p>
            </div>
          ) : (
            <div className="space-y-4">
              {myItems.map(sp => <OffersSection key={sp.id} sp={sp} />)}
            </div>
          )}
        </>
      )}

      {/* ── BROWSE PRODUCTS ── */}
      {tab === "browse" && (
        <>
          <div className="relative w-72">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input value={keyword} onChange={e => { setKeyword(e.target.value); setBrowsePage(1); }}
              placeholder="Search by name, keyword…"
              className="pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 w-full" />
          </div>

          {browseLoading ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {Array.from({length:8}).map((_,i) => <div key={i} className="bg-white rounded-xl border border-gray-200 h-60 animate-pulse" />)}
            </div>
          ) : browseItems.length === 0 ? (
            <div className="bg-white rounded-xl border border-gray-200 p-16 text-center">
              <ShoppingBag size={40} className="mx-auto mb-3 text-gray-300" />
              <p className="text-sm text-gray-400">No products found</p>
              {keyword && <p className="text-xs text-gray-400 mt-1">Try a different search term</p>}
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {browseItems.map(p => {
                const img = firstImage(p.images);
                const already = (suppliedProductIds ?? myProductIds).has(p.id);
                return (
                  <div key={p.id} className="bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-md transition flex flex-col">
                    {img ? (
                      <img src={img} alt={p.name} className="w-full h-32 object-cover" />
                    ) : (
                      <div className="w-full h-32 bg-gray-50 flex items-center justify-center border-b border-gray-100">
                        <Package2 size={28} className="text-gray-200" />
                      </div>
                    )}
                    <div className="p-3 flex flex-col flex-1">
                      <p className="text-sm font-semibold text-gray-900 truncate">{p.name}</p>
                      {p.category?.name && <p className="text-xs text-gray-400 truncate mt-0.5">{p.category.name}</p>}
                      <div className="mt-auto pt-3">
                        {already ? (
                          <span className="flex items-center gap-1 text-xs text-green-600 font-medium">
                            ✓ You supply this
                          </span>
                        ) : (
                          <button onClick={() => openAdd(p)}
                            className="w-full flex items-center justify-center gap-1.5 text-xs bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-1.5 font-medium transition">
                            <Plus size={13} /> Supply this product
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {browsePages > 1 && (
            <div className="flex items-center justify-between">
              <p className="text-sm text-gray-500">Page {browsePage} of {browsePages} · {browseTotal} products</p>
              <div className="flex gap-2">
                <button onClick={() => setBrowsePage(p => Math.max(1, p - 1))} disabled={browsePage === 1}
                  className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"><ChevronLeft size={16}/></button>
                <button onClick={() => setBrowsePage(p => Math.min(browsePages, p + 1))} disabled={browsePage === browsePages}
                  className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"><ChevronRight size={16}/></button>
              </div>
            </div>
          )}
        </>
      )}

      {/* ── Add Listing Modal ── */}
      {addForProduct && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 sticky top-0 bg-white">
              <div>
                <h2 className="text-base font-bold text-gray-900">Supply Product</h2>
                <p className="text-xs text-gray-500 mt-0.5 truncate max-w-[320px]">{addForProduct.name}</p>
              </div>
              <button onClick={() => setAddForProduct(null)} className="text-gray-400 hover:text-gray-600"><X size={18}/></button>
            </div>
            <div className="px-6 py-5">
              <ListingFields form={addForm} onChange={p => setAddForm(f => ({ ...f, ...p }))} markupRatio={markupRatio} hasWindow={addHasWindow} hideStockLimits />
            </div>
            <div className="flex gap-3 px-6 py-4 border-t border-gray-100 sticky bottom-0 bg-white">
              <button onClick={() => setAddForProduct(null)}
                className="flex-1 border border-gray-200 rounded-lg py-2.5 text-sm text-gray-600 hover:bg-gray-50">Cancel</button>
              <button onClick={submitAdd}
                disabled={addMut.isPending}
                className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-60 flex items-center justify-center gap-2">
                {addMut.isPending ? <><Loader2 size={14} className="animate-spin" /> Adding…</> : <><Plus size={14}/> Add Listing</>}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Missing windows confirmation ── */}
      {windowConfirm && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4 animate-fade-in">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
            <div className="flex items-start gap-3 px-6 pt-6">
              <div className="w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center shrink-0">
                <Clock size={18} className="text-amber-600" />
              </div>
              <div className="min-w-0">
                <h3 className="text-base font-bold text-gray-900">Some windows are empty</h3>
                <p className="text-sm text-gray-500 mt-1">
                  You didn't add any{" "}
                  <span className="font-semibold text-gray-700">
                    {[windowConfirm.orderEmpty && "Order Windows", windowConfirm.deliveryEmpty && "Delivery Windows"]
                      .filter(Boolean)
                      .join(" and ")}
                  </span>
                  . They will be set to{" "}
                  <span className="font-semibold text-gray-700">available every day, all day (00:00–23:59)</span>.
                </p>
              </div>
            </div>
            <div className="flex gap-3 px-6 py-5 mt-4 bg-gray-50/60">
              <button onClick={() => setWindowConfirm(null)}
                className="flex-1 border border-gray-200 bg-white rounded-lg py-2.5 text-sm text-gray-600 hover:bg-gray-50 transition">
                Go back &amp; edit
              </button>
              <button onClick={confirmFillAndAdd} disabled={addMut.isPending}
                className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-60 flex items-center justify-center gap-2 transition">
                {addMut.isPending ? <><Loader2 size={14} className="animate-spin" /> Adding…</> : "Fill & Continue"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
