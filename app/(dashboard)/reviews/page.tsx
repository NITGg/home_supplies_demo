"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchCustomerReviews, deleteCustomerReview,
  fetchCourierReviews, deleteCourierReview,
  fetchSupplierReviews, deleteSupplierReview,
  type Review,
} from "@/lib/reviews";
import { useT } from "@/contexts/LanguageContext";
import { Star, Trash2, RefreshCw, Eye } from "lucide-react";
import toast from "react-hot-toast";
import Link from "next/link";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

function fmtDate(d: string) { return new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }); }

function StarRating({ rating, size = 13, showText = true }: { rating: number; size?: number; showText?: boolean }) {
  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map(s => (
        <Star key={s} size={size} className={s <= rating ? "text-amber-400 fill-amber-400" : "text-gray-200 fill-gray-200"} />
      ))}
      {showText && <span className="ml-1 text-xs text-gray-500">{rating}/5</span>}
    </div>
  );
}

const AVATAR_COLORS = ["bg-indigo-500", "bg-emerald-500", "bg-rose-500", "bg-amber-500", "bg-sky-500", "bg-violet-500", "bg-teal-500", "bg-fuchsia-500"];
function Avatar({ name }: { name?: string }) {
  const clean = name?.trim() ?? "";
  const letter = clean ? clean[0].toUpperCase() : "?";
  const idx = clean ? clean.charCodeAt(0) % AVATAR_COLORS.length : 0;
  return (
    <div className={`w-10 h-10 shrink-0 rounded-full ${AVATAR_COLORS[idx]} text-white flex items-center justify-center font-semibold`}>
      {letter}
    </div>
  );
}

type Source = "customer" | "courier" | "supplier";
type Tab = "overview" | Source;

function sourceLabel(source: string, t: (k: string) => string) {
  if (source === "customer") return t("reviews.customer");
  if (source === "courier") return t("reviews.courier");
  if (source === "supplier") return t("reviews.supplier");
  return source;
}
function sourceBadgeClass(source: string) {
  if (source === "customer") return "bg-blue-100 text-blue-800";
  if (source === "courier") return "bg-green-100 text-green-800";
  if (source === "supplier") return "bg-purple-100 text-purple-800";
  return "bg-gray-100 text-gray-800";
}

function reviewerName(r: Review): string | undefined {
  if (r.source === "customer") return r.user?.full_name;
  if (r.source === "courier") return r.courier?.user?.full_name;
  if (r.source === "supplier") return r.supplier?.user?.full_name;
  return undefined;
}

const ROLE_OPTIONS: Record<Source, { value: string; labelKey: string }[]> = {
  customer: [],
  courier:  [{ value: "CUSTOMER", labelKey: "reviews.customer" }, { value: "SUPPLIER", labelKey: "reviews.supplier" }],
  supplier: [{ value: "CUSTOMER", labelKey: "reviews.customer" }, { value: "COURIER", labelKey: "reviews.courier" }],
};

const FETCH_FNS = { customer: fetchCustomerReviews, courier: fetchCourierReviews, supplier: fetchSupplierReviews };
const OV_LIMIT = 1000;

