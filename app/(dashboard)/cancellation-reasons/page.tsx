"use client";
import { useState, useEffect, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchCancellationReasons,
  createCancellationReason,
  updateCancellationReason,
  deleteCancellationReason,
  type CancellationReason,
} from "@/lib/cancellation-reasons";
import { fetchOrders, type Order } from "@/lib/orders";
import { useT } from "@/contexts/LanguageContext";
import {
  XCircle, Plus, Pencil, Trash2, RefreshCw, X,
  Phone, MessageSquare, BarChart2, List, ShoppingCart,
} from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import {
  PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Area, AreaChart,
} from "recharts";
import Link from "next/link";

const ROLE_LABELS: Record<number, string> = { 1: "Customer", 2: "Courier", 3: "Admin" };
const ROLE_COLORS: Record<number, string> = { 1: "#6366f1", 2: "#22c55e", 3: "#f59e0b" };
const PIE_COLORS = ["#6366f1", "#22c55e", "#f59e0b", "#ec4899", "#06b6d4"];

type PageTab = "reasons" | "cancelled" | "charts";

const ALL_COLUMN_KEYS = ["id", "reason_en", "reason_ar", "role_id", "created_at", "updated_at", "actions"] as const;

export default function CancellationReasonsPage() {
  const { t, isRTL } = useT();
  const qc = useQueryClient();
  const [tab, setTab] = useState<PageTab>("reasons");

  // ── Reasons tab state ────────────────────────────────────────────────────────
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<CancellationReason | null>(null);

  // ── Cancelled orders tab state ───────────────────────────────────────────────
  const [cancelPage, setCancelPage] = useState(1);
  const [cancelSearch, setCancelSearch] = useState("");
  const [debouncedCancelSearch, setDebouncedCancelSearch] = useState("");
  const [cancelSupplier, setCancelSupplier] = useState("");
  const [cancelCourier, setCancelCourier] = useState("");
  const [cancelCustomer, setCancelCustomer] = useState("");
  const [cancelFrom, setCancelFrom] = useState("");
  const [cancelTo, setCancelTo] = useState("");

  useEffect(() => {
    const t = setTimeout(() => setDebouncedCancelSearch(cancelSearch), 350);
    return () => clearTimeout(t);
  }, [cancelSearch]);

  // Column visibility
  const { visible, setVisible } = useColumnVisibility("cols:cancellation-reasons", [...ALL_COLUMN_KEYS]);

  // Reasons query
  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["cancellation-reasons", params],
    queryFn: () => fetchCancellationReasons(params),
  });

  // Cancelled orders query
  const cancelParams: Record<string, string | number> = {
    page: cancelPage,
    limit: 15,
    status: "CANCELLED",
    includes: "customer,courier.user,supplier.user",
  };
  if (debouncedCancelSearch) cancelParams.keyword = debouncedCancelSearch;

  const {
    data: cancelData,
    isLoading: cancelLoading,
    isFetching: cancelFetching,
    refetch: cancelRefetch,
  } = useQuery({
    queryKey: ["cancelled-orders", cancelPage, debouncedCancelSearch],
    queryFn: () => fetchOrders(cancelParams),
    enabled: tab === "cancelled" || tab === "charts",
  });

  // Client-side filters on reasons
  const allReasons = data?.reasons ?? [];
  const reasons = allReasons.filter(r => {
    if (roleFilter !== "all" && String(r.role_id) !== roleFilter) return false;
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  // Client-side filter cancelled orders by customer + supplier + courier + date
  const allCancelled = cancelData?.orders ?? [];
  const cancelledOrders = allCancelled.filter(o => {
    if (cancelCustomer) {
      const cName = (o.customer?.full_name ?? "").toLowerCase();
      if (!cName.includes(cancelCustomer.toLowerCase())) return false;
    }
    if (cancelSupplier) {
      const sName = (o.supplier?.user?.full_name ?? "").toLowerCase();
      if (!sName.includes(cancelSupplier.toLowerCase())) return false;
    }
    if (cancelCourier) {
      const courierN = (o.courier?.user?.full_name ?? o.courier?.full_name ?? "").toLowerCase();
      if (!courierN.includes(cancelCourier.toLowerCase())) return false;
    }
    if (cancelFrom && o.canceled_at && new Date(o.canceled_at) < new Date(cancelFrom)) return false;
    if (cancelTo && o.canceled_at && new Date(o.canceled_at) > new Date(cancelTo + "T23:59:59")) return false;
    return true;
  });

  // Unique names for datalist comboboxes
  const supplierNames = [...new Set(allCancelled.map(o => o.supplier?.user?.full_name).filter(Boolean))] as string[];
  const courierNames = [...new Set(allCancelled.map(o => o.courier?.user?.full_name ?? o.courier?.full_name).filter(Boolean))] as string[];
  const customerNames = [...new Set(allCancelled.map(o => o.customer?.full_name).filter(Boolean))] as string[];

  const total = data?.totalReasons ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo || roleFilter !== "all") ? reasons.length : total;

  const cancelTotal = cancelData?.totalOrders ?? 0;
  const cancelTotalPages = cancelData?.totalPages ?? 1;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteCancellationReason(id),
    onSuccess: () => {
      toast.success(t("cancellationReasons.deleted"));
      qc.invalidateQueries({ queryKey: ["cancellation-reasons"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("cancellationReasons.deleteError")),
  });

  // Charts data
  const roleDistData = useMemo(() => {
    const counts: Record<number, number> = {};
    (data?.reasons ?? []).forEach(r => {
      counts[r.role_id] = (counts[r.role_id] ?? 0) + 1;
    });
    return Object.entries(counts).map(([role, count]) => ({
      name: ROLE_LABELS[Number(role)] ?? `Role ${role}`,
      value: count,
    }));
  }, [data]);

  const trendData = useMemo(() => {
    const cancelled = cancelData?.orders ?? [];
    const byMonth: Record<string, number> = {};
    cancelled.forEach(o => {
      const d = new Date(o.canceled_at ?? o.updated_at);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    });
    return Object.entries(byMonth).sort().slice(-12).map(([month, count]) => ({ month, count }));
  }, [cancelData]);

  const withReasonCount = useMemo(
    () => (cancelData?.orders ?? []).filter(o => o.cancelled_reason).length,
    [cancelData],
  );
  const withoutReasonCount = (cancelData?.orders ?? []).length - withReasonCount;

  // Columns
  const allColumns: Column<CancellationReason>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: r => r.id,
      render: r => <span className="text-xs font-mono text-gray-400">#{r.id}</span>,
    },
    {
      key: "reason_en",
      label: t("cancellationReasons.reasonEn"),
      sortable: true,
      getValue: r => r.reason_en,
      render: r => <span className="text-gray-900">{r.reason_en}</span>,
    },
    {
      key: "reason_ar",
      label: t("cancellationReasons.reasonAr"),
      sortable: true,
      getValue: r => r.reason_ar,
      render: r => <span className="text-gray-700" dir="rtl">{r.reason_ar}</span>,
    },
    {
      key: "role_id",
      label: t("cancellationReasons.roleId"),
      sortable: true,
      getValue: r => r.role_id,
      render: r => (
        <span
          className="text-xs px-2.5 py-1 rounded-full font-medium"
          style={{
            backgroundColor: (ROLE_COLORS[r.role_id] ?? "#6b7280") + "22",
            color: ROLE_COLORS[r.role_id] ?? "#6b7280",
          }}
        >
          {ROLE_LABELS[r.role_id] ?? `Role ${r.role_id}`}
        </span>
      ),
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: r => new Date(r.created_at),
      render: r => (
        <span className="text-xs text-gray-500">
          {new Date(r.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: r => new Date(r.updated_at),
      render: r => (
        <span className="text-xs text-gray-500">
          {new Date(r.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: r => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === r.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button
                onClick={() => deleteMut.mutate(r.id)}
                disabled={deleteMut.isPending}
                className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50"
              >
                {t("common.yes")}
              </button>
              <button
                onClick={() => setDelConfirm(null)}
                className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg"
              >
                {t("common.cancel")}
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => { setEditing(r); setModalOpen(true); }}
                className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"
              >
                <Pencil size={15} />
              </button>
              <button
                onClick={() => setDelConfirm(r.id)}
                className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"
              >
                <Trash2 size={15} />
              </button>
            </>
          )}
        </div>
      ),
    },
  ];

  const columns = allColumns.filter(c => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map(c => ({
    key: c.key,
    label: c.label,
    alwaysVisible: c.key === "actions",
  }));

  const TABS = [
    { key: "reasons" as PageTab, label: t("cancellationReasons.tabReasons"), icon: List },
    { key: "cancelled" as PageTab, label: t("cancellationReasons.tabCancelledOrders"), icon: ShoppingCart },
    { key: "charts" as PageTab, label: t("cancellationReasons.tabCharts"), icon: BarChart2 },
  ];

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <XCircle size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("cancellationReasons.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("cancellationReasons.subtitle")}</p>
        </div>
        <button
          onClick={() => { refetch(); cancelRefetch(); }}
          disabled={isFetching || cancelFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50"
        >
          <RefreshCw size={15} className={(isFetching || cancelFetching) ? "animate-spin" : ""} />
          {t("common.refresh")}
        </button>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-indigo-700">{total}</p>
          <p className="text-xs text-indigo-400 mt-1">{t("cancellationReasons.total")}</p>
        </div>
        <div className="bg-red-50 border border-red-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-red-600">{cancelTotal}</p>
          <p className="text-xs text-red-400 mt-1">{t("cancellationReasons.totalCancelled")}</p>
        </div>
        <div className="bg-green-50 border border-green-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-green-600">{withReasonCount}</p>
          <p className="text-xs text-green-400 mt-1">{t("cancellationReasons.withReason")}</p>
        </div>
        <div className="bg-gray-50 border border-gray-200 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-gray-500">{withoutReasonCount}</p>
          <p className="text-xs text-gray-400 mt-1">{t("cancellationReasons.withoutReason")}</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 gap-1">
        {TABS.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex items-center gap-2 px-5 py-2.5 text-sm font-medium border-b-2 transition ${
              tab === key
                ? "border-indigo-600 text-indigo-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            <Icon size={15} />
            {label}
          </button>
        ))}
      </div>

      {/* ── REASONS TAB ─────────────────────────────────────────────────────── */}
      {tab === "reasons" && (
        <>
          <TableToolbar
            total={displayTotal}
            totalLabel="reason"
            search={search}
            onSearch={v => { setSearch(v); setPage(1); }}
            searchPlaceholder={t("cancellationReasons.searchPlaceholder")}
            action={
              <div className="flex items-center gap-2 flex-wrap">
                {/* Role filter */}
                <select
                  value={roleFilter}
                  onChange={e => { setRoleFilter(e.target.value); setPage(1); }}
                  className="input text-sm py-2 pr-8 min-w-[140px]"
                >
                  <option value="all">{t("cancellationReasons.allRoles")}</option>
                  <option value="1">{t("cancellationReasons.roleCustomer")}</option>
                  <option value="2">{t("cancellationReasons.roleCourier")}</option>
                  <option value="3">{t("cancellationReasons.roleAdmin")}</option>
                </select>
                <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
                <button
                  onClick={() => { setEditing(null); setModalOpen(true); }}
                  className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700"
                >
                  <Plus size={16} /> {t("cancellationReasons.new")}
                </button>
              </div>
            }
          >
            <DateRangeFilter
              label={t("common.createdAt")}
              from={createdFrom}
              to={createdTo}
              onFromChange={v => { setCreatedFrom(v); setPage(1); }}
              onToChange={v => { setCreatedTo(v); setPage(1); }}
            />
            <DateRangeFilter
              label={t("common.updatedAt")}
              from={updatedFrom}
              to={updatedTo}
              onFromChange={v => { setUpdatedFrom(v); setPage(1); }}
              onToChange={v => { setUpdatedTo(v); setPage(1); }}
            />
          </TableToolbar>

          <DataTable
            columns={columns}
            rows={reasons}
            keyExtractor={r => r.id}
            isLoading={isLoading}
            emptyText={t("cancellationReasons.noResults")}
            emptyIcon={<XCircle size={36} className="text-gray-300" />}
          />
          <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={20} onPageChange={setPage} />
        </>
      )}

      {/* ── CANCELLED ORDERS TAB ────────────────────────────────────────────── */}
      {tab === "cancelled" && (
        <div className="space-y-4">
          {/* Filters */}
          <div className="flex flex-wrap gap-3 items-end">
            {/* Search */}
            <div className="flex-1 min-w-[200px]">
              <input
                value={cancelSearch}
                onChange={e => { setCancelSearch(e.target.value); setCancelPage(1); }}
                placeholder={t("cancellationReasons.searchPlaceholder")}
                className="input text-sm w-full"
              />
            </div>
            {/* Customer filter (combobox) */}
            <div className="relative flex-1 min-w-[160px]">
              <input
                list="customer-list"
                value={cancelCustomer}
                onChange={e => setCancelCustomer(e.target.value)}
                placeholder="Filter by Customer…"
                className="input text-sm w-full"
              />
              <datalist id="customer-list">
                {customerNames.map(name => <option key={name} value={name} />)}
              </datalist>
            </div>
            {/* Supplier filter (combobox) */}
            <div className="relative flex-1 min-w-[160px]">
              <input
                list="supplier-list"
                value={cancelSupplier}
                onChange={e => setCancelSupplier(e.target.value)}
                placeholder="Filter by Supplier…"
                className="input text-sm w-full"
              />
              <datalist id="supplier-list">
                {supplierNames.map(name => <option key={name} value={name} />)}
              </datalist>
            </div>
            {/* Courier filter (combobox) */}
            <div className="relative flex-1 min-w-[160px]">
              <input
                list="courier-list"
                value={cancelCourier}
                onChange={e => setCancelCourier(e.target.value)}
                placeholder="Filter by Courier…"
                className="input text-sm w-full"
              />
              <datalist id="courier-list">
                {courierNames.map(name => <option key={name} value={name} />)}
              </datalist>
            </div>
            {/* Date range */}
            <div className="flex gap-2 items-center text-sm text-gray-500">
              <input
                type="date"
                value={cancelFrom}
                onChange={e => setCancelFrom(e.target.value)}
                className="input text-sm py-2"
              />
              <span>–</span>
              <input
                type="date"
                value={cancelTo}
                onChange={e => setCancelTo(e.target.value)}
                className="input text-sm py-2"
              />
            </div>
          </div>

          {/* Table */}
          {cancelLoading ? (
            <div className="space-y-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
              ))}
            </div>
          ) : cancelledOrders.length === 0 ? (
            <div className="text-center py-20 text-gray-400">
              <ShoppingCart size={40} className="mx-auto mb-3 text-gray-300" />
              <p>{t("cancellationReasons.noCancelledOrders")}</p>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("common.id")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("cancellationReasons.customerName")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("cancellationReasons.supplierName")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Courier</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("cancellationReasons.cancelledReason")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("cancellationReasons.cancelledAt")}</th>
                    <th className="px-4 py-3 text-right text-xs font-semibold text-gray-500 uppercase">{t("common.actions")}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {cancelledOrders.map(order => (
                    <CancelledOrderRow key={order.id} order={order} t={t} />
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <TablePagination
            page={cancelPage}
            totalPages={cancelTotalPages}
            total={cancelTotal}
            limit={15}
            onPageChange={setCancelPage}
          />
        </div>
      )}

      {/* ── CHARTS TAB ──────────────────────────────────────────────────────── */}
      {tab === "charts" && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Donut: role distribution */}
            <div className="bg-white rounded-2xl border border-gray-200 p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-700 mb-4">{t("cancellationReasons.chartRoleDistribution")}</h3>
              {roleDistData.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-12">No data</p>
              ) : (
                <ResponsiveContainer width="100%" height={260}>
                  <PieChart>
                    <Pie
                      data={roleDistData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={100}
                      paddingAngle={3}
                      dataKey="value"
                      label={({ name, percent }) => `${name} ${Math.round((percent ?? 0) * 100)}%`}
                      labelLine={false}
                    >
                      {roleDistData.map((_, i) => (
                        <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </div>

            {/* Bar: with/without reason */}
            <div className="bg-white rounded-2xl border border-gray-200 p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-700 mb-4">{t("cancellationReasons.chartTopReasons")}</h3>
              <ResponsiveContainer width="100%" height={260}>
                <BarChart
                  data={[
                    { name: t("cancellationReasons.withReason"), value: withReasonCount, fill: "#6366f1" },
                    { name: t("cancellationReasons.withoutReason"), value: withoutReasonCount, fill: "#e5e7eb" },
                  ]}
                  margin={{ top: 8, right: 16, left: 0, bottom: 8 }}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
                  <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Bar dataKey="value" radius={[6, 6, 0, 0]}>
                    {[{ fill: "#6366f1" }, { fill: "#d1d5db" }].map((entry, i) => (
                      <Cell key={i} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Line: cancellations over time */}
          <div className="bg-white rounded-2xl border border-gray-200 p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-700 mb-4">{t("cancellationReasons.chartCancelledTrend")}</h3>
            {trendData.length < 2 ? (
              <p className="text-sm text-gray-400 text-center py-12">
                Not enough data to show trend
              </p>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <AreaChart data={trendData} margin={{ top: 8, right: 16, left: 0, bottom: 8 }}>
                  <defs>
                    <linearGradient id="cancelGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#6366f1" stopOpacity={0.2} />
                      <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
                  <XAxis dataKey="month" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Area
                    type="monotone"
                    dataKey="count"
                    stroke="#6366f1"
                    strokeWidth={2}
                    fill="url(#cancelGrad)"
                    name={t("cancellationReasons.totalCancelled")}
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      )}

      {/* Modal */}
      {modalOpen && (
        <ReasonModal
          reason={editing}
          onClose={() => { setModalOpen(false); setEditing(null); }}
          onSaved={() => {
            setModalOpen(false);
            setEditing(null);
            qc.invalidateQueries({ queryKey: ["cancellation-reasons"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

// ── Cancelled Order Row ────────────────────────────────────────────────────────
function CancelledOrderRow({ order, t }: { order: Order; t: (k: string) => string }) {
  const customerPhone = order.customer?.phone ?? "";
  const customerName = order.customer?.full_name ?? `#${order.customer?.id ?? "?"}`;
  const supplierName = order.supplier?.user?.full_name ?? "—";
  const courierName = order.courier?.user?.full_name ?? order.courier?.full_name ?? "—";

  return (
    <tr className="hover:bg-gray-50 transition-colors">
      <td className="px-4 py-3 text-xs font-mono text-gray-400">#{order.id}</td>
      <td className="px-4 py-3">
        <div>
          <p className="font-medium text-gray-900 text-sm">{customerName}</p>
          {customerPhone && (
            <p className="text-xs text-gray-400">{customerPhone}</p>
          )}
        </div>
      </td>
      <td className="px-4 py-3 text-sm text-gray-600">{supplierName}</td>
      <td className="px-4 py-3 text-sm text-gray-600">{courierName}</td>
      <td className="px-4 py-3 max-w-[240px]">
        {order.cancelled_reason ? (
          <p className="text-sm text-gray-700 line-clamp-2">{order.cancelled_reason}</p>
        ) : (
          <span className="text-xs text-gray-400 italic">{t("cancellationReasons.noReason")}</span>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-gray-500">
        {order.canceled_at
          ? new Date(order.canceled_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })
          : "—"}
      </td>
      <td className="px-4 py-3">
        <div className="flex items-center justify-end gap-1.5">
          {customerPhone && (
            <a
              href={`tel:${customerPhone}`}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-green-50 text-green-700 hover:bg-green-100 transition"
              title={t("cancellationReasons.callCustomer")}
            >
              <Phone size={13} />
              {t("cancellationReasons.callCustomer")}
            </a>
          )}
          {order.customer?.id && (
            <Link
              href={`/chat?userId=${order.customer.id}`}
              className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition"
              title={t("cancellationReasons.chatCustomer")}
            >
              <MessageSquare size={13} />
              {t("cancellationReasons.chatCustomer")}
            </Link>
          )}
        </div>
      </td>
    </tr>
  );
}

// ── Reason Modal ───────────────────────────────────────────────────────────────
function ReasonModal({
  reason,
  onClose,
  onSaved,
  t,
}: {
  reason: CancellationReason | null;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState({
    reason_en: reason?.reason_en ?? "",
    reason_ar: reason?.reason_ar ?? "",
    role_id: reason?.role_id ?? 1,
  });

  const saveMut = useMutation({
    mutationFn: (d: typeof form) =>
      reason
        ? updateCancellationReason(reason.id, { reason_en: d.reason_en, reason_ar: d.reason_ar })
        : createCancellationReason(d),
    onSuccess: () => {
      toast.success(reason ? t("cancellationReasons.updated") : t("cancellationReasons.created"));
      onSaved();
    },
    onError: () => toast.error("Save failed"),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {reason ? t("common.edit") : t("cancellationReasons.new")}
          </h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>
        <form
          onSubmit={e => { e.preventDefault(); saveMut.mutate(form); }}
          className="px-6 py-5 space-y-4"
        >
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              {t("cancellationReasons.roleId")}
            </label>
            <select
              value={form.role_id}
              onChange={e => setForm(p => ({ ...p, role_id: Number(e.target.value) }))}
              className="input"
              disabled={!!reason}
            >
              <option value={1}>Customer</option>
              <option value={2}>Courier</option>
              <option value={3}>Admin</option>
            </select>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              {t("cancellationReasons.reasonEn")}
            </label>
            <input
              required
              value={form.reason_en}
              onChange={e => setForm(p => ({ ...p, reason_en: e.target.value }))}
              className="input"
            />
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              {t("cancellationReasons.reasonAr")}
            </label>
            <input
              required
              value={form.reason_ar}
              onChange={e => setForm(p => ({ ...p, reason_ar: e.target.value }))}
              dir="rtl"
              className="input text-right"
            />
          </div>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50"
            >
              {t("common.cancel")}
            </button>
            <button
              type="submit"
              disabled={saveMut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
            >
              {saveMut.isPending ? t("common.saving") : reason ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
