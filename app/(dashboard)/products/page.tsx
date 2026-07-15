"use client";
import { useState, useMemo, Fragment } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchProducts, deleteProduct, bulkDeleteProducts, fetchAllBrands,
  type Product,
} from "@/lib/products";
import { fetchCategories } from "@/lib/categories";
import ProductForm from "@/components/products/ProductForm";
import {
  Plus, Pencil, Trash2, Package, PackageX,
  ChevronUp, ChevronDown, ChevronsUpDown, RefreshCw,
  Tag, Layers,
} from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

type SortField = "name" | "sku" | "category" | "brand" | "created_at";
type SortDir = "asc" | "desc";

const ALL_COLUMN_KEYS = ["thumb", "name", "sku", "category", "brand", "created_at", "actions"] as const;

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc"
    ? <ChevronUp size={13} className="text-indigo-600" />
    : <ChevronDown size={13} className="text-indigo-600" />;
}

function ProductThumb({ images, name }: { images: string[]; name: string }) {
  const src = images?.[0];
  if (src) {
    return (
      <div className="w-10 h-10 rounded-lg overflow-hidden border border-gray-200 shrink-0">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={src} alt={name} className="w-full h-full object-cover" />
      </div>
    );
  }
  return (
    <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
      <Package size={18} className="text-gray-400" />
    </div>
  );
}

