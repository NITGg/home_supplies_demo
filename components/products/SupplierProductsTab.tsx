"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchProductSuppliers, fetchAllSuppliers, linkSupplierToProduct,
  updateSupplierProduct, unlinkSupplierFromProduct,
  type SupplierProduct, type SupplierProductPayload,
} from "@/lib/supplier-products";
import {
  Plus, Trash2, Pencil, X, ChevronDown, ChevronUp, Users,
  DollarSign, Package, Star, TrendingUp, Clock, Timer, ShoppingCart,
} from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";

interface Props { productId: number }

type FieldPatch = Partial<Omit<SupplierProductPayload, "supplier_id">>;

const emptyForm = (): FieldPatch => ({
  cost_price: undefined, price: undefined,
  stock: 0, min_stock: 0,
  is_active: true, is_featured: false, is_best_seller: false,
  pickup_ready_duration: undefined,
  estimated_time_from: undefined, estimated_time_to: undefined,
  max_amount_for_one_order: undefined, min_amount_for_one_order: 1,
  max_amount_for_one_user: undefined, min_amount_for_one_user: 1,
});

export default function SupplierProductsTab({ productId }: Props) {
  const qc = useQueryClient();
  const { t } = useT();
  const [showAdd, setShowAdd]       = useState(false);
  const [editingId, setEditingId]   = useState<number | null>(null);   // sp.id
  const [unlinkId, setUnlinkId]     = useState<number | null>(null);   // sp.id
  const [addSupplierId, setAddSupplierId] = useState<number>(0);
  const [addFields, setAddFields]   = useState<FieldPatch>(emptyForm());
  const [editFields, setEditFields] = useState<Record<number, FieldPatch>>({});

  // ── Data ──────────────────────────────────────────────────────────────────
  const { data: linked = [], isLoading } = useQuery({
    queryKey: ["product-suppliers", productId],
    queryFn: () => fetchProductSuppliers(productId),
  });

  // All suppliers from the supplier table (not users)
  const { data: allSuppliers = [] } = useQuery({
    queryKey: ["all-suppliers"],
    queryFn: fetchAllSuppliers,
    enabled: showAdd,
  });
  const linkedIds = new Set(linked.map(s => s.supplier_id)); // supplier.id values already linked

  // ── Mutations ─────────────────────────────────────────────────────────────
  const linkMut = useMutation({
    mutationFn: (p: SupplierProductPayload) => linkSupplierToProduct(productId, p),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["product-suppliers", productId] });
      toast.success(t("supplierProd.linked"));
      setShowAdd(false); setAddSupplierId(0); setAddFields(emptyForm());
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  const updateMut = useMutation({
    // spId = supplierProduct.id (primary key), not supplier_id
    mutationFn: ({ spId, payload }: { spId: number; payload: FieldPatch }) =>
      updateSupplierProduct(productId, spId, payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["product-suppliers", productId] });
      toast.success(t("supplierProd.updated"));
      setEditingId(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  const unlinkMut = useMutation({
    mutationFn: (spId: number) => unlinkSupplierFromProduct(productId, spId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["product-suppliers", productId] });
      toast.success(t("supplierProd.unlinked"));
      setUnlinkId(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  function startEdit(sp: SupplierProduct) {
    setEditingId(sp.id);
    setEditFields(prev => ({
      ...prev,
      [sp.id]: {
        cost_price: sp.cost_price ?? undefined,
        price: sp.price ?? undefined,
        stock: sp.stock, min_stock: sp.min_stock,
        is_active: sp.is_active, is_featured: sp.is_featured, is_best_seller: sp.is_best_seller,
        pickup_ready_duration: sp.pickup_ready_duration ?? undefined,
        estimated_time_from: sp.estimated_time_from ?? undefined,
        estimated_time_to: sp.estimated_time_to ?? undefined,
        max_amount_for_one_order: sp.max_amount_for_one_order ?? undefined,
        min_amount_for_one_order: sp.min_amount_for_one_order ?? undefined,
        max_amount_for_one_user: sp.max_amount_for_one_user ?? undefined,
        min_amount_for_one_user: sp.min_amount_for_one_user ?? undefined,
      },
    }));
  }

  if (isLoading) return (
    <div className="p-6 space-y-3">
      {[0, 1, 2].map(i => <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />)}
    </div>
  );

  return (
    <div className="p-6 space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold text-gray-700">
          {linked.length} {t("supplierProd.tabTitle")}
        </p>
        {!showAdd && (
          <button onClick={() => setShowAdd(true)}
            className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-2 rounded-lg text-sm font-medium transition">
            <Plus size={15} /> {t("supplierProd.addNew")}
          </button>
        )}
      </div>

      {/* Add form */}
      {showAdd && (
        <div className="border-2 border-indigo-200 bg-indigo-50/40 rounded-xl p-5 space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-semibold text-indigo-700">{t("supplierProd.addNew")}</h4>
            <button onClick={() => setShowAdd(false)} className="p-1 hover:bg-indigo-100 rounded-lg">
              <X size={16} />
            </button>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">{t("supplierProd.selectSupplier")} *</label>
            <select value={addSupplierId}
              onChange={e => setAddSupplierId(Number(e.target.value))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white">
              <option value={0}>{t("supplierProd.selectSupplier")}</option>
              {allSuppliers.filter(s => !linkedIds.has(s.id)).map(s => (
                <option key={s.id} value={s.id}>{s.user.full_name} — {s.user.phone}</option>
              ))}
            </select>
          </div>
          <SupplierFields form={addFields} onChange={p => setAddFields(prev => ({ ...prev, ...p }))} t={t} />
          <div className="flex gap-2 pt-1">
            <button onClick={() => setShowAdd(false)}
              className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">
              {t("common.cancel")}
            </button>
            <button onClick={() => {
              if (!addSupplierId) { toast.error(t("supplierProd.selectSupplier")); return; }
              linkMut.mutate({ supplier_id: addSupplierId, ...addFields } as SupplierProductPayload);
            }} disabled={linkMut.isPending}
              className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
              {linkMut.isPending ? t("common.saving") : t("supplierProd.saveLink")}
            </button>
          </div>
        </div>
      )}

      {/* Empty state */}
      {linked.length === 0 && !showAdd && (
        <div className="text-center py-14 border-2 border-dashed border-gray-200 rounded-xl">
          <Users size={32} className="text-gray-300 mx-auto mb-2" />
          <p className="text-gray-400 text-sm">{t("supplierProd.noSuppliers")}</p>
        </div>
      )}

      {/* Supplier cards */}
      <div className="space-y-3">
        {linked.map(sp => (
          <SupplierCard
            key={sp.id} sp={sp}
            isEditing={editingId === sp.id}
            editForm={editFields[sp.id] ?? {}}
            onEdit={() => startEdit(sp)}
            onCancelEdit={() => setEditingId(null)}
            onSave={() => updateMut.mutate({ spId: sp.id, payload: editFields[sp.id] ?? {} })}
            isUnlinkConfirm={unlinkId === sp.id}
            onUnlink={() => setUnlinkId(sp.id)}
            onConfirmUnlink={() => unlinkMut.mutate(sp.id)}
            onCancelUnlink={() => setUnlinkId(null)}
            onFormChange={(p: FieldPatch) => setEditFields(prev => ({ ...prev, [sp.id]: { ...prev[sp.id], ...p } }))}
            isSaving={updateMut.isPending}
            isUnlinking={unlinkMut.isPending}
            t={t}
          />
        ))}
      </div>
    </div>
  );
}

// ── SupplierCard ─────────────────────────────────────────────────────────────
function SupplierCard({ sp, isEditing, editForm, onEdit, onCancelEdit, onSave,
  isUnlinkConfirm, onUnlink, onConfirmUnlink, onCancelUnlink,
  onFormChange, isSaving, isUnlinking, t }: any) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className={cn("border rounded-xl overflow-hidden transition-all",
      isEditing ? "border-indigo-300 shadow-md" : "border-gray-200 hover:border-gray-300")}>

      {/* Header row */}
      <div className="flex items-center gap-3 px-4 py-3 bg-white">
        {/* Avatar */}
        <div className="w-9 h-9 rounded-full bg-indigo-100 flex items-center justify-center shrink-0">
          <span className="text-xs font-bold text-indigo-700">
            {sp.supplier?.user?.full_name?.charAt(0)?.toUpperCase() ?? "S"}
          </span>
        </div>

        {/* Name + phone */}
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-gray-900 truncate">
            {sp.supplier?.user?.full_name ?? `Supplier #${sp.supplier_id}`}
          </p>
          <p className="text-xs text-gray-400">{sp.supplier?.user?.phone}</p>
        </div>

        {/* Quick stats */}
        <div className="hidden md:flex items-center gap-3 text-xs">
          {sp.price != null && (
            <span className="flex items-center gap-1 text-green-600 font-medium">
              <DollarSign size={11} /> {sp.price}
            </span>
          )}
          <span className="flex items-center gap-1 text-blue-600 font-medium">
            <Package size={11} /> {sp.stock}
          </span>
          <span className={cn("px-2 py-0.5 rounded-full font-medium",
            sp.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700")}>
            {sp.is_active ? t("common.active") : t("common.inactive")}
          </span>
          {sp.is_featured && (
            <span className="flex items-center gap-1 px-2 py-0.5 bg-yellow-100 text-yellow-700 rounded-full font-medium">
              <Star size={10} /> {t("supplierProd.isFeatured")}
            </span>
          )}
          {sp.is_best_seller && (
            <span className="flex items-center gap-1 px-2 py-0.5 bg-orange-100 text-orange-700 rounded-full font-medium">
              <TrendingUp size={10} /> {t("supplierProd.isBestSeller")}
            </span>
          )}
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-1 shrink-0">
          {isUnlinkConfirm ? (
            <>
              <button onClick={onConfirmUnlink} disabled={isUnlinking}
                className="px-2 py-1 bg-red-600 text-white text-xs rounded-lg disabled:opacity-60 transition">
                {t("common.yes")}
              </button>
              <button onClick={onCancelUnlink}
                className="px-2 py-1 border border-gray-300 text-xs rounded-lg hover:bg-gray-50 transition">
                {t("common.no")}
              </button>
            </>
          ) : (
            <>
              <button onClick={onEdit}
                className="p-1.5 hover:bg-indigo-50 text-indigo-600 rounded-lg transition" title={t("supplierProd.editLink")}>
                <Pencil size={14} />
              </button>
              <button onClick={onUnlink}
                className="p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition" title={t("supplierProd.unlink")}>
                <Trash2 size={14} />
              </button>
              <button onClick={() => setExpanded(e => !e)}
                className="p-1.5 hover:bg-gray-100 text-gray-400 rounded-lg transition">
                {expanded || isEditing ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
              </button>
            </>
          )}
        </div>
      </div>

      {/* Expanded / Edit area */}
      {(expanded || isEditing) && (
        <div className="border-t border-gray-100 p-4 bg-gray-50/40">
          {isEditing ? (
            <>
              <SupplierFields form={editForm} onChange={onFormChange} t={t} />
              <div className="flex gap-2 mt-4">
                <button onClick={onCancelEdit}
                  className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">
                  {t("common.cancel")}
                </button>
                <button onClick={onSave} disabled={isSaving}
                  className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
                  {isSaving ? t("common.saving") : t("common.saveChanges")}
                </button>
              </div>
            </>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-xs">
              <Stat label={t("supplierProd.costPrice")}     value={sp.cost_price ?? "—"} />
              <Stat label={t("supplierProd.sellingPrice")}  value={sp.price ?? "—"} />
              <Stat label={t("supplierProd.stock")}         value={sp.stock} />
              <Stat label={t("supplierProd.minStock")}      value={sp.min_stock} />
              <Stat label="Est. Time From"
                value={sp.estimated_time_from != null ? `${sp.estimated_time_from} min` : "—"} />
              <Stat label="Est. Time To"
                value={sp.estimated_time_to != null ? `${sp.estimated_time_to} min` : "—"} />
              <Stat label={t("supplierProd.minPerOrder")}   value={sp.min_amount_for_one_order ?? "—"} />
              <Stat label={t("supplierProd.maxPerOrder")}   value={sp.max_amount_for_one_order ?? "—"} />
              <Stat label={t("supplierProd.minPerUser")}    value={sp.min_amount_for_one_user ?? "—"} />
              <Stat label={t("supplierProd.maxPerUser")}    value={sp.max_amount_for_one_user ?? "—"} />
              <Stat label="Rating" value={sp.rating != null ? `⭐ ${sp.rating}` : "—"} />
              <Stat label="Reviews" value={sp.total_reviews ?? 0} />
              <Stat label="Reserved in Carts" value={sp.reserved_in_carts_amount ?? 0} />
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Shared field group ────────────────────────────────────────────────────────
function SupplierFields({ form, onChange, t }: { form: FieldPatch; onChange: (p: FieldPatch) => void; t: (k: string) => string }) {
  const inp = "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white";
  const lbl = "block text-xs font-medium text-gray-600 mb-1";
  const num = (key: keyof FieldPatch, val: string) =>
    onChange({ [key]: val === "" ? undefined : Number(val) } as any);

  return (
    <div className="space-y-4">
      {/* Prices */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>{t("supplierProd.costPrice")}</label>
          <input type="number" step="0.01" min="0" className={inp} placeholder="0.00"
            value={form.cost_price ?? ""} onChange={e => num("cost_price", e.target.value)} />
        </div>
        <div>
          <label className={lbl}>{t("supplierProd.sellingPrice")}</label>
          <input type="number" step="0.01" min="0" className={inp} placeholder="0.00"
            value={form.price ?? ""} onChange={e => num("price", e.target.value)} />
        </div>
      </div>

      {/* Stock */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>{t("supplierProd.stock")}</label>
          <input type="number" min="0" className={inp} placeholder="0"
            value={form.stock ?? ""} onChange={e => onChange({ stock: Number(e.target.value) })} />
        </div>
        <div>
          <label className={lbl}>{t("supplierProd.minStock")}</label>
          <input type="number" min="0" className={inp} placeholder="0"
            value={form.min_stock ?? ""} onChange={e => onChange({ min_stock: Number(e.target.value) })} />
        </div>
      </div>

      {/* Durations */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}><Timer size={11} className="inline mr-1" />Est. Time From (min)</label>
          <input type="number" min="0" className={inp} placeholder="15"
            value={form.estimated_time_from ?? ""} onChange={e => num("estimated_time_from", e.target.value)} />
        </div>
        <div>
          <label className={lbl}><Timer size={11} className="inline mr-1" />Est. Time To (min)</label>
          <input type="number" min="0" className={inp} placeholder="30"
            value={form.estimated_time_to ?? ""} onChange={e => num("estimated_time_to", e.target.value)} />
        </div>
      </div>

      {/* Order limits */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>{t("supplierProd.minPerOrder")}</label>
          <input type="number" min="1" className={inp} placeholder="1"
            value={form.min_amount_for_one_order ?? ""} onChange={e => num("min_amount_for_one_order", e.target.value)} />
        </div>
        <div>
          <label className={lbl}>{t("supplierProd.maxPerOrder")}</label>
          <input type="number" min="1" className={inp} placeholder="—"
            value={form.max_amount_for_one_order ?? ""} onChange={e => num("max_amount_for_one_order", e.target.value)} />
        </div>
      </div>

      {/* User limits */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>{t("supplierProd.minPerUser")}</label>
          <input type="number" min="1" className={inp} placeholder="1"
            value={form.min_amount_for_one_user ?? ""} onChange={e => num("min_amount_for_one_user", e.target.value)} />
        </div>
        <div>
          <label className={lbl}>{t("supplierProd.maxPerUser")}</label>
          <input type="number" min="1" className={inp} placeholder="—"
            value={form.max_amount_for_one_user ?? ""} onChange={e => num("max_amount_for_one_user", e.target.value)} />
        </div>
      </div>

      {/* Toggles */}
      <div className="flex flex-wrap gap-5 pt-1">
        {([
          ["is_active",      t("supplierProd.isActive"),     "indigo"],
          ["is_featured",    t("supplierProd.isFeatured"),   "yellow"],
          ["is_best_seller", t("supplierProd.isBestSeller"), "orange"],
        ] as [keyof FieldPatch, string, string][]).map(([key, label, _color]) => (
          <label key={key} className="flex items-center gap-2 cursor-pointer select-none">
            <input type="checkbox"
              checked={!!(form as any)[key]}
              onChange={e => onChange({ [key]: e.target.checked } as any)}
              className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
            <span className="text-sm text-gray-700">{label}</span>
          </label>
        ))}
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-white rounded-lg border border-gray-100 px-3 py-2">
      <p className="text-gray-400 text-xs mb-0.5">{label}</p>
      <p className="font-semibold text-gray-800">{value}</p>
    </div>
  );
}
