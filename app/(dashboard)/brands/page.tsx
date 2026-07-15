"use client";
import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchBrands, bulkDeleteBrands, deleteBrand, type Brand,
} from "@/lib/products";
import BrandForm from "@/components/brands/BrandForm";
import {
  Plus, Pencil, Trash2, Tag, Star, RefreshCw,
  ChevronUp, ChevronDown, ChevronsUpDown,
} from "lucide-react";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";

type SortField = "name" | "created_at";
type SortDir   = "asc" | "desc";

const ALL_COLUMN_KEYS = ["logo", "name", "is_active", "created_at", "actions"] as const;

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc"
    ? <ChevronUp size={13} className="text-indigo-600" />
    : <ChevronDown size={13} className="text-indigo-600" />;
}

export default function BrandsPage() {
  const qc = useQueryClient();
  const { t } = useT();

  const [search,        setSearch]        = useState("");
  const [filterActive,  setFilterActive]  = useState<"" | "true" | "false">("");
  const [filterPopular, setFilterPopular] = useState(false);
  const [page,          setPage]          = useState(1);
  const [pageSize,      setPageSize]      = useState(12);
  const [sortField,     setSortField]     = useState<SortField>("created_at");
  const [sortDir,       setSortDir]       = useState<SortDir>("desc");

  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo,   setCreatedTo]   = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo,   setUpdatedTo]   = useState("");

  const [showForm,       setShowForm]       = useState(false);
  const [editBrand,      setEditBrand]      = useState<Brand | undefined>();
  const [deleteConfirm,  setDeleteConfirm]  = useState<number | null>(null);
  const [selected,       setSelected]       = useState<Set<number>>(new Set());

  // ── Column visibility ─────────────────────────────────────────────────────
  const { visible, setVisible } = useColumnVisibility("cols:brands", [...ALL_COLUMN_KEYS]);

  // ── Query params ──────────────────────────────────────────────────────────
  const params = useMemo(() => {
    const p: Record<string, string | number> = { page, limit: pageSize };
    if (search)        p.keyword    = search;
    if (filterActive)  p.is_active  = filterActive;
    if (filterPopular) p.is_popular = "true";
    return p;
  }, [page, pageSize, search, filterActive, filterPopular]);

  const { data, isLoading, refetch } = useQuery({
    queryKey: ["brands", params],
    queryFn: () => fetchBrands(params),
  });

  const sortedBrands = useMemo(() => {
    const list = [...(data?.brands ?? [])];
    return list.sort((a, b) => {
      const av = sortField === "name" ? a.name.toLowerCase() : new Date(a.created_at).getTime();
      const bv = sortField === "name" ? b.name.toLowerCase() : new Date(b.created_at).getTime();
      if (av < bv) return sortDir === "asc" ? -1 : 1;
      if (av > bv) return sortDir === "asc" ?  1 : -1;
      return 0;
    });
  }, [data, sortField, sortDir]);

  // ── Client-side date filtering ────────────────────────────────────────────
  const brands = sortedBrands.filter(r => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && r.updated_at && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && r.updated_at && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const totalBrands = data?.totalBrands ?? 0;
  const totalPages  = data?.totalPages  ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? brands.length : totalBrands;

  const popularCount = brands.filter(b => b.is_popular).length;

  // ── Mutations ─────────────────────────────────────────────────────────────
  const softDeleteMut = useMutation({
    mutationFn: (id: number) => deleteBrand(id, false),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["brands"] });
      toast.success(t("brands.deleted"));
      setDeleteConfirm(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || t("brands.deleteError")),
  });

  const hardDeleteMut = useMutation({
    mutationFn: (id: number) => deleteBrand(id, true),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["brands"] });
      toast.success(t("common.deleteForever") + " ✓");
      setDeleteConfirm(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || t("brands.deleteError")),
  });

  const bulkDeleteMut = useMutation({
    mutationFn: (ids: number[]) => bulkDeleteBrands(ids, true),
    onSuccess: (_, ids) => {
      qc.invalidateQueries({ queryKey: ["brands"] });
      toast.success(`${ids.length} ${t("brands.bulkDeleted")}`);
      setSelected(new Set());
    },
    onError: (e: any) => toast.error(e.response?.data?.message || t("brands.deleteError")),
  });

  function toggleSort(field: SortField) {
    if (sortField === field) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortField(field); setSortDir("asc"); }
  }

  function toggleSelect(id: number) {
    setSelected(prev => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  }
  function toggleAll() {
    setSelected(selected.size === brands.length ? new Set() : new Set(brands.map(b => b.id)));
  }

  // ── Column toggle options ─────────────────────────────────────────────────
  const columnOptions: ColumnOption[] = [
    { key: "logo",       label: t("common.image") },
    { key: "name",       label: t("common.name") },
    { key: "is_active",  label: t("common.status") },
    { key: "created_at", label: t("products.added") },
    { key: "actions",    label: t("common.actions"), alwaysVisible: true },
  ];

  function Th({ field, label, cls }: { field?: SortField; label: string; cls?: string }) {
    return (
      <th className={cn("px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide", cls)}>
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
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t("brands.title")}</h1>
          <p className="text-sm text-gray-500 mt-0.5">{t("brands.subtitle")}</p>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-indigo-50 flex items-center justify-center">
            <Tag size={22} className="text-indigo-500" />
          </div>
          <div>
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{t("brands.total")}</p>
            <p className="text-2xl font-bold text-gray-900">{totalBrands}</p>
          </div>
        </div>
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-yellow-50 flex items-center justify-center">
            <Star size={22} className="text-yellow-500" />
          </div>
          <div>
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{t("brands.popular")}</p>
            <p className="text-2xl font-bold text-gray-900">{popularCount}</p>
          </div>
        </div>
      </div>

      {/* Filters */}
      <TableToolbar
        total={displayTotal}
        totalLabel="brand"
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("brands.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditBrand(undefined); setShowForm(true); }}
              className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition shadow-sm">
              <Plus size={16} /> {t("brands.new")}
            </button>
          </div>
        }
      >
        <select value={filterActive} onChange={e => { setFilterActive(e.target.value as any); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="">{t("common.allStatus")}</option>
          <option value="true">{t("common.active")}</option>
          <option value="false">{t("common.inactive")}</option>
        </select>

        <button onClick={() => { setFilterPopular(p => !p); setPage(1); }}
          className={cn("flex items-center gap-1.5 px-3 py-2.5 rounded-xl text-sm border transition",
            filterPopular ? "bg-yellow-50 border-yellow-200 text-yellow-700" : "border-gray-300 text-gray-600 hover:bg-gray-50")}>
          <Star size={14} /> {t("brands.isPopular")}
        </button>

        <select value={pageSize} onChange={e => { setPageSize(Number(e.target.value)); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          {[12, 24, 48].map(s => <option key={s} value={s}>{s} / page</option>)}
        </select>

        <button onClick={() => refetch()}
          className="p-2 border border-gray-300 rounded-xl hover:bg-gray-50 transition text-gray-500">
          <RefreshCw size={15} className={isLoading ? "animate-spin" : ""} />
        </button>

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

      {/* Bulk banner */}
      {selected.size > 0 && (
        <div className="bg-indigo-50 border border-indigo-200 rounded-xl px-4 py-3 flex items-center justify-between">
          <span className="text-sm font-medium text-indigo-700">{selected.size} {t("common.selected")}</span>
          <div className="flex gap-2">
            <button onClick={() => setSelected(new Set())} className="text-sm text-indigo-600 hover:underline">
              {t("common.deselectAll")}
            </button>
            <button onClick={() => bulkDeleteMut.mutate(Array.from(selected))}
              disabled={bulkDeleteMut.isPending}
              className="flex items-center gap-1.5 text-sm bg-red-600 hover:bg-red-700 text-white px-3 py-1.5 rounded-lg disabled:opacity-60 transition">
              <Trash2 size={13} /> {t("common.deleteSelected")}
            </button>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="px-4 py-3 w-10">
                  <input type="checkbox"
                    checked={brands.length > 0 && selected.size === brands.length}
                    onChange={toggleAll}
                    className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
                </th>
                {visible.includes("logo") && <th className="px-4 py-3 w-14" />}
                {visible.includes("name") && <Th field="name" label={t("common.name")} />}
                {visible.includes("is_active") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{t("common.status")}</th>
                )}
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
                : brands.length === 0
                  ? (
                    <tr>
                      <td colSpan={visible.length + 1} className="px-4 py-16 text-center">
                        <Tag size={32} className="mx-auto text-gray-300 mb-3" />
                        <p className="text-gray-400 text-sm">{t("brands.noResults")}</p>
                      </td>
                    </tr>
                  )
                  : brands.map(brand => (
                    <tr key={brand.id}
                      className={cn("hover:bg-gray-50/50 transition", selected.has(brand.id) && "bg-indigo-50/40")}>
                      <td className="px-4 py-3">
                        <input type="checkbox" checked={selected.has(brand.id)} onChange={() => toggleSelect(brand.id)}
                          className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
                      </td>

                      {/* Logo */}
                      {visible.includes("logo") && (
                        <td className="px-4 py-3">
                          {brand.logo_url ? (
                            <div className="w-10 h-10 rounded-lg overflow-hidden border border-gray-200 bg-gray-50">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img src={brand.logo_url} alt={brand.name}
                                className="w-full h-full object-contain" />
                            </div>
                          ) : (
                            <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center">
                              <Tag size={16} className="text-gray-400" />
                            </div>
                          )}
                        </td>
                      )}

                      {/* Name */}
                      {visible.includes("name") && (
                        <td className="px-4 py-3">
                          <div className="font-medium text-gray-900 text-sm">{brand.name}</div>
                          {brand.name_ar && (
                            <div className="text-xs text-gray-400 mt-0.5 text-right" dir="rtl">{brand.name_ar}</div>
                          )}
                          {brand.is_popular && (
                            <span className="inline-flex items-center gap-1 mt-1 text-xs bg-yellow-100 text-yellow-700 px-1.5 py-0.5 rounded-full">
                              <Star size={10} /> {t("brands.isPopular")}
                            </span>
                          )}
                        </td>
                      )}

                      {/* Status */}
                      {visible.includes("is_active") && (
                        <td className="px-4 py-3">
                          <span className={cn("text-xs px-2.5 py-1 rounded-full font-medium",
                            brand.is_active
                              ? "bg-green-100 text-green-700"
                              : "bg-gray-100 text-gray-500")}>
                            {brand.is_active ? t("common.active") : t("common.inactive")}
                          </span>
                        </td>
                      )}

                      {/* Date */}
                      {visible.includes("created_at") && (
                        <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">
                          {new Date(brand.created_at).toLocaleDateString("en-GB", {
                            day: "2-digit", month: "short", year: "numeric",
                          })}
                        </td>
                      )}

                      {/* Actions */}
                      {visible.includes("actions") && (
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-end gap-1">
                            {deleteConfirm === brand.id ? (
                              <>
                                <span className="text-xs text-gray-500 mr-1">{t("common.sure")}</span>
                                <button onClick={() => softDeleteMut.mutate(brand.id)}
                                  disabled={softDeleteMut.isPending || hardDeleteMut.isPending}
                                  className="text-xs bg-amber-500 hover:bg-amber-600 text-white px-2 py-1 rounded transition disabled:opacity-60">
                                  {t("common.archive")}
                                </button>
                                <button onClick={() => hardDeleteMut.mutate(brand.id)}
                                  disabled={softDeleteMut.isPending || hardDeleteMut.isPending}
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
                                <button onClick={() => { setEditBrand(brand); setShowForm(true); }}
                                  className="p-1.5 hover:bg-indigo-50 text-indigo-500 rounded-lg transition">
                                  <Pencil size={15} />
                                </button>
                                <button onClick={() => setDeleteConfirm(brand.id)}
                                  className="p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition">
                                  <Trash2 size={15} />
                                </button>
                              </>
                            )}
                          </div>
                        </td>
                      )}
                    </tr>
                  ))}
            </tbody>
          </table>
        </div>

      </div>

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={displayTotal}
        limit={pageSize}
        onPageChange={setPage}
      />

      {showForm && (
        <BrandForm brand={editBrand} onClose={() => { setShowForm(false); setEditBrand(undefined); }} />
      )}
    </div>
  );
}
