"use client";
import { useState, useRef, useMemo } from "react";
import { X, ImagePlus, Trash2, Package, Users, Percent } from "lucide-react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createProduct, updateProduct, fetchAllBrands, type Product } from "@/lib/products";
import { fetchCategories } from "@/lib/categories";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import { ALLOWED_IMAGE_ACCEPT, filterAllowedImageFiles } from "@/lib/file-upload";
import SupplierProductsTab from "./SupplierProductsTab";
import OffersTab from "./OffersTab";

type Tab = "general" | "suppliers" | "offers";

interface Props {
  product?: Product;
  onClose: () => void;
}

export default function ProductForm({ product, onClose }: Props) {
  const qc = useQueryClient();
  const { t } = useT();
  const isEdit = !!product;
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [activeTab, setActiveTab] = useState<Tab>("general");

  const [form, setForm] = useState({
    name: product?.name || "",
    name_ar: product?.name_ar || "",
    description: product?.description || "",
    description_ar: product?.description_ar || "",
    sku: product?.sku || "",
    barcode: product?.barcode || "",
    slug: product?.slug || "",
    synonyms: product?.synonyms || "",
    category_id: product?.category_id?.toString() || "",
    brand_id: product?.brand_id?.toString() || "",
    sort_id: product?.sort_id?.toString() || "0",
    weight: product?.weight?.toString() || "",
    dimensions: product?.dimensions || "",
    color: product?.color || "",
    refundable: product?.refundable ?? false,
    refundable_period: product?.refundable_period?.toString() || "24",
    refund_policy: product?.refund_policy || "",
  });

  const [existingImages, setExistingImages] = useState<string[]>(product?.images ?? []);
  const [imagesToDelete, setImagesToDelete] = useState<string[]>([]);
  const [newFiles, setNewFiles] = useState<File[]>([]);
  const [newPreviews, setNewPreviews] = useState<string[]>([]);
  const totalImages = existingImages.length + newFiles.length;

  const { data: categoriesData } = useQuery({
    queryKey: ["categories", "all"],
    queryFn: () => fetchCategories({ limit: 9999 }),
  });
  const categories = categoriesData?.categories ?? [];

  const { data: brands = [] } = useQuery({
    queryKey: ["brands", "all"],
    queryFn: fetchAllBrands,
  });

  // ── Sorted category options (parent sort_id → children sort_id) ──────────
  const sortedCategories = useMemo(() => {
    const parentNameMap: Record<number, string> = {};
    categories.forEach(c => { if (!c.parent_id) parentNameMap[c.id] = c.name; });
    const parents = categories.filter(c => !c.parent_id).sort((a, b) => a.sort_id - b.sort_id);
    return parents.flatMap(p => [
      { ...p, _label: p.name },
      ...categories
        .filter(c => c.parent_id === p.id)
        .sort((a, b) => a.sort_id - b.sort_id)
        .map(c => ({ ...c, _label: `${p.name} › ${c.name}` })),
    ]);
  }, [categories]);

  const mutation = useMutation({
    mutationFn: (fd: FormData) =>
      isEdit ? updateProduct(product!.id, fd) : createProduct(fd),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["products"] });
      toast.success(isEdit ? t("prodForm.updated") : t("prodForm.created"));
      if (!isEdit) onClose();
    },
    onError: (err: any) => toast.error(err.response?.data?.message || "Error"),
  });

  function handleAddImages(e: React.ChangeEvent<HTMLInputElement>) {
    const files = filterAllowedImageFiles(Array.from(e.target.files ?? []));
    const slots = 5 - totalImages;
    const toAdd = files.slice(0, slots);
    if (files.length > slots)
      toast.error(`${t("prodForm.maxImages")} ${slots} ${t("prodForm.slotsRemaining")}`);
    setNewFiles(prev => [...prev, ...toAdd]);
    setNewPreviews(prev => [...prev, ...toAdd.map(f => URL.createObjectURL(f))]);
    e.target.value = "";
  }

  function removeExisting(url: string) {
    setExistingImages(prev => prev.filter(u => u !== url));
    setImagesToDelete(prev => [...prev, url]);
  }

  function removeNew(index: number) {
    URL.revokeObjectURL(newPreviews[index]);
    setNewFiles(prev => prev.filter((_, i) => i !== index));
    setNewPreviews(prev => prev.filter((_, i) => i !== index));
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.category_id) { toast.error(t("prodForm.selectCategoryRequired")); return; }
    if (!isEdit && totalImages === 0) { toast.error(t("prodForm.imageRequired")); return; }

    const fd = new FormData();
    fd.append("name", form.name);
    if (form.name_ar) fd.append("name_ar", form.name_ar);
    if (form.description) fd.append("description", form.description);
    if (form.description_ar) fd.append("description_ar", form.description_ar);
    if (form.sku) fd.append("sku", form.sku);
    if (form.barcode) fd.append("barcode", form.barcode);
    if (form.slug) fd.append("slug", form.slug);
    if (form.synonyms) fd.append("synonyms", form.synonyms);
    fd.append("category_id", form.category_id);
    if (form.brand_id) fd.append("brand_id", form.brand_id);
    fd.append("sort_id", form.sort_id || "0");
    if (form.weight) fd.append("weight", form.weight);
    if (form.dimensions) fd.append("dimensions", form.dimensions);
    if (form.color) fd.append("color", form.color);
    fd.append("refundable", String(form.refundable));
    if (form.refundable && form.refundable_period) fd.append("refundable_period", form.refundable_period);
    if (form.refundable && form.refund_policy) fd.append("refund_policy", form.refund_policy);
    if (imagesToDelete.length > 0) fd.append("deleteSpecificImages", JSON.stringify(imagesToDelete));
    newFiles.forEach(f => fd.append("images", f));
    mutation.mutate(fd);
  }

  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setForm(f => ({ ...f, [k]: e.target.value }));

  const inputCls = "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none";
  const labelCls = "block text-sm font-medium text-gray-700 mb-1";

  const TABS: { id: Tab; label: string; icon: React.ElementType }[] = [
    { id: "general",   label: t("prodForm.tabGeneral"),   icon: Package },
    ...(isEdit ? [
      { id: "suppliers" as Tab, label: t("prodForm.tabSuppliers"), icon: Users   },
      { id: "offers"    as Tab, label: t("prodForm.tabOffers"),    icon: Percent },
    ] : []),
  ];

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[92vh] flex flex-col">

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b shrink-0">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              {isEdit ? t("products.edit") : t("products.new")}
            </h2>
            {isEdit && product.name && (
              <p className="text-xs text-gray-400 mt-0.5 truncate max-w-sm">{product.name}</p>
            )}
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-lg">
            <X size={18} />
          </button>
        </div>

        {/* Tab bar — only shown when editing */}
        {isEdit && (
          <div className="flex border-b bg-gray-50 shrink-0">
            {TABS.map(({ id, label, icon: Icon }) => (
              <button key={id} onClick={() => setActiveTab(id)}
                className={cn(
                  "flex items-center gap-2 px-5 py-3 text-sm font-medium transition-all border-b-2",
                  activeTab === id
                    ? "border-indigo-600 text-indigo-700 bg-white"
                    : "border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-100"
                )}>
                <Icon size={15} />
                {label}
              </button>
            ))}
          </div>
        )}

        {/* Scrollable content area */}
        <div className="flex-1 overflow-y-auto">

          {/* ── General Info ── */}
          {activeTab === "general" && (
            <form onSubmit={handleSubmit} className="p-6 space-y-6">

              {/* Images */}
              <div>
                <label className={labelCls}>
                  {t("prodForm.images")} {!isEdit && "*"}
                  <span className="ml-1 font-normal text-gray-400">({totalImages}/5)</span>
                </label>
                <div className="flex flex-wrap gap-3 mt-2">
                  {existingImages.map(url => (
                    <div key={url} className="relative w-20 h-20 rounded-xl overflow-hidden border border-gray-200 group">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={url} alt="product" className="w-full h-full object-cover" />
                      <button type="button" onClick={() => removeExisting(url)}
                        className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex items-center justify-center transition">
                        <Trash2 size={16} className="text-white" />
                      </button>
                    </div>
                  ))}
                  {newPreviews.map((src, i) => (
                    <div key={i} className="relative w-20 h-20 rounded-xl overflow-hidden border-2 border-indigo-300 group">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={src} alt="new" className="w-full h-full object-cover" />
                      <button type="button" onClick={() => removeNew(i)}
                        className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex items-center justify-center transition">
                        <Trash2 size={16} className="text-white" />
                      </button>
                    </div>
                  ))}
                  {totalImages < 5 && (
                    <button type="button" onClick={() => fileInputRef.current?.click()}
                      className="w-20 h-20 rounded-xl border-2 border-dashed border-gray-300 flex flex-col items-center justify-center gap-1 hover:border-indigo-400 hover:bg-indigo-50 transition text-gray-400 hover:text-indigo-500">
                      <ImagePlus size={20} />
                      <span className="text-xs">{t("common.add")}</span>
                    </button>
                  )}
                  <input ref={fileInputRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} multiple className="hidden" onChange={handleAddImages} />
                </div>
              </div>

              {/* Names */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className={labelCls}>{t("prodForm.nameEn")} *</label>
                  <input required value={form.name} onChange={set("name")} className={inputCls} />
                </div>
                <div>
                  <label className={labelCls}>{t("prodForm.nameAr")}</label>
                  <input value={form.name_ar} onChange={set("name_ar")} className={cn(inputCls, "text-right")} dir="rtl" />
                </div>
              </div>

              {/* Descriptions */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className={labelCls}>{t("prodForm.descEn")}</label>
                  <textarea value={form.description} onChange={set("description")}
                    className={cn(inputCls, "resize-none")} rows={3} />
                </div>
                <div>
                  <label className={labelCls}>{t("prodForm.descAr")}</label>
                  <textarea value={form.description_ar} onChange={set("description_ar")}
                    className={cn(inputCls, "resize-none text-right")} dir="rtl" rows={3} />
                </div>
              </div>

              {/* Category & Brand */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className={labelCls}>{t("prodForm.category")} *</label>
                  <select required value={form.category_id} onChange={set("category_id")} className={inputCls}>
                    <option value="">{t("prodForm.selectCategory")}</option>
                    {sortedCategories.map(c => (
                      <option key={c.id} value={c.id}>
                        {c._label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className={labelCls}>{t("prodForm.brand")}</label>
                  <select value={form.brand_id} onChange={set("brand_id")} className={inputCls}>
                    <option value="">{t("prodForm.noBrand")}</option>
                    {brands.map(b => (
                      <option key={b.id} value={b.id}>{b.name}</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* SKU & Barcode */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className={labelCls}>
                    {t("prodForm.sku")} <span className="font-normal text-gray-400">{t("prodForm.skuHint")}</span>
                  </label>
                  <input value={form.sku} onChange={set("sku")} className={inputCls} placeholder="PROD-001" />
                </div>
                <div>
                  <label className={labelCls}>
                    {t("prodForm.barcode")} <span className="font-normal text-gray-400">{t("prodForm.barcodeHint")}</span>
                  </label>
                  <input value={form.barcode} onChange={set("barcode")} className={inputCls} placeholder="6001234567890" />
                </div>
              </div>

              {/* Slug & Sort Order */}
              <div className="grid grid-cols-3 gap-4">
                <div className="col-span-2">
                  <label className={labelCls}>
                    Slug <span className="font-normal text-gray-400">(unique URL key)</span>
                  </label>
                  <input value={form.slug} onChange={set("slug")} className={inputCls} placeholder="fresh-milk-1l" />
                </div>
                <div>
                  <label className={labelCls}>Sort Order</label>
                  <input type="number" min="0" value={form.sort_id} onChange={set("sort_id")} className={inputCls} placeholder="0" />
                </div>
              </div>

              {/* Synonyms */}
              <div>
                <label className={labelCls}>
                  Synonyms <span className="font-normal text-gray-400">(search aliases, comma-separated)</span>
                </label>
                <input value={form.synonyms} onChange={set("synonyms")} className={inputCls} placeholder="milk, laban, full cream milk" />
              </div>

              {/* Weight / Dimensions / Color */}
              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className={labelCls}>{t("prodForm.weight")}</label>
                  <input type="number" step="0.01" min="0" value={form.weight} onChange={set("weight")} className={inputCls} placeholder="0.5" />
                </div>
                <div>
                  <label className={labelCls}>{t("prodForm.dimensions")}</label>
                  <input value={form.dimensions} onChange={set("dimensions")} className={inputCls} placeholder="30×20×10 cm" />
                </div>
                <div>
                  <label className={labelCls}>{t("prodForm.color")}</label>
                  <input value={form.color} onChange={set("color")} className={inputCls} />
                </div>
              </div>

              {/* Refund policy */}
              <div className="border border-gray-200 rounded-xl p-4 space-y-4">
                <div className="flex items-center gap-3">
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox" checked={form.refundable}
                      onChange={e => setForm(f => ({ ...f, refundable: e.target.checked }))}
                      className="sr-only peer" />
                    <div className="w-10 h-5 bg-gray-200 peer-checked:bg-indigo-600 rounded-full transition peer-focus:ring-2 peer-focus:ring-indigo-400 after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5" />
                  </label>
                  <span className="text-sm font-medium text-gray-700">{t("prodForm.refundable")}</span>
                </div>
                {form.refundable && (
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className={labelCls}>{t("prodForm.refundPeriod")} <span className="font-normal text-gray-400">(hours)</span></label>
                      <input type="number" min="1" value={form.refundable_period} onChange={set("refundable_period")} className={inputCls} placeholder="24" />
                    </div>
                    <div>
                      <label className={labelCls}>{t("prodForm.refundPolicy")}</label>
                      <input value={form.refund_policy} onChange={set("refund_policy")} className={inputCls} />
                    </div>
                  </div>
                )}
              </div>

              {/* Hint for new products */}
              {!isEdit && (
                <div className="flex items-center gap-2 text-xs text-indigo-600 bg-indigo-50 border border-indigo-100 rounded-lg px-3 py-2.5">
                  <Users size={13} className="shrink-0" />
                  {t("prodForm.suppliersHint")}
                </div>
              )}

              {/* Actions */}
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={onClose}
                  className="flex-1 border border-gray-300 rounded-lg py-2.5 text-sm font-medium hover:bg-gray-50 transition">
                  {t("common.cancel")}
                </button>
                <button type="submit" disabled={mutation.isPending}
                  className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-60 transition">
                  {mutation.isPending ? t("common.saving") : isEdit ? t("common.saveChanges") : t("products.new")}
                </button>
              </div>
            </form>
          )}

          {/* ── Suppliers tab ── */}
          {activeTab === "suppliers" && isEdit && (
            <SupplierProductsTab productId={product!.id} />
          )}

          {/* ── Offers tab ── */}
          {activeTab === "offers" && isEdit && (
            <OffersTab productId={product!.id} />
          )}

        </div>
      </div>
    </div>
  );
}
