"use client";
import { useState, useMemo, Fragment } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchCategories, deleteCategory, hardDeleteCategory, type Category } from "@/lib/categories";
import CategoryForm from "@/components/categories/CategoryForm";
import { useT } from "@/contexts/LanguageContext";
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell,
} from "recharts";
import {
  Plus, Pencil, Trash2, Image as ImageIcon,
  LayoutGrid, List, ChevronUp, ChevronDown, ChevronsUpDown, ChevronRight,
} from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";

const COLORS = ["#6366f1","#8b5cf6","#ec4899","#f59e0b","#10b981","#3b82f6","#f97316"];
const PAGE_SIZES = [10, 20, 50, 100, 0] as const; // 0 = all

type SortField = "name" | "name_ar" | "level" | "status" | "sort_id";
type SortDir   = "asc" | "desc";

function SortIcon({ field, active, dir }: { field: string; active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc" ? <ChevronUp size={13} className="text-indigo-600" /> : <ChevronDown size={13} className="text-indigo-600" />;
}

export default function CategoriesPage() {
  const qc = useQueryClient();
  const { t } = useT();

  // ── Filters ──────────────────────────────────────────────────────────────
  const [search, setSearch]           = useState("");
  const [filterActive, setFilterActive] = useState<"all" | "active" | "inactive">("all");
  const [filterLevel, setFilterLevel]   = useState<"all" | "parent" | "child">("all");
  const [filterWindow, setFilterWindow] = useState<"all" | "yes" | "no">("all");
  const [page, setPage]               = useState(1);
  const [pageSize, setPageSize]       = useState<number>(10);   // 0 = all

  // ── Sort ─────────────────────────────────────────────────────────────────
  const [sortField, setSortField] = useState<SortField>("sort_id");
  const [sortDir, setSortDir]     = useState<SortDir>("asc");

  // ── Date filters ──────────────────────────────────────────────────────────
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo,   setCreatedTo]   = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo,   setUpdatedTo]   = useState("");

  // ── UI State ─────────────────────────────────────────────────────────────
  const [showForm, setShowForm]         = useState(false);
  const [editCategory, setEditCategory] = useState<Category | undefined>();
  const [deleteConfirm, setDeleteConfirm] = useState<number | null>(null);
  const [view, setView]                 = useState<"table" | "grid">("table");

  // ── Expanded parent rows ──────────────────────────────────────────────────
  const [expandedIds, setExpandedIds] = useState<Set<number>>(new Set());
  function toggleExpand(id: number) {
    setExpandedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  // ── Derive server-side params ─────────────────────────────────────────────
  const serverParams = useMemo(() => {
    const p: Record<string, string | number> = {
      page,
      limit: pageSize === 0 ? 9999 : pageSize,
    };
    if (search) p.keyword = search;
    if (filterActive === "active")   p.is_active = "true";
    if (filterActive === "inactive") p.is_active = "false";
    // Server-side level filter
    if (filterLevel === "parent") p.parent_id = "null";
    // "child" handled client-side below (no easy server-side "NOT NULL")
    return p;
  }, [page, pageSize, search, filterActive, filterLevel]);

  // ── Main paginated query ──────────────────────────────────────────────────
  const { data, isLoading } = useQuery({
    queryKey: ["categories", serverParams],
    queryFn: () => fetchCategories(serverParams),
  });

  // ── Chart query (all, no pagination) ─────────────────────────────────────
  const { data: allData } = useQuery({
    queryKey: ["categories-all"],
    queryFn: () => fetchCategories({ limit: 9999 }),
  });

  // ── Client-side child filter + sort ──────────────────────────────────────
  const categories = useMemo(() => {
    let list = data?.categories ?? [];

    // "child" must be filtered client-side
    if (filterLevel === "child") list = list.filter(c => !!c.parent_id);

    // Sort
    list = [...list].sort((a, b) => {
      let av: string | number, bv: string | number;
      switch (sortField) {
        case "name":    av = a.name.toLowerCase();    bv = b.name.toLowerCase();    break;
        case "name_ar": av = a.name_ar.toLowerCase(); bv = b.name_ar.toLowerCase(); break;
        case "level":   av = a.parent_id ? 1 : 0;    bv = b.parent_id ? 1 : 0;    break;
        case "status":  av = a.is_active ? 1 : 0;    bv = b.is_active ? 1 : 0;    break;
        default:        av = a.sort_id;               bv = b.sort_id;              break;
      }
      if (av < bv) return sortDir === "asc" ? -1 : 1;
      if (av > bv) return sortDir === "asc" ?  1 : -1;
      return 0;
    });

    return list;
  }, [data, filterLevel, sortField, sortDir]);

  // ── Client-side date filtering ────────────────────────────────────────────
  const filteredCategories = categories.filter(r => {
    if (filterWindow === "yes" && !r.has_window) return false;
    if (filterWindow === "no"  &&  r.has_window) return false;
    if (createdFrom && r.created_at && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && r.created_at && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && r.updated_at && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && r.updated_at && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });
  const dateFilterActive = createdFrom || createdTo || updatedFrom || updatedTo || filterWindow !== "all";

  // ── Displayed count ───────────────────────────────────────────────────────
  const displayedCount = dateFilterActive
    ? filteredCategories.length
    : filterLevel === "child"
      ? categories.length   // client-side filtered
      : (data?.totalCount ?? 0);

  // ── Chart data ────────────────────────────────────────────────────────────
  const chartData = useMemo(() =>
    (allData?.categories ?? [])
      .filter(c => !c.parent_id)
      .map(parent => ({
        name: parent.name,
        subcategories: (allData?.categories ?? []).filter(c => c.parent_id === parent.id).length,
      })),
  [allData]);

  // ── Stat counters ─────────────────────────────────────────────────────────
  const totalParents  = (allData?.categories ?? []).filter(c => !c.parent_id).length;
  const totalChildren = (allData?.categories ?? []).filter(c => !!c.parent_id).length;
  const totalActive   = (allData?.categories ?? []).filter(c => c.is_active).length;

  // ── Mutations ─────────────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: deleteCategory,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["categories"] });
      qc.invalidateQueries({ queryKey: ["categories-all"] });
      toast.success(t("categories.deleted"));
      setDeleteConfirm(null);
    },
    onError: () => toast.error(t("categories.deleteError")),
  });

  const hardDeleteMutation = useMutation({
    mutationFn: hardDeleteCategory,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["categories"] });
      qc.invalidateQueries({ queryKey: ["categories-all"] });
      toast.success(t("common.deleteForever") + " ✓");
      setDeleteConfirm(null);
    },
    onError: () => toast.error(t("categories.deleteError")),
  });

  // ── Helpers ───────────────────────────────────────────────────────────────
  function toggleSort(field: SortField) {
    if (sortField === field) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortField(field); setSortDir("asc"); }
  }

  function openEdit(cat: Category) { setEditCategory(cat); setShowForm(true); }
  function openNew()  { setEditCategory(undefined); setShowForm(true); }
  function closeForm() {
    setShowForm(false);
    setEditCategory(undefined);
    qc.invalidateQueries({ queryKey: ["categories-all"] });
  }

  // Reset page when filters change
  function handleFilterChange<T>(setter: (v: T) => void, value: T) {
    setter(value);
    setPage(1);
  }

  // ── Pagination ────────────────────────────────────────────────────────────
  const totalPages = pageSize === 0 ? 1 : (data?.totalPages ?? 1);

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div className="p-6 space-y-6">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t("categories.title")}</h1>
          <p className="text-sm text-gray-500 mt-0.5">{t("categories.subtitle")}</p>
        </div>
        <button onClick={openNew}
          className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition">
          <Plus size={16} /> {t("categories.new")}
        </button>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: t("categories.total"),         value: allData?.totalCount ?? 0, color: "bg-indigo-50 text-indigo-700" },
          { label: t("categories.parents"),       value: totalParents,             color: "bg-purple-50 text-purple-700" },
          { label: t("categories.subcategories"), value: totalChildren,            color: "bg-pink-50 text-pink-700" },
          { label: t("categories.active"),        value: totalActive,              color: "bg-green-50 text-green-700" },
        ].map(({ label, value, color }) => (
          <div key={label} className="bg-white rounded-xl border border-gray-200 p-4">
            <p className="text-sm text-gray-500">{label}</p>
            <p className={cn("text-3xl font-bold mt-1 rounded-lg inline-block px-2", color)}>{value}</p>
          </div>
        ))}
      </div>

      {/* Chart */}
      {chartData.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="text-sm font-semibold text-gray-700 mb-4">{t("categories.chartTitle")}</h3>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartData} barSize={36}>
              <XAxis dataKey="name" tick={{ fontSize: 12 }} />
              <YAxis allowDecimals={false} tick={{ fontSize: 12 }} />
              <Tooltip />
              <Bar dataKey="subcategories" radius={[6, 6, 0, 0]}>
                {chartData.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Filters toolbar */}
      <TableToolbar
        total={displayedCount}
        totalLabel={displayedCount !== 1 ? t("common.results") : t("common.result")}
        search={search}
        onSearch={(v) => handleFilterChange(setSearch, v)}
        searchPlaceholder={t("categories.searchPlaceholder")}
        action={
          <div className="flex border border-gray-300 rounded-xl overflow-hidden">
            <button onClick={() => setView("table")}
              className={cn("p-2.5", view === "table" ? "bg-indigo-600 text-white" : "text-gray-500 hover:bg-gray-50")}>
              <List size={16} />
            </button>
            <button onClick={() => setView("grid")}
              className={cn("p-2.5", view === "grid" ? "bg-indigo-600 text-white" : "text-gray-500 hover:bg-gray-50")}>
              <LayoutGrid size={16} />
            </button>
          </div>
        }
      >
        <select value={filterLevel} onChange={e => handleFilterChange(setFilterLevel, e.target.value as any)}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="all">{t("categories.allLevels")}</option>
          <option value="parent">{t("categories.parentsOnly")}</option>
          <option value="child">{t("categories.subcategoriesOnly")}</option>
        </select>

        <select value={filterActive} onChange={e => handleFilterChange(setFilterActive, e.target.value as any)}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="all">{t("common.allStatus")}</option>
          <option value="active">{t("common.active")}</option>
          <option value="inactive">{t("common.inactive")}</option>
        </select>

        <select value={filterWindow} onChange={e => handleFilterChange(setFilterWindow, e.target.value as any)}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="all">{t("categories.allWindow")}</option>
          <option value="yes">{t("categories.hasWindowYes")}</option>
          <option value="no">{t("categories.hasWindowNo")}</option>
        </select>

        <select value={pageSize} onChange={e => { setPageSize(Number(e.target.value)); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          {PAGE_SIZES.map(s => (
            <option key={s} value={s}>{s === 0 ? "All" : `${s} / page`}</option>
          ))}
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

      {/* ── Table View ── */}
      {view === "table" && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="w-8 px-2 py-3" />
                <th className="text-left px-4 py-3 font-medium text-gray-600">{t("common.image")}</th>
                {/* Sortable columns */}
                {([
                  ["name",    t("common.name")],
                  ["name_ar", t("common.arabic")],
                  ["level",   t("categories.level")],
                  ["status",  t("common.status")],
                  ["sort_id", t("common.sort")],
                ] as [SortField, string][]).map(([field, label]) => (
                  <th key={field}
                    className="text-left px-4 py-3 font-medium text-gray-600 cursor-pointer select-none hover:text-indigo-600"
                    onClick={() => toggleSort(field)}>
                    <div className="flex items-center gap-1">
                      {label}
                      <SortIcon field={field} active={sortField === field} dir={sortDir} />
                    </div>
                  </th>
                ))}
                <th className="text-left px-4 py-3 font-medium text-gray-600">{t("categories.window")}</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">{t("common.actions")}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i} className="animate-pulse">
                    {Array.from({ length: 9 }).map((_, j) => (
                      <td key={j} className="px-4 py-3"><div className="h-4 bg-gray-200 rounded" /></td>
                    ))}
                  </tr>
                ))
              ) : filteredCategories.length === 0 ? (
                <tr><td colSpan={9} className="text-center py-12 text-gray-400">{t("categories.noResults")}</td></tr>
              ) : filteredCategories.map(cat => {
                const isParent   = !cat.parent_id;
                const isExpanded = expandedIds.has(cat.id);
                const children   = (allData?.categories ?? []).filter(c => c.parent_id === cat.id);
                const hasChildren = isParent && children.length > 0;

                return (
                  <Fragment key={cat.id}>
                    {/* ── Parent / regular row ── */}
                    <tr
                      className={cn("hover:bg-gray-50", isExpanded && "bg-indigo-50/40")}>
                      {/* Expand chevron */}
                      <td className="px-2 py-3 text-center">
                        {hasChildren ? (
                          <button onClick={() => toggleExpand(cat.id)}
                            className="p-1 rounded hover:bg-indigo-100 text-indigo-500 transition">
                            <ChevronRight size={15}
                              className={cn("transition-transform duration-200", isExpanded && "rotate-90")} />
                          </button>
                        ) : null}
                      </td>
                      <td className="px-4 py-3">
                        {cat.image_url ? (
                          <div className="relative w-10 h-10 rounded-lg overflow-hidden border border-gray-200">
                            <img src={cat.image_url} alt={cat.name} className="absolute inset-0 w-full h-full object-cover" />
                          </div>
                        ) : (
                          <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center">
                            <ImageIcon size={16} className="text-gray-400" />
                          </div>
                        )}
                      </td>
                      <td className="px-4 py-3 font-medium text-gray-900">
                        {cat.name}
                        {hasChildren && (
                          <span className="ml-2 text-xs text-gray-400 font-normal">
                            ({children.length} sub)
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-gray-600" dir="rtl">{cat.name_ar}</td>
                      <td className="px-4 py-3">
                        <span className={cn("px-2 py-1 rounded-full text-xs font-medium",
                          cat.parent_id ? "bg-purple-100 text-purple-700" : "bg-blue-100 text-blue-700")}>
                          {cat.parent_id ? t("categories.sub") : t("categories.parent")}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <span className={cn("px-2 py-1 rounded-full text-xs font-medium",
                          cat.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700")}>
                          {cat.is_active ? t("common.active") : t("common.inactive")}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-gray-500">{cat.sort_id}</td>
                      <td className="px-4 py-3">
                        <span className={cn("px-2 py-1 rounded-full text-xs font-medium",
                          cat.has_window ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500")}>
                          {cat.has_window ? t("common.yes") : t("common.no")}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2 justify-end">
                          <button onClick={() => openEdit(cat)}
                            className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition">
                            <Pencil size={15} />
                          </button>
                          {deleteConfirm === cat.id ? (
                            <div className="flex items-center gap-1 flex-wrap">
                              <span className="text-xs text-gray-500">{t("common.sure")}</span>
                              <button onClick={() => deleteMutation.mutate(cat.id)}
                                disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                className="px-2 py-1 bg-amber-500 hover:bg-amber-600 text-white text-xs rounded-lg disabled:opacity-60">
                                {t("common.archive")}
                              </button>
                              <button onClick={() => hardDeleteMutation.mutate(cat.id)}
                                disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                className="px-2 py-1 bg-red-600 hover:bg-red-700 text-white text-xs rounded-lg disabled:opacity-60">
                                {t("common.deleteForever")}
                              </button>
                              <button onClick={() => setDeleteConfirm(null)}
                                className="px-2 py-1 border text-xs rounded-lg">{t("common.cancel")}</button>
                            </div>
                          ) : (
                            <button onClick={() => setDeleteConfirm(cat.id)}
                              className="p-1.5 hover:bg-red-50 rounded-lg text-red-500 transition">
                              <Trash2 size={15} />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>

                    {/* ── Subcategory rows (expanded) ── */}
                    {isExpanded && children.map(child => (
                      <tr key={child.id} className="bg-indigo-50/20 hover:bg-indigo-50/50 border-l-4 border-indigo-300">
                        <td className="px-2 py-2" />
                        <td className="px-4 py-2 pl-8">
                          {child.image_url ? (
                            <div className="relative w-8 h-8 rounded-lg overflow-hidden border border-gray-200">
                              <img src={child.image_url} alt={child.name} className="absolute inset-0 w-full h-full object-cover" />
                            </div>
                          ) : (
                            <div className="w-8 h-8 rounded-lg bg-gray-100 flex items-center justify-center">
                              <ImageIcon size={13} className="text-gray-400" />
                            </div>
                          )}
                        </td>
                        <td className="px-4 py-2 text-sm text-gray-800">{child.name}</td>
                        <td className="px-4 py-2 text-sm text-gray-500" dir="rtl">{child.name_ar}</td>
                        <td className="px-4 py-2">
                          <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-700">Sub</span>
                        </td>
                        <td className="px-4 py-2">
                          <span className={cn("px-2 py-0.5 rounded-full text-xs font-medium",
                            child.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700")}>
                            {child.is_active ? t("common.active") : t("common.inactive")}
                          </span>
                        </td>
                        <td className="px-4 py-2 text-sm text-gray-500">{child.sort_id}</td>
                        <td className="px-4 py-2">
                          <span className={cn("px-2 py-0.5 rounded-full text-xs font-medium",
                            child.has_window ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500")}>
                            {child.has_window ? t("common.yes") : t("common.no")}
                          </span>
                        </td>
                        <td className="px-4 py-2">
                          <div className="flex items-center gap-2 justify-end">
                            <button onClick={() => openEdit(child)}
                              className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition">
                              <Pencil size={14} />
                            </button>
                            {deleteConfirm === child.id ? (
                              <div className="flex items-center gap-1 flex-wrap">
                                <span className="text-xs text-gray-500">{t("common.sure")}</span>
                                <button onClick={() => deleteMutation.mutate(child.id)}
                                  disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                  className="px-2 py-1 bg-amber-500 hover:bg-amber-600 text-white text-xs rounded-lg disabled:opacity-60">
                                  {t("common.archive")}
                                </button>
                                <button onClick={() => hardDeleteMutation.mutate(child.id)}
                                  disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                  className="px-2 py-1 bg-red-600 hover:bg-red-700 text-white text-xs rounded-lg disabled:opacity-60">
                                  {t("common.deleteForever")}
                                </button>
                                <button onClick={() => setDeleteConfirm(null)}
                                  className="px-2 py-1 border text-xs rounded-lg">{t("common.cancel")}</button>
                              </div>
                            ) : (
                              <button onClick={() => setDeleteConfirm(child.id)}
                                className="p-1.5 hover:bg-red-50 rounded-lg text-red-500 transition">
                                <Trash2 size={14} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </Fragment>
                );
              })}
            </tbody>
          </table>

        </div>
      )}

      {pageSize !== 0 && (
        <TablePagination page={page} totalPages={totalPages} total={displayedCount} limit={pageSize} onPageChange={setPage} />
      )}

      {/* ── Grid View ── */}
      {view === "grid" && (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {isLoading
            ? Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="bg-white rounded-xl border border-gray-200 p-4 animate-pulse h-40" />
              ))
            : filteredCategories.map(cat => {
                const isParent   = !cat.parent_id;
                const isExpanded = expandedIds.has(cat.id);
                const children   = (allData?.categories ?? []).filter(c => c.parent_id === cat.id);
                const hasChildren = isParent && children.length > 0;

                return (
                  <div key={cat.id} className="flex flex-col gap-2">
                    {/* Parent / regular card */}
                    <div className={cn("bg-white rounded-xl border overflow-hidden hover:shadow-md transition",
                      isExpanded ? "border-indigo-300 shadow-sm" : "border-gray-200")}>
                      <div className="relative h-28 bg-gray-100">
                        {cat.image_url
                          ? <img src={cat.image_url} alt={cat.name} className="absolute inset-0 w-full h-full object-cover" />
                          : <div className="absolute inset-0 flex items-center justify-center"><ImageIcon size={32} className="text-gray-300" /></div>
                        }
                        <span className={cn("absolute top-2 right-2 px-2 py-0.5 rounded-full text-xs font-medium",
                          cat.is_active ? "bg-green-500 text-white" : "bg-red-500 text-white")}>
                          {cat.is_active ? t("common.active") : t("common.inactive")}
                        </span>
                      </div>
                      <div className="p-3">
                        <p className="font-semibold text-sm text-gray-900 truncate">{cat.name}</p>
                        <p className="text-xs text-gray-500 truncate" dir="rtl">{cat.name_ar}</p>
                        <div className="flex items-center justify-between mt-3">
                          <span className={cn("text-xs px-2 py-0.5 rounded-full",
                            cat.parent_id ? "bg-purple-100 text-purple-700" : "bg-blue-100 text-blue-700")}>
                            {cat.parent_id ? t("categories.sub") : t("categories.parent")}
                          </span>
                          <div className="flex gap-1 items-center">
                            {hasChildren && (
                              <button onClick={() => toggleExpand(cat.id)}
                                className={cn("p-1 rounded text-indigo-500 hover:bg-indigo-50 transition text-xs flex items-center gap-0.5")}>
                                <ChevronRight size={13} className={cn("transition-transform duration-200", isExpanded && "rotate-90")} />
                                {children.length}
                              </button>
                            )}
                            <button onClick={() => openEdit(cat)} className="p-1 hover:bg-indigo-50 rounded text-indigo-600"><Pencil size={13} /></button>
                            <button onClick={() => setDeleteConfirm(deleteConfirm === cat.id ? null : cat.id)}
                              className="p-1 hover:bg-red-50 rounded text-red-500"><Trash2 size={13} /></button>
                          </div>
                        </div>
                        {deleteConfirm === cat.id && (
                          <div className="mt-2 space-y-1">
                            <div className="flex gap-1">
                              <button onClick={() => deleteMutation.mutate(cat.id)}
                                disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                className="flex-1 py-1 bg-amber-500 hover:bg-amber-600 text-white text-xs rounded-lg disabled:opacity-60">
                                {t("common.archive")}
                              </button>
                              <button onClick={() => hardDeleteMutation.mutate(cat.id)}
                                disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                className="flex-1 py-1 bg-red-600 hover:bg-red-700 text-white text-xs rounded-lg disabled:opacity-60">
                                {t("common.deleteForever")}
                              </button>
                            </div>
                            <button onClick={() => setDeleteConfirm(null)}
                              className="w-full py-1 border text-xs rounded-lg">{t("common.cancel")}</button>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Sub-cards (expanded) */}
                    {isExpanded && (
                      <div className="pl-4 flex flex-col gap-2 border-l-2 border-indigo-300">
                        {children.map(child => (
                          <div key={child.id} className="bg-indigo-50/60 rounded-xl border border-indigo-100 overflow-hidden hover:shadow-sm transition">
                            <div className="relative h-20 bg-gray-100">
                              {child.image_url
                                ? <img src={child.image_url} alt={child.name} className="absolute inset-0 w-full h-full object-cover" />
                                : <div className="absolute inset-0 flex items-center justify-center"><ImageIcon size={24} className="text-gray-300" /></div>
                              }
                              <span className={cn("absolute top-2 right-2 px-1.5 py-0.5 rounded-full text-xs font-medium",
                                child.is_active ? "bg-green-500 text-white" : "bg-red-500 text-white")}>
                                {child.is_active ? t("common.active") : t("common.inactive")}
                              </span>
                            </div>
                            <div className="p-2">
                              <p className="font-medium text-xs text-gray-900 truncate">{child.name}</p>
                              <p className="text-xs text-gray-400 truncate" dir="rtl">{child.name_ar}</p>
                              <div className="flex items-center justify-end gap-1 mt-2">
                                <button onClick={() => openEdit(child)} className="p-1 hover:bg-indigo-100 rounded text-indigo-600"><Pencil size={12} /></button>
                                <button onClick={() => setDeleteConfirm(deleteConfirm === child.id ? null : child.id)}
                                  className="p-1 hover:bg-red-50 rounded text-red-500"><Trash2 size={12} /></button>
                              </div>
                              {deleteConfirm === child.id && (
                                <div className="mt-1 space-y-1">
                                  <div className="flex gap-1">
                                    <button onClick={() => deleteMutation.mutate(child.id)}
                                      disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                      className="flex-1 py-0.5 bg-amber-500 hover:bg-amber-600 text-white text-xs rounded-lg disabled:opacity-60">
                                      {t("common.archive")}
                                    </button>
                                    <button onClick={() => hardDeleteMutation.mutate(child.id)}
                                      disabled={deleteMutation.isPending || hardDeleteMutation.isPending}
                                      className="flex-1 py-0.5 bg-red-600 hover:bg-red-700 text-white text-xs rounded-lg disabled:opacity-60">
                                      {t("common.deleteForever")}
                                    </button>
                                  </div>
                                  <button onClick={() => setDeleteConfirm(null)}
                                    className="w-full py-0.5 border text-xs rounded-lg">{t("common.cancel")}</button>
                                </div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
        </div>
      )}

      {/* Modal Form */}
      {showForm && <CategoryForm category={editCategory} onClose={closeForm} />}
    </div>
  );
}