export default function ProductsPage() {
  const qc = useQueryClient();
  const { t } = useT();

  // ── Filters ───────────────────────────────────────────────────────────────
  const [search, setSearch] = useState("");
  const [filterCategory, setFilterCategory] = useState("");
  const [filterBrand, setFilterBrand] = useState("");
  const [showArchived, setShowArchived] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // ── Date filters ──────────────────────────────────────────────────────────
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");

  // ── Sort ──────────────────────────────────────────────────────────────────
  const [sortField, setSortField] = useState<SortField>("created_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");

  // ── UI state ──────────────────────────────────────────────────────────────
  const [showForm, setShowForm] = useState(false);
  const [editProduct, setEditProduct] = useState<Product | undefined>();
  const [deleteConfirm, setDeleteConfirm] = useState<number | null>(null);
  const [selected, setSelected] = useState<Set<number>>(new Set());

  // ── Column visibility ─────────────────────────────────────────────────────
  const { visible, setVisible } = useColumnVisibility("cols:products", [...ALL_COLUMN_KEYS]);

  // ── Server params ─────────────────────────────────────────────────────────
  const serverParams = useMemo(() => {
    const p: Record<string, string | number> = {
      page,
      limit: pageSize === 0 ? 9999 : pageSize,
    };
    if (search) p.keyword = search;
    if (filterCategory) p.category_id = filterCategory;
    if (filterBrand) p.brand_id = filterBrand;
    if (showArchived) p.deleted_at = "not_null";
    return p;
  }, [page, pageSize, search, filterCategory, filterBrand, showArchived]);

  // ── Queries ───────────────────────────────────────────────────────────────
  const { data, isLoading, refetch } = useQuery({
    queryKey: ["products", serverParams],
    queryFn: () => fetchProducts(serverParams),
  });

  const { data: categoriesData } = useQuery({
    queryKey: ["categories", "all"],
    queryFn: () => fetchCategories({ limit: 9999 }),
  });
  const categories = categoriesData?.categories ?? [];

  const { data: brands = [] } = useQuery({
    queryKey: ["brands", "all"],
    queryFn: fetchAllBrands,
  });

  // ── Category / Brand maps ─────────────────────────────────────────────────
  const categoryMap = useMemo(() => {
    const m: Record<number, string> = {};
    categories.forEach(c => { m[c.id] = c.name; });
    return m;
  }, [categories]);

  const brandMap = useMemo(() => {
    const m: Record<number, string> = {};
    brands.forEach(b => { m[b.id] = b.name; });
    return m;
  }, [brands]);

  // ── Client-side sort ──────────────────────────────────────────────────────
  const sortedProducts = useMemo(() => {
    const list = [...(data?.products ?? [])];
    return list.sort((a, b) => {
      let av: string | number, bv: string | number;
      switch (sortField) {
        case "name": av = a.name.toLowerCase(); bv = b.name.toLowerCase(); break;
        case "sku": av = a.sku.toLowerCase(); bv = b.sku.toLowerCase(); break;
        case "category": av = (categoryMap[a.category_id] || "").toLowerCase(); bv = (categoryMap[b.category_id] || "").toLowerCase(); break;
        case "brand": av = (brandMap[a.brand_id ?? 0] || "").toLowerCase(); bv = (brandMap[b.brand_id ?? 0] || "").toLowerCase(); break;
        default: av = new Date(a.created_at).getTime(); bv = new Date(b.created_at).getTime(); break;
      }
      if (av < bv) return sortDir === "asc" ? -1 : 1;
      if (av > bv) return sortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [data, sortField, sortDir, categoryMap, brandMap]);

  // ── Client-side date filtering ────────────────────────────────────────────
  const products = sortedProducts.filter(r => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && r.updated_at && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && r.updated_at && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const totalProducts = data?.totalProducts ?? 0;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? products.length : totalProducts;
  const archivedCount = products.filter(p => p.deleted_at).length;

  // ── Sorted category options (parent sort_id → children sort_id) ──────────
  const sortedCategoryOptions = useMemo(() => {
    const parentNameMap: Record<number, string> = {};
    categories.forEach(c => { if (!c.parent_id) parentNameMap[c.id] = c.name; });
    const parents = categories.filter(c => !c.parent_id).sort((a, b) => a.sort_id - b.sort_id);
    return parents.flatMap(p => [
      { id: p.id, label: p.name },
      ...categories
        .filter(c => c.parent_id === p.id)
        .sort((a, b) => a.sort_id - b.sort_id)
        .map(c => ({ id: c.id, label: `${p.name} › ${c.name}` })),
    ]);
  }, [categories]);

  // ── Mutations ─────────────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: (id: number) => deleteProduct(id, true),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["products"] });
      toast.success(t("products.archived"));
      setDeleteConfirm(null);
    },
    onError: (err: any) => toast.error(err.response?.data?.message || t("products.deleteError")),
  });

  const hardDeleteMutation = useMutation({
    mutationFn: (id: number) => deleteProduct(id, false),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["products"] });
      toast.success(t("common.deleteForever") + " ✓");
      setDeleteConfirm(null);
    },
    onError: (err: any) => toast.error(err.response?.data?.message || t("products.deleteError")),
  });

  const bulkDeleteMutation = useMutation({
    mutationFn: (ids: number[]) => bulkDeleteProducts(ids, false),
    onSuccess: (_, ids) => {
      qc.invalidateQueries({ queryKey: ["products"] });
      toast.success(`${ids.length} ${t("products.bulkDeleted")}`);
      setSelected(new Set());
    },
    onError: (err: any) => toast.error(err.response?.data?.message || t("products.deleteError")),
  });

  // ── Helpers ───────────────────────────────────────────────────────────────
  function toggleSort(field: SortField) {
    if (sortField === field) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortField(field); setSortDir("asc"); }
  }

  function handleFilterChange<T>(setter: (v: T) => void, value: T) {
    setter(value); setPage(1);
  }

  function openEdit(p: Product) { setEditProduct(p); setShowForm(true); }
  function openNew() { setEditProduct(undefined); setShowForm(true); }
  function closeForm() { setShowForm(false); setEditProduct(undefined); }

  function toggleSelect(id: number) {
    setSelected(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }
  function toggleSelectAll() {
    if (selected.size === products.length) setSelected(new Set());
    else setSelected(new Set(products.map(p => p.id)));
  }

  const totalPages = pageSize === 0 ? 1 : (data?.totalPages ?? 1);

  // ── Column toggle options ─────────────────────────────────────────────────
  const columnOptions: ColumnOption[] = [
    { key: "thumb",      label: t("common.image") },
    { key: "name",       label: t("common.name") },
    { key: "sku",        label: t("products.sku") },
    { key: "category",   label: t("products.category") },
    { key: "brand",      label: t("products.brand") },
    { key: "created_at", label: t("products.added") },
    { key: "actions",    label: t("common.actions"), alwaysVisible: true },
  ];

  function Th({ field, label, className }: { field?: SortField; label: string; className?: string }) {
    return (
      <th className={cn("px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide", className)}>
        {field ? (
          <button onClick={() => toggleSort(field)} className="flex items-center gap-1 hover:text-gray-700">
            {label} <SortIcon active={sortField === field} dir={sortDir} />
          </button>
        ) : label}
      </th>
    );
  }

  return (
    <div className="p-6 space-y-6">
      {/* ── Header ── */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t("products.title")}</h1>
          <p className="text-sm text-gray-500 mt-0.5">{t("products.subtitle")}</p>
        </div>
        <button onClick={openNew}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition shadow-sm">
          <Plus size={16} /> {t("products.new")}
        </button>
      </div>

      {/* ── Stat cards ── */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-indigo-50 flex items-center justify-center">
            <Package size={22} className="text-indigo-500" />
          </div>
          <div>
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{t("products.total")}</p>
            <p className="text-2xl font-bold text-gray-900">{totalProducts}</p>
          </div>
        </div>
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-red-50 flex items-center justify-center">
            <PackageX size={22} className="text-red-400" />
          </div>
          <div>
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{t("common.archived")}</p>
            <p className="text-2xl font-bold text-gray-900">{archivedCount}</p>
          </div>
        </div>
      </div>

      {/* ── Filters ── */}
      <TableToolbar
        total={displayTotal}
        totalLabel={t("products.title").toLowerCase()}
        search={search}
        onSearch={(v) => handleFilterChange(setSearch, v)}
        searchPlaceholder={t("products.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => refetch()}
              className="p-2.5 border border-gray-300 rounded-xl hover:bg-gray-50 transition text-gray-500">
              <RefreshCw size={15} className={isLoading ? "animate-spin" : ""} />
            </button>
          </div>
        }
      >
        <select
          value={filterCategory}
          onChange={e => handleFilterChange(setFilterCategory, e.target.value)}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="">{t("products.allCategories")}</option>
          {sortedCategoryOptions.map(c => (
            <option key={c.id} value={c.id}>{c.label}</option>
          ))}
        </select>

        <select
          value={filterBrand}
          onChange={e => handleFilterChange(setFilterBrand, e.target.value)}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="">{t("products.allBrands")}</option>
          {brands.map(b => (
            <option key={b.id} value={b.id}>{b.name}</option>
          ))}
        </select>

        <button
          onClick={() => handleFilterChange(setShowArchived, !showArchived)}
          className={cn("flex items-center gap-1.5 px-3 py-2.5 rounded-xl text-sm border transition",
            showArchived ? "bg-red-50 border-red-200 text-red-600" : "border-gray-300 text-gray-600 hover:bg-gray-50")}>
          <PackageX size={14} /> {t("common.archived")}
        </button>

        <select
          value={pageSize}
          onChange={e => { setPageSize(Number(e.target.value)); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          {[10, 20, 50, 100].map(s => (
            <option key={s} value={s}>{s} / page</option>
          ))}
          <option value={0}>All</option>
        </select>

        <DateRangeFilter
          label={t("common.createdAt")}
          from={createdFrom} to={createdTo}
          onFromChange={v => { setCreatedFrom(v); setPage(1); }}
          onToChange={v => { setCreatedTo(v); setPage(1); }}
        />
        <DateRangeFilter
          label={t("common.updatedAt")}
          from={updatedFrom} to={updatedTo}
          onFromChange={v => { setUpdatedFrom(v); setPage(1); }}
          onToChange={v => { setUpdatedTo(v); setPage(1); }}
        />
      </TableToolbar>

      {/* ── Bulk delete banner ── */}
      {selected.size > 0 && (
        <div className="bg-indigo-50 border border-indigo-200 rounded-xl px-4 py-3 flex items-center justify-between">
          <span className="text-sm font-medium text-indigo-700">{selected.size} {t("common.selected")}</span>
          <div className="flex gap-2">
            <button onClick={() => setSelected(new Set())}
              className="text-sm text-indigo-600 hover:underline">{t("common.deselectAll")}</button>
            <button
              onClick={() => bulkDeleteMutation.mutate(Array.from(selected))}
              disabled={bulkDeleteMutation.isPending}
              className="flex items-center gap-1.5 text-sm bg-red-600 hover:bg-red-700 text-white px-3 py-1.5 rounded-lg transition disabled:opacity-60">
              <Trash2 size={13} /> {t("common.deleteSelected")}
            </button>
          </div>
        </div>
      )}

      {/* ── Table ── */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="px-4 py-3 w-10">
                  <input type="checkbox"
                    checked={products.length > 0 && selected.size === products.length}
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
                </th>
                {visible.includes("thumb") && <th className="px-4 py-3 w-14" />}
                {visible.includes("name") && <Th field="name" label={t("common.name")} />}
                {visible.includes("sku") && <Th field="sku" label={t("products.sku")} />}
                {visible.includes("category") && <Th field="category" label={t("products.category")} />}
                {visible.includes("brand") && <Th field="brand" label={t("products.brand")} />}
                {visible.includes("created_at") && <Th field="created_at" label={t("products.added")} />}
                {visible.includes("actions") && (
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">{t("common.actions")}</th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading
                ? Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i}>
                    {Array.from({ length: visible.length + 1 }).map((__, j) => (
                      <td key={j} className="px-4 py-3">
                        <div className="h-4 bg-gray-100 rounded animate-pulse" />
                      </td>
                    ))}
                  </tr>
                ))
                : products.length === 0
                  ? (
                    <tr>
                      <td colSpan={visible.length + 1} className="px-4 py-16 text-center">
                        <Package size={32} className="mx-auto text-gray-300 mb-3" />
                        <p className="text-gray-400 text-sm">{t("products.noResults")}</p>
                      </td>
                    </tr>
                  )
                  : products.map(p => (
                    <Fragment key={p.id}>
                      <tr className={cn(
                        "hover:bg-gray-50/50 transition",
                        p.deleted_at && "opacity-50",
                        selected.has(p.id) && "bg-indigo-50/40",
                      )}>
                        {/* Checkbox */}
                        <td className="px-4 py-3">
                          <input type="checkbox" checked={selected.has(p.id)} onChange={() => toggleSelect(p.id)}
                            className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
                        </td>

                        {/* Thumb */}
                        {visible.includes("thumb") && (
                          <td className="px-4 py-3">
                            <ProductThumb images={p.images} name={p.name} />
                          </td>
                        )}

                        {/* Name */}
                        {visible.includes("name") && (
                          <td className="px-4 py-3">
                            <div className="font-medium text-gray-900 text-sm leading-tight">{p.name}</div>
                            {p.name_ar && (
                              <div className="text-xs text-gray-400 mt-0.5 text-right" dir="rtl">{p.name_ar}</div>
                            )}
                            {p.deleted_at && (
                              <span className="inline-flex items-center gap-1 mt-1 text-xs bg-red-100 text-red-600 px-1.5 py-0.5 rounded-full">
                                <PackageX size={10} /> {t("common.archived")}
                              </span>
                            )}
                          </td>
                        )}

                        {/* SKU */}
                        {visible.includes("sku") && (
                          <td className="px-4 py-3">
                            <span className="text-xs font-mono bg-gray-100 text-gray-600 px-2 py-1 rounded">
                              {p.sku}
                            </span>
                          </td>
                        )}

                        {/* Category */}
                        {visible.includes("category") && (
                          <td className="px-4 py-3">
                            {p.category?.name || categoryMap[p.category_id] ? (
                              <span className="flex items-center gap-1 text-xs bg-indigo-50 text-indigo-700 px-2 py-1 rounded-full w-fit">
                                <Layers size={10} />
                                {p.category?.name ?? categoryMap[p.category_id] ?? "—"}
                              </span>
                            ) : (
                              <span className="text-gray-400 text-xs">—</span>
                            )}
                          </td>
                        )}

                        {/* Brand */}
                        {visible.includes("brand") && (
                          <td className="px-4 py-3">
                            {(p.brand?.name || (p.brand_id && brandMap[p.brand_id])) ? (
                              <span className="flex items-center gap-1 text-xs bg-purple-50 text-purple-700 px-2 py-1 rounded-full w-fit">
                                <Tag size={10} />
                                {p.brand?.name ?? brandMap[p.brand_id!] ?? "—"}
                              </span>
                            ) : (
                              <span className="text-gray-400 text-xs">—</span>
                            )}
                          </td>
                        )}

                        {/* Date */}
                        {visible.includes("created_at") && (
                          <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">
                            {new Date(p.created_at).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" })}
                          </td>
                        )}

                        {/* Actions */}
                        {visible.includes("actions") && (
                          <td className="px-4 py-3">
                            <div className="flex items-center justify-end gap-1">
                              {deleteConfirm === p.id ? (
                                <>
                                  <span className="text-xs text-gray-500 mr-1">{t("common.sure")}</span>
                                  <button onClick={() => deleteMutation.mutate(p.id)}
                                    disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                    className="text-xs bg-amber-500 hover:bg-amber-600 text-white px-2 py-1 rounded transition disabled:opacity-60">
                                    {t("common.archive")}
                                  </button>
                                  <button onClick={() => hardDeleteMutation.mutate(p.id)}
                                    disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                    className="text-xs bg-red-600 hover:bg-red-700 text-white px-2 py-1 rounded transition disabled:opacity-60">
                                    {t("common.deleteForever")}
                                  </button>
                                  <button onClick={() => setDeleteConfirm(null)}
                                    className="text-xs border border-gray-300 hover:bg-gray-50 px-2 py-1 rounded transition">
                                    {t("common.cancel")}
                                  </button>
                                </>
                              ) : (
                                <>
                                  <button onClick={() => openEdit(p)}
                                    className="p-1.5 hover:bg-indigo-50 text-indigo-500 rounded-lg transition">
                                    <Pencil size={15} />
                                  </button>
                                  <button onClick={() => setDeleteConfirm(p.id)}
                                    className="p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition">
                                    <Trash2 size={15} />
                                  </button>
                                </>
                              )}
                            </div>
                          </td>
                        )}
                      </tr>
                    </Fragment>
                  ))}
            </tbody>
          </table>
        </div>

      </div>

      {pageSize !== 0 && (
        <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={pageSize} onPageChange={setPage} />
      )}

      {/* ── Form modal ── */}
      {showForm && (
        <ProductForm product={editProduct} onClose={closeForm} />
      )}
    </div>
  );
}
