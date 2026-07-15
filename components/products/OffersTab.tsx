"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient, useQueries } from "@tanstack/react-query";
import {
  fetchOffersBySpId, createOffer, updateOffer, deleteOffer,
  type Offer, type OfferPayload, type OfferType,
} from "@/lib/offers";
import { fetchProductSuppliers } from "@/lib/supplier-products";
import { Plus, Trash2, Pencil, X, Percent, ChevronDown, ChevronUp } from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";

interface Props { productId: number }

const today = () => new Date().toISOString().slice(0, 10);
const nextMonth = () => {
  const d = new Date(); d.setMonth(d.getMonth() + 1);
  return d.toISOString().slice(0, 10);
};

const emptyOffer = (spId: number): OfferPayload => ({
  supplier_product_id: spId,
  offer_type: "PERCENT",
  offer_value: 0,
  start_date: today(),
  end_date: nextMonth(),
  is_active: true,
});

export default function OffersTab({ productId }: Props) {
  const qc = useQueryClient();
  const { t } = useT();

  // ── Linked supplier-products ──────────────────────────────────────────────
  const { data: linked = [] } = useQuery({
    queryKey: ["product-suppliers", productId],
    queryFn: () => fetchProductSuppliers(productId),
  });

  // ── Fetch offers for each supplier_product in parallel ───────────────────
  const offersQueries = useQueries({
    queries: linked.map(sp => ({
      queryKey: ["offers-sp", sp.id],
      queryFn: () => fetchOffersBySpId(sp.id),
      enabled: linked.length > 0,
    })),
  });

  // ── UI state ──────────────────────────────────────────────────────────────
  // addingSpId = which supplier_product we're adding an offer to
  const [addingSpId, setAddingSpId] = useState<number | null>(null);
  const [addForm, setAddForm] = useState<OfferPayload | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState<Partial<OfferPayload>>({});
  const [deleteId, setDeleteId] = useState<number | null>(null);
  const [expandedSp, setExpandedSp] = useState<Set<number>>(new Set(linked.map(s => s.id)));

  function openAdd(spId: number) {
    setAddingSpId(spId);
    setAddForm(emptyOffer(spId));
  }
  function closeAdd() { setAddingSpId(null); setAddForm(null); }

  function startEdit(offer: Offer) {
    setEditingId(offer.id);
    setEditForm({
      offer_type: offer.offer_type ?? "PERCENT",
      offer_value: offer.offer_value ?? 0,
      start_date: offer.start_date?.slice(0, 10) ?? today(),
      end_date: offer.end_date?.slice(0, 10) ?? nextMonth(),
      is_active: offer.is_active ?? true,
    });
  }

  // ── Mutations ─────────────────────────────────────────────────────────────
  const createMut = useMutation({
    mutationFn: (p: OfferPayload) => createOffer(p),
    onSuccess: (_, vars) => {
      qc.invalidateQueries({ queryKey: ["offers-sp", vars.supplier_product_id] });
      toast.success(t("offers.created"));
      closeAdd();
    },
    onError: (e: any) => toast.error(e.response?.data?.message || e.response?.data?.errors?.[0]?.message || "Error"),
  });

  const updateMut = useMutation({
    mutationFn: ({ id, payload }: { id: number; payload: Partial<OfferPayload> }) =>
      updateOffer(id, payload),
    onSuccess: () => {
      // invalidate all offer queries for this product
      linked.forEach(sp => qc.invalidateQueries({ queryKey: ["offers-sp", sp.id] }));
      toast.success(t("offers.updated"));
      setEditingId(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || e.response?.data?.errors?.[0]?.message || "Error"),
  });

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteOffer(id),
    onSuccess: () => {
      linked.forEach(sp => qc.invalidateQueries({ queryKey: ["offers-sp", sp.id] }));
      toast.success(t("offers.deleted"));
      setDeleteId(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  if (linked.length === 0) {
    return (
      <div className="p-6 text-center py-16 border-2 border-dashed border-gray-200 rounded-xl">
        <Percent size={32} className="text-gray-300 mx-auto mb-2" />
        <p className="text-gray-400 text-sm">{t("offers.noOffers")}</p>
        <p className="text-xs text-gray-400 mt-1">Link a supplier first to add offers</p>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-4">
      {linked.map((sp, idx) => {
        const offers: Offer[] = offersQueries[idx]?.data ?? [];
        const isLoading = offersQueries[idx]?.isLoading ?? false;
        const isExpanded = expandedSp.has(sp.id);
        const supplierName = sp.supplier?.user?.full_name ?? `Supplier #${sp.supplier_id}`;
        const isAddingHere = addingSpId === sp.id;

        return (
          <div key={sp.id} className="border border-gray-200 rounded-xl overflow-hidden">
            {/* Supplier header */}
            <div className="flex items-center justify-between px-4 py-3 bg-gray-50 border-b border-gray-100">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-full bg-indigo-100 flex items-center justify-center text-xs font-bold text-indigo-700 shrink-0">
                  {supplierName.charAt(0).toUpperCase()}
                </div>
                <span className="text-sm font-semibold text-gray-800">{supplierName}</span>
                <span className="text-xs bg-white border border-gray-200 text-gray-500 px-2 py-0.5 rounded-full">
                  {offers.length} {t("offers.title")}
                </span>
              </div>
              <div className="flex items-center gap-1">
                {!isAddingHere && (
                  <button onClick={() => openAdd(sp.id)}
                    className="flex items-center gap-1.5 text-xs bg-green-600 hover:bg-green-700 text-white px-2.5 py-1.5 rounded-lg transition">
                    <Plus size={12} /> {t("offers.new")}
                  </button>
                )}
                <button onClick={() => setExpandedSp(prev => {
                  const next = new Set(prev);
                  if (next.has(sp.id)) next.delete(sp.id); else next.add(sp.id);
                  return next;
                })} className="p-1.5 hover:bg-gray-200 rounded-lg transition text-gray-400">
                  {isExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                </button>
              </div>
            </div>

            {isExpanded && (
              <div className="bg-white">
                {/* Add form */}
                {isAddingHere && addForm && (
                  <div className="border-b border-gray-100 p-4 bg-green-50/30">
                    <div className="flex items-center justify-between mb-3">
                      <h4 className="text-sm font-semibold text-green-700">{t("offers.new")}</h4>
                      <button onClick={closeAdd} className="p-1 hover:bg-green-100 rounded-lg">
                        <X size={15} />
                      </button>
                    </div>
                    <OfferFields form={addForm}
                      onChange={p => setAddForm(prev => prev ? { ...prev, ...p } : prev)}
                      t={t} />
                    <div className="flex gap-2 mt-3">
                      <button onClick={closeAdd}
                        className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">
                        {t("common.cancel")}
                      </button>
                      <button onClick={() => createMut.mutate(addForm!)}
                        disabled={createMut.isPending}
                        className="flex-1 bg-green-600 hover:bg-green-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
                        {createMut.isPending ? t("common.saving") : t("offers.new")}
                      </button>
                    </div>
                  </div>
                )}

                {/* Loading */}
                {isLoading && (
                  <div className="p-4 space-y-2">
                    {[0, 1].map(i => <div key={i} className="h-12 bg-gray-100 rounded-lg animate-pulse" />)}
                  </div>
                )}

                {/* Empty */}
                {!isLoading && offers.length === 0 && !isAddingHere && (
                  <div className="py-8 text-center text-gray-400 text-sm">
                    <Percent size={24} className="mx-auto mb-2 text-gray-300" />
                    {t("offers.noOffers")}
                  </div>
                )}

                {/* Offer rows */}
                {offers.map(offer => (
                  <div key={offer.id} className="border-b border-gray-50 last:border-0">
                    {editingId === offer.id ? (
                      <div className="p-4 bg-indigo-50/30">
                        <OfferFields form={editForm as OfferPayload}
                          onChange={p => setEditForm(prev => ({ ...prev, ...p }))}
                          t={t} />
                        <div className="flex gap-2 mt-3">
                          <button onClick={() => setEditingId(null)}
                            className="flex-1 border border-gray-300 rounded-lg py-2 text-sm hover:bg-gray-50 transition">
                            {t("common.cancel")}
                          </button>
                          <button onClick={() => updateMut.mutate({ id: offer.id, payload: editForm })}
                            disabled={updateMut.isPending}
                            className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-60 transition">
                            {updateMut.isPending ? t("common.saving") : t("common.saveChanges")}
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex items-center gap-3 px-4 py-3 hover:bg-gray-50 transition">
                        {/* Discount badge */}
                        <div className={cn(
                          "w-11 h-11 rounded-xl flex items-center justify-center shrink-0 text-xs font-bold",
                          offer.offer_type === "PERCENT"
                            ? "bg-green-100 text-green-700"
                            : "bg-blue-100 text-blue-700"
                        )}>
                          {offer.offer_type === "PERCENT"
                            ? `${offer.offer_value}%`
                            : `-${offer.offer_value}`}
                        </div>

                        {/* Info */}
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium",
                              offer.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700")}>
                              {offer.is_active ? t("common.active") : t("common.inactive")}
                            </span>
                            <span className="text-xs text-gray-400">
                              {offer.offer_type === "PERCENT" ? t("offers.percentage") : t("offers.fixed")}
                            </span>
                          </div>
                          {offer.start_date && (
                            <p className="text-xs text-gray-400 mt-0.5">
                              {new Date(offer.start_date).toLocaleDateString()}
                              {offer.end_date && ` → ${new Date(offer.end_date).toLocaleDateString()}`}
                            </p>
                          )}
                        </div>

                        {/* Actions */}
                        <div className="flex items-center gap-1 shrink-0">
                          {deleteId === offer.id ? (
                            <>
                              <button onClick={() => deleteMut.mutate(offer.id)} disabled={deleteMut.isPending}
                                className="px-2 py-1 bg-red-600 text-white text-xs rounded-lg disabled:opacity-60">
                                {t("common.yes")}
                              </button>
                              <button onClick={() => setDeleteId(null)}
                                className="px-2 py-1 border text-xs rounded-lg hover:bg-gray-50">
                                {t("common.no")}
                              </button>
                            </>
                          ) : (
                            <>
                              <button onClick={() => startEdit(offer)}
                                className="p-1.5 hover:bg-indigo-50 text-indigo-600 rounded-lg transition">
                                <Pencil size={13} />
                              </button>
                              <button onClick={() => setDeleteId(offer.id)}
                                className="p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition">
                                <Trash2 size={13} />
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── OfferFields ───────────────────────────────────────────────────────────────
function OfferFields({ form, onChange, t }: {
  form: Partial<OfferPayload>;
  onChange: (p: Partial<OfferPayload>) => void;
  t: (k: string) => string;
}) {
  const inp = "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white";
  const lbl = "block text-xs font-medium text-gray-600 mb-1";

  return (
    <div className="space-y-3">
      {/* Type + Value */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>{t("offers.discountType")}</label>
          <select value={form.offer_type ?? "PERCENT"}
            onChange={e => onChange({ offer_type: e.target.value as OfferType })}
            className={inp}>
            <option value="PERCENT">{t("offers.percentage")}</option>
            <option value="FIXED_CENTS">{t("offers.fixed")}</option>
          </select>
        </div>
        <div>
          <label className={lbl}>{t("offers.discountValue")}</label>
          <input type="number" step="0.01" min="0" placeholder="0"
            value={form.offer_value ?? ""}
            onChange={e => onChange({ offer_value: Number(e.target.value) })}
            className={inp} />
        </div>
      </div>

      {/* Dates — both required by API */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className={lbl}>{t("offers.startDate")} *</label>
          <input type="date" value={form.start_date ?? ""}
            onChange={e => onChange({ start_date: e.target.value })}
            className={inp} />
        </div>
        <div>
          <label className={lbl}>{t("offers.endDate")} *</label>
          <input type="date" value={form.end_date ?? ""}
            onChange={e => onChange({ end_date: e.target.value })}
            className={inp} />
        </div>
      </div>

      {/* Active */}
      <label className="flex items-center gap-2 cursor-pointer select-none">
        <input type="checkbox" checked={!!form.is_active}
          onChange={e => onChange({ is_active: e.target.checked })}
          className="rounded border-gray-300 text-green-600 focus:ring-green-500" />
        <span className="text-sm text-gray-700">{t("offers.isActive")}</span>
      </label>
    </div>
  );
}