export default function ReviewsPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("overview");
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);

  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo,   setCreatedTo]   = useState("");

  const [roleFilter, setRoleFilter] = useState("");
  const [ratingFilter, setRatingFilter] = useState("");

  // Overview tab state
  const [ovSource, setOvSource] = useState<Source>("supplier");
  const [ovStar, setOvStar] = useState<number | null>(null);
  const [ovPage, setOvPage] = useState(1);
  const OV_PAGE_SIZE = 10;

  const ALL_COLS = ["reviewer", "role", "rating", "comment", "created_at", "actions"] as const;
  const { visible, setVisible } = useColumnVisibility("cols:reviews-unified", [...ALL_COLS]);

  const isTable = tab !== "overview";
  const tableSource = (isTable ? tab : "customer") as Source;

  /* ── table-tab params & queries ──────────────────────────────────────── */
  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;
  if (roleFilter) params.review_from = roleFilter;
  if (ratingFilter) params.rating = Number(ratingFilter);

  const customerQ = useQuery({
    queryKey: ["customer-reviews", params],
    queryFn: () => fetchCustomerReviews(params),
    enabled: tab === "customer",
  });
  const courierQ = useQuery({
    queryKey: ["courier-reviews", params],
    queryFn: () => fetchCourierReviews(params),
    enabled: tab === "courier",
  });
  const supplierQ = useQuery({
    queryKey: ["supplier-reviews", params],
    queryFn: () => fetchSupplierReviews(params),
    enabled: tab === "supplier",
  });
  const tableQ = tab === "customer" ? customerQ : tab === "courier" ? courierQ : supplierQ;

  /* ── overview query (fetch a large page to aggregate locally) ────────── */
  const overviewQ = useQuery({
    queryKey: ["overview-reviews", ovSource],
    queryFn: () => FETCH_FNS[ovSource]({ page: 1, limit: OV_LIMIT }),
    enabled: tab === "overview",
  });

  const activeQ = tab === "overview" ? overviewQ : tableQ;
  const total = activeQ.data?.totalReviews ?? 0;

  /* ── table-tab derived data ──────────────────────────────────────────── */
  const allReviews = tableQ.data?.reviews ?? [];
  const reviews = allReviews.filter(r => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    return true;
  });
  const displayTotal = (createdFrom || createdTo) ? reviews.length : (tableQ.data?.totalReviews ?? 0);
  const totalPages = tableQ.data?.totalPages ?? 1;

  /* ── overview derived data ───────────────────────────────────────────── */
  const ovLoaded = overviewQ.data?.reviews ?? [];
  const ovTotal = overviewQ.data?.totalReviews ?? ovLoaded.length;
  const ovCounts = [0, 0, 0, 0, 0]; // index 0 → 1★ … index 4 → 5★
  let ovSum = 0;
  ovLoaded.forEach(r => { const i = Math.min(5, Math.max(1, Math.round(r.rating))) - 1; ovCounts[i]++; ovSum += r.rating; });
  const ovAvg = ovLoaded.length ? ovSum / ovLoaded.length : 0;
  const ovFilteredCards = ovStar ? ovLoaded.filter(r => Math.round(r.rating) === ovStar) : ovLoaded;
  const ovTotalFiltered = ovFilteredCards.length;
  const ovTotalPages = Math.ceil(ovTotalFiltered / OV_PAGE_SIZE) || 1;
  const currentOvCards = ovFilteredCards.slice((ovPage - 1) * OV_PAGE_SIZE, ovPage * OV_PAGE_SIZE);

  /* ── delete (all sources hit the same endpoint via review_from) ──────── */
  const delTableMut = useMutation({
    mutationFn: ({ id, source }: { id: number; source: string }) => deleteSupplierReview(id, source.toUpperCase()),
    onSuccess: () => {
      toast.success(t("reviews.deleted"));
      qc.invalidateQueries({ queryKey: [`${tableSource}-reviews`] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("reviews.deleteError")),
  });
  const delOvMut = useMutation({
    mutationFn: ({ id, source }: { id: number; source: string }) => deleteSupplierReview(id, source.toUpperCase()),
    onSuccess: () => {
      toast.success(t("reviews.deleted"));
      qc.invalidateQueries({ queryKey: ["overview-reviews"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("reviews.deleteError")),
  });

  /* ── tab switch ──────────────────────────────────────────────────────── */
  function switchTab(newTab: Tab) {
    setTab(newTab); setPage(1); setSearch(""); setDelConfirm(null);
    setCreatedFrom(""); setCreatedTo("");
    setRoleFilter(""); setRatingFilter("");
    setOvStar(null);
    setOvPage(1);
  }

  /* ── table columns ───────────────────────────────────────────────────── */
  const columnOptions: ColumnOption[] = [
    { key: "reviewer",   label: t("reviews.reviewer") },
    { key: "role",       label: t("reviews.role") },
    { key: "rating",     label: t("reviews.rating") },
    { key: "comment",    label: t("reviews.comment") },
    { key: "created_at", label: "Date" },
    { key: "actions",    label: t("common.actions"), alwaysVisible: true },
  ];

  const columns: Column<Review>[] = [
    {
      key: "reviewer",
      label: t("reviews.reviewer"),
      sortable: true,
      getValue: r => reviewerName(r),
      render: r => {
        const name = reviewerName(r);
        return name ? <p className="font-medium text-gray-900">{name}</p> : <span>—</span>;
      },
    },
    {
      key: "role",
      label: t("reviews.role"),
      sortable: true,
      getValue: r => r.source,
      render: r => (
        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${sourceBadgeClass(r.source)}`}>
          {sourceLabel(r.source, t)}
        </span>
      ),
    },
    {
      key: "rating",
      label: t("reviews.rating"),
      sortable: true,
      getValue: r => r.rating,
      render: r => <StarRating rating={r.rating} />,
    },
    {
      key: "comment",
      label: t("reviews.comment"),
      render: r => {
        const orderId = r.order_id || (r as any).orderId || (r as any).order?.id;
        return (
          <div className="text-gray-600 max-w-xs">
            <p className="truncate">{r.comment?.trim() ? r.comment : "—"}</p>
            {orderId && (
              <div className="mt-1">
                <button
                  type="button"
                  onClick={(e) => { 
                    e.preventDefault(); 
                    e.stopPropagation(); 
                    window.location.href = `/orders?id=${orderId}`; 
                  }}
                  className="inline-flex items-center gap-1.5 px-2 py-1 text-[11px] font-medium text-indigo-600 bg-indigo-50 border border-indigo-200 rounded hover:bg-indigo-100 hover:text-indigo-700 transition cursor-pointer"
                >
                  <Eye size={11} />
                  View Order #{orderId}
                </button>
              </div>
            )}
          </div>
        );
      },
    },
    {
      key: "created_at",
      label: "Date",
      sortable: true,
      getValue: r => new Date(r.created_at),
      render: r => <span className="text-gray-500 text-xs">{fmtDate(r.created_at)}</span>,
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: r => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === r.id ? (
            <>
              <button onClick={() => delTableMut.mutate({ id: r.id, source: r.source })} disabled={delTableMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <button onClick={() => setDelConfirm(r.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
          )}
        </div>
      ),
    },
  ];

  const roleOpts = ROLE_OPTIONS[tableSource];

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Star size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("reviews.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("reviews.subtitle")}</p>
        </div>
        <button onClick={() => activeQ.refetch()} disabled={activeQ.isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={activeQ.isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">{t("reviews.total")}</p>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 overflow-x-auto">
        {(["overview", "customer", "courier", "supplier"] as Tab[]).map(tabKey => (
          <button key={tabKey} onClick={() => switchTab(tabKey)}
            className={`px-5 py-2.5 text-sm font-medium border-b-2 transition whitespace-nowrap ${tab === tabKey ? "border-indigo-600 text-indigo-600" : "border-transparent text-gray-500 hover:text-gray-700"}`}>
            {tabKey === "overview" ? t("reviews.overview")
              : tabKey === "customer" ? t("reviews.customerReviews")
              : tabKey === "courier" ? t("reviews.courierReviews")
              : t("reviews.supplierReviews")}
          </button>
        ))}
      </div>

      {tab === "overview" ? (
        /* ── Google Play–style overview ─────────────────────────────────── */
        <div className="space-y-5">
          {/* source switcher */}
          <div className="flex items-center justify-between flex-wrap gap-3">
            <div className="inline-flex rounded-xl bg-gray-100 p-1">
              {(["supplier", "customer", "courier"] as Source[]).map(s => (
                <button key={s}
                  onClick={() => { setOvSource(s); setOvStar(null); setDelConfirm(null); setOvPage(1); }}
                  className={`px-4 py-1.5 text-sm rounded-lg transition ${ovSource === s ? "bg-white shadow-sm text-indigo-600 font-medium" : "text-gray-500 hover:text-gray-700"}`}>
                  {sourceLabel(s, t)}
                </button>
              ))}
            </div>
            {ovStar !== null && (
              <button onClick={() => setOvStar(null)} className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700">
                {ovStar}★ · {t("common.clear")} ✕
              </button>
            )}
          </div>

          {/* summary card */}
          <div className="bg-white border border-gray-100 rounded-2xl p-6 flex flex-col sm:flex-row gap-6 sm:gap-8">
            <div className="flex flex-col items-center justify-center text-center sm:pr-8 sm:border-r border-gray-100 sm:min-w-[150px]">
              <p className="text-5xl font-bold text-gray-900 leading-none">{ovAvg.toFixed(1)}</p>
              <div className="my-2"><StarRating rating={Math.round(ovAvg)} size={18} showText={false} /></div>
              <p className="text-xs text-gray-400">{ovTotal} {t("reviews.reviewsWord")}</p>
            </div>
            <div className="flex-1 flex flex-col justify-center gap-1.5">
              {[5, 4, 3, 2, 1].map(star => {
                const count = ovCounts[star - 1];
                const pct = ovLoaded.length ? (count / ovLoaded.length) * 100 : 0;
                const active = ovStar === star;
                return (
                  <button key={star} onClick={() => { setOvStar(active ? null : star); setOvPage(1); }} className="flex items-center gap-3 w-full group">
                    <span className="text-xs text-gray-500 w-3 text-right">{star}</span>
                    <div className="flex-1 h-2.5 rounded-full bg-gray-100 overflow-hidden">
                      <div className={`h-full rounded-full transition-all ${active ? "bg-indigo-600" : "bg-amber-400 group-hover:bg-amber-500"}`} style={{ width: `${pct}%` }} />
                    </div>
                    <span className="text-xs text-gray-400 w-8 text-right tabular-nums">{count}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* review cards */}
          {overviewQ.isLoading ? (
            <div className="space-y-3">
              {[0, 1, 2].map(i => (
                <div key={i} className="bg-white border border-gray-100 rounded-2xl p-4 animate-pulse flex gap-3">
                  <div className="w-10 h-10 rounded-full bg-gray-100" />
                  <div className="flex-1 space-y-2 py-1">
                    <div className="h-3 bg-gray-100 rounded w-1/3" />
                    <div className="h-3 bg-gray-100 rounded w-2/3" />
                  </div>
                </div>
              ))}
            </div>
          ) : currentOvCards.length === 0 ? (
            <div className="bg-white border border-gray-100 rounded-2xl py-16 flex flex-col items-center gap-3 text-gray-400">
              <Star size={36} className="text-gray-300" />
              <p className="text-sm">{t("reviews.noResults")}</p>
            </div>
          ) : (
            <div className="space-y-3">
              {currentOvCards.map(r => {
                const name = reviewerName(r);
                return (
                  <div key={r.id} className="bg-white border border-gray-100 rounded-2xl p-4 hover:shadow-sm transition group">
                    <div className="flex items-start gap-3">
                      <Avatar name={name} />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex items-center gap-2 flex-wrap">
                            <p className="font-medium text-gray-900 truncate">{name ?? "—"}</p>
                            <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium ${sourceBadgeClass(r.source)}`}>
                              {sourceLabel(r.source, t)}
                            </span>
                          </div>
                          <div className="flex items-center gap-2 shrink-0">
                            <span className="text-xs text-gray-400">{fmtDate(r.created_at)}</span>
                            {delConfirm === r.id ? (
                              <div className="flex items-center gap-1">
                                <button onClick={() => delOvMut.mutate({ id: r.id, source: r.source })} disabled={delOvMut.isPending} className="px-2 py-1 text-[11px] bg-red-600 text-white rounded-md disabled:opacity-50">{t("common.yes")}</button>
                                <button onClick={() => setDelConfirm(null)} className="px-2 py-1 text-[11px] border border-gray-300 rounded-md">{t("common.cancel")}</button>
                              </div>
                            ) : (
                              <button onClick={() => setDelConfirm(r.id)} className="p-1.5 rounded-lg text-gray-300 hover:text-red-600 hover:bg-red-50 opacity-0 group-hover:opacity-100 transition"><Trash2 size={14} /></button>
                            )}
                          </div>
                        </div>
                        <div className="mt-1"><StarRating rating={r.rating} size={14} showText={false} /></div>
                        <div className="mt-2 text-sm text-gray-600 whitespace-pre-line break-words">
                          {r.comment?.trim() ? r.comment : <span className="italic text-gray-300">{t("reviews.noComment")}</span>}
                        </div>
                        {(() => {
                          const orderId = r.order_id || (r as any).orderId || (r as any).order?.id;
                          if (orderId) {
                            return (
                              <div className="mt-2">
                                <button
                                  type="button"
                                  onClick={(e) => { 
                                    e.preventDefault(); 
                                    e.stopPropagation(); 
                                    window.location.href = `/orders?id=${orderId}`; 
                                  }}
                                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-indigo-600 bg-indigo-50 border border-indigo-200 rounded-lg hover:bg-indigo-100 hover:text-indigo-700 transition cursor-pointer"
                                >
                                  <Eye size={13} />
                                  View Order #{orderId}
                                </button>
                              </div>
                            );
                          }
                          return null;
                        })()}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
          {ovTotalFiltered > 0 && (
            <div className="pt-2">
              <TablePagination
                page={ovPage}
                totalPages={ovTotalPages}
                total={ovTotalFiltered}
                limit={OV_PAGE_SIZE}
                onPageChange={setOvPage}
              />
            </div>
          )}
        </div>
      ) : (
        /* ── table view (customer / courier / supplier) ─────────────────── */
        <>
          <TableToolbar
            total={displayTotal}
            totalLabel="review"
            search={search}
            onSearch={(v) => { setSearch(v); setPage(1); }}
            searchPlaceholder={t("reviews.searchPlaceholder")}
            action={
              <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            }
          >
            {roleOpts.length > 0 && (
              <div className="flex items-center gap-2">
                <label className="text-xs text-gray-500">{t("reviews.role")}</label>
                <select
                  value={roleFilter}
                  onChange={e => { setRoleFilter(e.target.value); setPage(1); }}
                  className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg bg-white"
                >
                  <option value="">{t("common.all")}</option>
                  {roleOpts.map(o => <option key={o.value} value={o.value}>{t(o.labelKey)}</option>)}
                </select>
              </div>
            )}
            <div className="flex items-center gap-2">
              <label className="text-xs text-gray-500">{t("reviews.rating")}</label>
              <select
                value={ratingFilter}
                onChange={e => { setRatingFilter(e.target.value); setPage(1); }}
                className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg bg-white"
              >
                <option value="">{t("common.all")}</option>
                {[1, 2, 3, 4, 5].map(r => <option key={r} value={String(r)}>{r} Star{r > 1 ? "s" : ""}</option>)}
              </select>
            </div>
            <DateRangeFilter
              label={t("common.createdAt")}
              from={createdFrom} to={createdTo}
              onFromChange={v => { setCreatedFrom(v); setPage(1); }}
              onToChange={v => { setCreatedTo(v); setPage(1); }}
            />
          </TableToolbar>

          <DataTable<Review>
            columns={columns.filter(c => visible.includes(c.key))}
            rows={reviews}
            keyExtractor={r => `${r.source}-${r.id}`}
            isLoading={tableQ.isFetching}
            emptyText={t("reviews.noResults")}
            emptyIcon={<Star size={36} className="text-gray-300" />}
          />

          <TablePagination
            page={page}
            totalPages={totalPages}
            total={displayTotal}
            limit={20}
            onPageChange={setPage}
          />
        </>
      )}
    </div>
  );
}
