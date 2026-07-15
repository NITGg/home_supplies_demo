"use client";
import { useState, useMemo, Fragment, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchOrders, fetchOrderDetail, cancelOrder, fetchOrder, type Order, type OrderStatus } from "@/lib/orders";
import {
  ShoppingCart, RefreshCw, ChevronUp, ChevronDown, ChevronsUpDown,
  X, Truck, CheckCircle2, XCircle, Clock, AlertCircle, Eye, TimerOff,
  Phone, MessageSquare, Package, User, TrendingUp, Loader2,
} from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

type SortField = "order_number" | "status" | "amount" | "created_at";
type SortDir = "asc" | "desc";

const ALL_COLUMN_KEYS = [
  "order_number", "status", "type", "payment_method",
  "customer", "supplier", "courier",
  "amount", "products_total", "courier_fee", "payable_amount",
  "distance_m",
  "pickup_address", "delivery_address",
  "is_scheduled", "is_ready",
  "order_collected_at", "delivered_at", "canceled_at", "offer_accepted_at",
  "proposals_deadline_at", "expires_at",
  "failure_reason", "admin_notes",
  "created_at", "updated_at",
  "actions",
] as const;

const STATUS_STYLES: Record<string, string> = {
  PENDING:     "bg-amber-100 text-amber-700",
  IN_PROGRESS: "bg-blue-100 text-blue-700",
  DELIVERED:   "bg-green-100 text-green-700",
  CANCELLED:   "bg-red-100 text-red-700",
  EXPIRED:     "bg-gray-100 text-gray-600",
  SEARCHING_FAILED: "bg-orange-100 text-orange-700",
};
const STATUS_ICONS: Record<string, React.ElementType> = {
  PENDING:     Clock,
  IN_PROGRESS: Truck,
  DELIVERED:   CheckCircle2,
  CANCELLED:   XCircle,
  EXPIRED:     TimerOff,
  SEARCHING_FAILED: AlertCircle,
};

function fmt(cents?: number | string | null) {
  if (cents == null) return "—";
  const n = Number(cents);
  if (isNaN(n)) return "—";
  return `${(n / 100).toFixed(2)} EGP`;
}
function fmtDate(d?: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc" ? <ChevronUp size={13} className="text-indigo-600" /> : <ChevronDown size={13} className="text-indigo-600" />;
}

export default function OrdersPage() {
  const qc = useQueryClient();
  const { t } = useT();
  const searchParams = useSearchParams();

  const [search,       setSearch]       = useState("");
  const [filterStatus, setFilterStatus] = useState<"" | OrderStatus>("");
  const [page,         setPage]         = useState(1);
  const [pageSize,     setPageSize]     = useState(15);
  const [sortField,    setSortField]    = useState<SortField>("created_at");
  const [sortDir,      setSortDir]      = useState<SortDir>("desc");

  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo,   setCreatedTo]   = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo,   setUpdatedTo]   = useState("");

  const [selectedOrder,  setSelectedOrder]  = useState<Order | null>(null);
  const [showCancel,     setShowCancel]     = useState(false);
  const [cancelReason,   setCancelReason]   = useState("");
  const [cancelFee,      setCancelFee]      = useState("");

  const openOrderId = searchParams.get("open_order_id");
  const idParam = searchParams.get("id");

  useEffect(() => {
    if (openOrderId) {
      fetchOrder(Number(openOrderId))
        .then(order => {
          setSelectedOrder(order);
          const url = new URL(window.location.href);
          url.searchParams.delete("open_order_id");
          window.history.replaceState({}, "", url.pathname + url.search);
        })
        .catch(err => console.error("Failed to auto-open order:", err));
    }
    // Also auto-open if id is present so the row details pop up
    if (idParam) {
      fetchOrder(Number(idParam))
        .then(order => setSelectedOrder(order))
        .catch(err => console.error("Failed to auto-open order by id:", err));
    }
  }, [openOrderId, idParam]);

  // Fetch full order detail (with orderItems) when drawer opens
  const { data: orderDetail, isLoading: detailLoading } = useQuery({
    queryKey: ["order-detail", selectedOrder?.id],
    queryFn: () => fetchOrderDetail(selectedOrder!.id),
    enabled: !!selectedOrder && !showCancel,
    staleTime: 30_000,
  });

  // ── Column visibility ─────────────────────────────────────────────────────
  const { visible, setVisible } = useColumnVisibility(
    "cols:orders",
    // default visible columns
    ["order_number", "status", "type", "customer", "supplier", "courier", "amount", "created_at", "actions"],
    // ALL available column keys — must include every key used in columnOptions/headers/cells
    [...ALL_COLUMN_KEYS],
  );

  const params = useMemo(() => {
    const p: Record<string, string | number> = { page, limit: pageSize };
    if (search)       p.keyword = search;
    if (filterStatus) p.status  = filterStatus;
    if (idParam && !search) p.id = idParam; // Filter by ID if present
    return p;
  }, [page, pageSize, search, filterStatus, idParam]);

  const { data, isLoading, refetch } = useQuery({
    queryKey: ["orders", params],
    queryFn: () => fetchOrders(params),
  });

  const sortedOrders = useMemo(() => {
    const list = [...(data?.orders ?? [])];
    return list.sort((a, b) => {
      let av: string | number, bv: string | number;
      switch (sortField) {
        case "order_number": av = a.order_number; bv = b.order_number; break;
        case "status":       av = a.status;       bv = b.status;       break;
        case "amount":       av = a.actual_price ?? 0; bv = b.actual_price ?? 0; break;
        default:             av = new Date(a.created_at).getTime(); bv = new Date(b.created_at).getTime(); break;
      }
      if (av < bv) return sortDir === "asc" ? -1 : 1;
      if (av > bv) return sortDir === "asc" ?  1 : -1;
      return 0;
    });
  }, [data, sortField, sortDir]);

  // ── Client-side date filtering ────────────────────────────────────────────
  const orders = sortedOrders.filter(r => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && r.updated_at && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && r.updated_at && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });
  

  const totalOrders = data?.totalOrders ?? 0;
  const totalPages  = data?.totalPages  ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? orders.length : totalOrders;

  const statuses: OrderStatus[] = ["PENDING", "IN_PROGRESS", "DELIVERED", "CANCELLED", "EXPIRED", "SEARCHING_FAILED"];
  const counts = useMemo(() => {
    const c: Record<string, number> = {};
    (data?.orders ?? []).forEach(o => { c[o.status] = (c[o.status] ?? 0) + 1; });
    return c;
  }, [data]);

  const cancelMut = useMutation({
    mutationFn: () => cancelOrder(selectedOrder!.id, {
      cancelled_reason: cancelReason,
      ...(cancelFee ? { cancellation_fee: Number(cancelFee) } : {}),
    }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["orders"] });
      toast.success(t("orders.cancelSuccess"));
      setShowCancel(false);
      setCancelReason("");
      setCancelFee("");
      setSelectedOrder(null);
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  function toggleSort(f: SortField) {
    if (sortField === f) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortField(f); setSortDir("asc"); }
  }

  // ── Column toggle options ─────────────────────────────────────────────────
  const columnOptions: ColumnOption[] = [
    { key: "order_number",        label: "Order #" },
    { key: "status",              label: "Status" },
    { key: "type",                label: "Type" },
    { key: "payment_method",      label: "Payment" },
    { key: "customer",            label: "Customer" },
    { key: "supplier",            label: "Supplier" },
    { key: "courier",             label: "Courier" },
    { key: "amount",              label: "Amount (actual)" },
    { key: "products_total",      label: "Products Total" },
    { key: "courier_fee",         label: "Courier Fee" },
    { key: "payable_amount",      label: "Payable Amount" },
    { key: "distance_m",          label: "Distance" },
    { key: "pickup_address",      label: "Pickup Address" },
    { key: "delivery_address",    label: "Delivery Address" },
    { key: "is_scheduled",        label: "Scheduled?" },
    { key: "is_ready",            label: "Ready for Pickup?" },
    { key: "order_collected_at",  label: "Collected At" },
    { key: "delivered_at",        label: "Delivered At" },
    { key: "canceled_at",         label: "Cancelled At" },
    { key: "offer_accepted_at",   label: "Offer Accepted At" },
    { key: "proposals_deadline_at", label: "Proposals Deadline" },
    { key: "expires_at",          label: "Expires At" },
    { key: "failure_reason",      label: "Failure Reason" },
    { key: "admin_notes",         label: "Admin Notes" },
    { key: "created_at",          label: "Created At" },
    { key: "updated_at",          label: "Updated At" },
    { key: "actions",             label: "Actions", alwaysVisible: true },
  ];

  const STAT_CARDS = [
    { label: t("orders.total"),           value: totalOrders,                   color: "bg-indigo-50 text-indigo-700", icon: ShoppingCart },
    { label: t("orders.pending"),         value: counts.PENDING ?? 0,           color: "bg-amber-50 text-amber-700",  icon: Clock },
    { label: t("orders.inProgress"),      value: counts.IN_PROGRESS ?? 0,       color: "bg-blue-50 text-blue-700",    icon: Truck },
    { label: t("orders.delivered"),       value: counts.DELIVERED ?? 0,         color: "bg-green-50 text-green-700",  icon: CheckCircle2 },
    { label: t("orders.cancelled"),       value: counts.CANCELLED ?? 0,         color: "bg-red-50 text-red-700",      icon: XCircle },
    { label: t("orders.expired"),         value: counts.EXPIRED ?? 0,           color: "bg-gray-50 text-gray-600",    icon: TimerOff },
    { label: t("orders.searchingFailed"), value: counts.SEARCHING_FAILED ?? 0,  color: "bg-orange-50 text-orange-700", icon: AlertCircle },
  ];

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t("orders.title")}</h1>
        <p className="text-sm text-gray-500 mt-0.5">{t("orders.subtitle")}</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
        {STAT_CARDS.map(({ label, value, color, icon: Icon }) => (
          <div key={label} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 flex items-center gap-3">
            <div className={cn("w-10 h-10 rounded-xl flex items-center justify-center shrink-0", color.split(" ")[0])}>
              <Icon size={18} className={color.split(" ")[1]} />
            </div>
            <div>
              <p className="text-xs text-gray-500">{label}</p>
              <p className={cn("text-2xl font-bold", color.split(" ")[1])}>{value}</p>
            </div>
          </div>
        ))}
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel={t("orders.title").toLowerCase()}
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("orders.searchPlaceholder")}
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
        <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value as any); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          <option value="">{t("orders.allStatuses")}</option>
          {statuses.map(s => <option key={s} value={s}>{s.replace("_", " ")}</option>)}
        </select>

        <select value={pageSize} onChange={e => { setPageSize(Number(e.target.value)); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none">
          {[10, 15, 25, 50].map(s => <option key={s} value={s}>{s} / page</option>)}
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

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                {visible.includes("order_number") && (
                  <th
                    className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide cursor-pointer hover:text-gray-700"
                    onClick={() => toggleSort("order_number")}>
                    <span className="flex items-center gap-1">
                      {t("orders.orderNumber")}
                      <SortIcon active={sortField === "order_number"} dir={sortDir} />
                    </span>
                  </th>
                )}
                {visible.includes("status") && (
                  <th
                    className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide cursor-pointer hover:text-gray-700"
                    onClick={() => toggleSort("status")}>
                    <span className="flex items-center gap-1">
                      {t("common.status")}
                      <SortIcon active={sortField === "status"} dir={sortDir} />
                    </span>
                  </th>
                )}
                {visible.includes("type") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Type</th>
                )}
                {visible.includes("payment_method") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Payment</th>
                )}
                {visible.includes("customer") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">{t("orders.customer")}</th>
                )}
                {visible.includes("supplier") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Supplier</th>
                )}
                {visible.includes("courier") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">
                    {t("orders.courier")}
                  </th>
                )}
                {visible.includes("amount") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide cursor-pointer hover:text-gray-700 whitespace-nowrap" onClick={() => toggleSort("amount")}>
                    <span className="flex items-center gap-1">Amount <SortIcon active={sortField === "amount"} dir={sortDir} /></span>
                  </th>
                )}
                {visible.includes("products_total") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Products Total</th>
                )}
                {visible.includes("courier_fee") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Courier Fee</th>
                )}
                {visible.includes("payable_amount") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Payable</th>
                )}
                {visible.includes("distance_m") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Distance</th>
                )}
                {visible.includes("pickup_address") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Pickup</th>
                )}
                {visible.includes("delivery_address") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Delivery</th>
                )}
                {visible.includes("is_scheduled") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Scheduled</th>
                )}
                {visible.includes("is_ready") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Ready</th>
                )}
                {visible.includes("order_collected_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Collected At</th>
                )}
                {visible.includes("delivered_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Delivered At</th>
                )}
                {visible.includes("canceled_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Cancelled At</th>
                )}
                {visible.includes("offer_accepted_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Offer Accepted</th>
                )}
                {visible.includes("proposals_deadline_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Proposals Deadline</th>
                )}
                {visible.includes("expires_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Expires At</th>
                )}
                {visible.includes("failure_reason") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Failure Reason</th>
                )}
                {visible.includes("admin_notes") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Admin Notes</th>
                )}
                {visible.includes("created_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide cursor-pointer hover:text-gray-700 whitespace-nowrap" onClick={() => toggleSort("created_at")}>
                    <span className="flex items-center gap-1">Created <SortIcon active={sortField === "created_at"} dir={sortDir} /></span>
                  </th>
                )}
                {visible.includes("updated_at") && (
                  <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Updated At</th>
                )}
                {visible.includes("actions") && (
                  <th className="px-4 py-3 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap">Actions</th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading
                ? Array.from({ length: 6 }).map((_, i) => (
                    <tr key={i}>{Array.from({ length: visible.length }).map((__, j) => (
                      <td key={j} className="px-4 py-3"><div className="h-4 bg-gray-100 rounded animate-pulse" /></td>
                    ))}</tr>
                  ))
                : orders.length === 0
                  ? <tr><td colSpan={visible.length} className="py-16 text-center text-gray-400">
                      <ShoppingCart size={32} className="mx-auto mb-3 text-gray-300" />
                      {t("orders.noResults")}
                    </td></tr>
                  : orders.map(order => {
                      const StatusIcon = STATUS_ICONS[order.status] ?? AlertCircle;
                      return (
                        <Fragment key={order.id}>
                          <tr className="hover:bg-gray-50/50 transition">
                            {visible.includes("order_number") && (
                              <td className="px-4 py-3 font-mono text-xs text-indigo-600 font-semibold">
                                #{order.order_number}
                              </td>
                            )}
                            {visible.includes("status") && (
                              <td className="px-4 py-3">
                                <span className={cn("inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium", STATUS_STYLES[order.status])}>
                                  {/* <StatusIcon size={11} /> */}
                                  {order.status.replace("_", " ")}
                                </span>
                              </td>
                            )}
                            {visible.includes("type") && (
                              <td className="px-4 py-3">
                                {order.type === "CATALOG_PURCHASE"
                                  ? <span className="text-xs px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700 font-medium">Catalog</span>
                                  : order.type === "CUSTOM_PICKUP"
                                    ? <span className="text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 font-medium">Custom</span>
                                    : <span className="text-gray-300 text-xs">—</span>}
                              </td>
                            )}
                            {visible.includes("payment_method") && (
                              <td className="px-4 py-3 text-xs text-gray-600 whitespace-nowrap">
                                {order.payment_method ?? "—"}
                              </td>
                            )}
                            {visible.includes("customer") && (
                              <td className="px-4 py-3">
                                {order.customer
                                  ? <div>
                                      <div className="font-medium text-gray-900">{order.customer.full_name}</div>
                                      <div className="flex items-center gap-2 mt-0.5">
                                        <span className="text-xs text-gray-400">{order.customer.phone}</span>
                                        <a href={`tel:${order.customer.phone}`} className="text-green-600 hover:text-green-700" title="Call customer"><Phone size={12} /></a>
                                        <a href={`/chat?userId=${order.customer.id}&orderId=${order.id}&orderNum=${order.order_number}&orderStatus=${order.status}`} target="_blank" rel="noreferrer" className="text-indigo-500 hover:text-indigo-700" title="Chat with customer"><MessageSquare size={12} /></a>
                                      </div>
                                    </div>
                                  : <span className="text-gray-400">—</span>}
                              </td>
                            )}
                            {visible.includes("supplier") && (
                              <td className="px-4 py-3">
                                {order.supplier?.user
                                  ? <div>
                                      <div className="font-medium text-gray-900 text-sm">{order.supplier.user.full_name}</div>
                                      <div className="text-xs text-gray-400">{order.supplier.user.phone}</div>
                                    </div>
                                  : <span className="text-gray-300 text-xs">—</span>}
                              </td>
                            )}
                            {visible.includes("courier") && (
                              <td className="px-4 py-3">
                                {order.courier
                                  ? <div>
                                      <div className="font-medium text-gray-900">{order.courier.user?.full_name ?? order.courier.full_name}</div>
                                      <div className="flex items-center gap-2 mt-0.5">
                                        <span className="text-xs text-gray-400">{order.courier.user?.phone ?? order.courier.phone}</span>
                                        {(order.courier.user?.phone ?? order.courier.phone) && (
                                          <a href={`tel:${order.courier.user?.phone ?? order.courier.phone}`} className="text-green-600 hover:text-green-700" title="Call courier"><Phone size={12} /></a>
                                        )}
                                        <a href={`/chat?userId=${order.courier.user?.id ?? order.courier.id}&orderId=${order.id}&orderNum=${order.order_number}&orderStatus=${order.status}`} target="_blank" rel="noreferrer" className="text-indigo-500 hover:text-indigo-700" title="Chat with courier"><MessageSquare size={12} /></a>
                                      </div>
                                    </div>
                                  : <span className="text-gray-400 text-xs">Unassigned</span>}
                              </td>
                            )}
                            {visible.includes("amount") && (
                              <td className="px-4 py-3 text-gray-700 font-medium whitespace-nowrap">
                                {fmt(order.actual_price)}
                              </td>
                            )}
                            {visible.includes("products_total") && (
                              <td className="px-4 py-3 text-gray-700 whitespace-nowrap">{fmt(order.products_total)}</td>
                            )}
                            {visible.includes("courier_fee") && (
                              <td className="px-4 py-3 text-gray-700 whitespace-nowrap">{fmt(order.courier_fee)}</td>
                            )}
                            {visible.includes("payable_amount") && (
                              <td className="px-4 py-3 text-gray-700 font-semibold whitespace-nowrap">{fmt(order.payable_amount)}</td>
                            )}
                            {visible.includes("distance_m") && (
                              <td className="px-4 py-3 text-gray-600 text-xs whitespace-nowrap">
                                {order.distance_m != null ? `${(Number(order.distance_m) / 1000).toFixed(2)} km` : "—"}
                              </td>
                            )}
                            {visible.includes("pickup_address") && (
                              <td className="px-4 py-3 text-gray-600 text-xs max-w-[160px] truncate" title={order.pickup_address_description ?? ""}>
                                {order.pickup_address_description ?? "—"}
                              </td>
                            )}
                            {visible.includes("delivery_address") && (
                              <td className="px-4 py-3 text-gray-600 text-xs max-w-[160px] truncate" title={order.delivery_address_description ?? ""}>
                                {order.delivery_address_description ?? "—"}
                              </td>
                            )}
                            {visible.includes("is_scheduled") && (
                              <td className="px-4 py-3">
                                {order.is_scheduled
                                  ? <span className="text-xs px-2 py-0.5 rounded-full bg-purple-50 text-purple-700">Yes</span>
                                  : <span className="text-xs text-gray-300">No</span>}
                              </td>
                            )}
                            {visible.includes("is_ready") && (
                              <td className="px-4 py-3">
                                {order.is_ready_for_pickup
                                  ? <span className="text-xs px-2 py-0.5 rounded-full bg-cyan-50 text-cyan-700">Ready</span>
                                  : <span className="text-xs text-gray-300">—</span>}
                              </td>
                            )}
                            {visible.includes("order_collected_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.order_collected_at)}</td>
                            )}
                            {visible.includes("delivered_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.delivered_at)}</td>
                            )}
                            {visible.includes("canceled_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.canceled_at)}</td>
                            )}
                            {visible.includes("offer_accepted_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.offer_accepted_at)}</td>
                            )}
                            {visible.includes("proposals_deadline_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.proposals_deadline_at)}</td>
                            )}
                            {visible.includes("expires_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.expires_at)}</td>
                            )}
                            {visible.includes("failure_reason") && (
                              <td className="px-4 py-3 text-xs text-red-500 max-w-[140px] truncate" title={order.failure_reason ?? ""}>
                                {order.failure_reason ?? "—"}
                              </td>
                            )}
                            {visible.includes("admin_notes") && (
                              <td className="px-4 py-3 text-xs text-gray-600 max-w-[180px] truncate" title={order.admin_notes ?? ""}>
                                {order.admin_notes ?? "—"}
                              </td>
                            )}
                            {visible.includes("created_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                                {fmtDate(order.created_at)}
                              </td>
                            )}
                            {visible.includes("updated_at") && (
                              <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">{fmtDate(order.updated_at)}</td>
                            )}
                            {visible.includes("actions") && (
                              <td className="px-4 py-3">
                                <div className="flex items-center justify-end gap-1">
                                  <button onClick={() => { setSelectedOrder(order); setShowCancel(false); }}
                                    className="p-1.5 hover:bg-indigo-50 text-indigo-500 rounded-lg transition" title={t("orders.viewDetails")}>
                                    <Eye size={15} />
                                  </button>
                                  {order.status !== "CANCELLED" && order.status !== "DELIVERED" && (
                                    <button onClick={() => { setSelectedOrder(order); setShowCancel(true); }}
                                      className="p-1.5 hover:bg-red-50 text-red-400 rounded-lg transition" title={t("orders.cancelOrder")}>
                                      <XCircle size={15} />
                                    </button>
                                  )}
                                </div>
                              </td>
                            )}
                          </tr>
                        </Fragment>
                      );
                    })}
            </tbody>
          </table>
        </div>

      </div>

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={pageSize} onPageChange={setPage} />

      {/* Order Detail / Cancel Drawer */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 flex">
          <div className="flex-1 bg-black/40" onClick={() => setSelectedOrder(null)} />
          <div className="w-full max-w-3xl bg-white h-full overflow-y-auto shadow-2xl flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b">
              <div>
                <h2 className="text-lg font-bold text-gray-900">
                  {showCancel ? t("orders.cancelOrder") : t("orders.details")}
                </h2>
                <p className="text-xs text-gray-400 font-mono mt-0.5">#{selectedOrder.order_number}</p>
              </div>
              <button onClick={() => setSelectedOrder(null)} className="p-2 hover:bg-gray-100 rounded-lg">
                <X size={18} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-6 py-5 space-y-5">
              {!showCancel ? (
                <>
                  {/* Status + cancel button */}
                  <div className="flex items-center gap-3">
                    <span className={cn("inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium", STATUS_STYLES[selectedOrder.status])}>
                      {(() => { const Icon = STATUS_ICONS[selectedOrder.status] ?? AlertCircle; return <Icon size={14} />; })()}
                      {selectedOrder.status.replace("_", " ")}
                    </span>
                    {selectedOrder.status !== "CANCELLED" && selectedOrder.status !== "DELIVERED" && (
                      <button onClick={() => setShowCancel(true)}
                        className="text-xs text-red-500 border border-red-200 px-3 py-1.5 rounded-lg hover:bg-red-50 transition">
                        {t("orders.cancelOrder")}
                      </button>
                    )}
                  </div>

                  {/* Participants: Customer / Supplier / Courier */}
                  <div className="grid grid-cols-3 gap-3 text-xs">
                    <div className="bg-indigo-50 border border-indigo-100 rounded-xl p-3">
                      <p className="text-indigo-400 font-bold uppercase tracking-wide text-[9px] mb-1.5 flex items-center gap-1"><User size={10} /> Customer</p>
                      {selectedOrder.customer ? (
                        <>
                          <p className="font-semibold text-gray-900 truncate">{selectedOrder.customer.full_name}</p>
                          <p className="text-gray-500 mt-0.5">{selectedOrder.customer.phone}</p>
                          {selectedOrder.customer.email && <p className="text-gray-400 truncate">{selectedOrder.customer.email}</p>}
                        </>
                      ) : <p className="text-gray-400">—</p>}
                    </div>
                    <div className="bg-gray-50 rounded-xl p-3 border border-gray-100">
                      <p className="text-gray-400 font-bold uppercase tracking-wide text-[9px] mb-1.5">Supplier</p>
                      <p className="font-semibold text-gray-800 truncate">{selectedOrder.supplier?.user?.full_name ?? "—"}</p>
                      <p className="text-gray-500 mt-0.5">{selectedOrder.supplier?.user?.phone ?? ""}</p>
                    </div>
                    <div className="bg-gray-50 rounded-xl p-3 border border-gray-100">
                      <p className="text-gray-400 font-bold uppercase tracking-wide text-[9px] mb-1.5">Courier</p>
                      <p className="font-semibold text-gray-800 truncate">{selectedOrder.courier?.user?.full_name ?? selectedOrder.courier?.full_name ?? "Unassigned"}</p>
                      <p className="text-gray-500 mt-0.5">{selectedOrder.courier?.user?.phone ?? selectedOrder.courier?.phone ?? ""}</p>
                    </div>
                  </div>

                  {/* Order items */}
                  <div className="space-y-2">
                    <p className="text-xs font-bold text-gray-500 uppercase tracking-wide flex items-center gap-1"><Package size={12} /> Order Items</p>
                    {detailLoading ? (
                      <div className="flex items-center justify-center py-6">
                        <Loader2 size={20} className="animate-spin text-indigo-400" />
                      </div>
                    ) : (orderDetail?.orderItems ?? []).length === 0 ? (
                      <p className="text-xs text-gray-400 py-3 text-center">No items</p>
                    ) : (
                      <div className="border border-gray-100 rounded-xl overflow-hidden">
                        <table className="w-full text-xs">
                          <thead className="bg-gray-50 border-b border-gray-100">
                            <tr>
                              <th className="text-left px-3 py-2 text-gray-500 font-semibold">Product</th>
                              <th className="text-center px-2 py-2 text-gray-500 font-semibold">Qty</th>
                              <th className="text-right px-2 py-2 text-gray-500 font-semibold">Cost/u</th>
                              <th className="text-right px-2 py-2 text-gray-500 font-semibold">Sell/u</th>
                              <th className="text-right px-3 py-2 text-gray-500 font-semibold">Total</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-gray-50">
                            {(orderDetail?.orderItems ?? []).map((item: any, idx: number) => {
                              const prod = item.product ?? item.supplierProduct?.product;
                              const name = prod?.name ?? `Item #${item.id}`;
                              const costSubtotal = Number(item.cost_price ?? 0) * Number(item.quantity ?? 1);
                              const sellSubtotal = Number(item.unit_price ?? 0) * Number(item.quantity ?? 1);
                              return (
                                <tr key={item.id ?? idx} className="bg-white">
                                  <td className="px-3 py-2 font-medium text-gray-800 max-w-[200px] truncate" title={name}>{name}</td>
                                  <td className="px-2 py-2 text-center text-gray-600">{item.quantity}</td>
                                  <td className="px-2 py-2 text-right text-indigo-600 font-mono">{fmt(item.cost_price)}</td>
                                  <td className="px-2 py-2 text-right text-green-600 font-mono">{fmt(item.unit_price)}</td>
                                  <td className="px-3 py-2 text-right text-gray-800 font-semibold font-mono">{fmt(sellSubtotal)}</td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>

                  {/* Financial breakdown — Who gets what */}
                  <div className="space-y-2">
                    <p className="text-xs font-bold text-gray-500 uppercase tracking-wide flex items-center gap-1">
                      <TrendingUp size={12} /> Financial Breakdown
                    </p>

                    {/* 3 share cards */}
                    <div className="grid grid-cols-3 gap-2 text-xs">
                      <div className="bg-indigo-50 border border-indigo-100 rounded-xl p-3 text-center">
                        <p className="text-indigo-400 font-bold uppercase tracking-wide text-[9px] mb-1">Supplier</p>
                        <p className="text-indigo-700 font-bold text-sm font-mono">
                          {fmt(orderDetail?.total_cost_price ?? selectedOrder.total_cost_price)}
                        </p>
                        <p className="text-indigo-300 text-[9px] mt-0.5">Products cost</p>
                      </div>
                      <div className="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">
                        <p className="text-amber-500 font-bold uppercase tracking-wide text-[9px] mb-1">Courier</p>
                        <p className="text-amber-700 font-bold text-sm font-mono">
                          {fmt(selectedOrder.courier_fee)}
                        </p>
                        <p className="text-amber-300 text-[9px] mt-0.5">Delivery fee</p>
                      </div>
                      <div className="bg-green-50 border border-green-100 rounded-xl p-3 text-center">
                        <p className="text-green-500 font-bold uppercase tracking-wide text-[9px] mb-1">Platform</p>
                        <p className="text-green-700 font-bold text-sm font-mono">
                          {fmt(selectedOrder.platform_fee)}
                        </p>
                        <p className="text-green-300 text-[9px] mt-0.5">Commission</p>
                      </div>
                    </div>

                    {/* Detailed breakdown */}
                    <div className="bg-gray-50 border border-gray-100 rounded-xl px-4 py-3 space-y-1.5 text-sm">
                      <Row label="Products (selling)" value={fmt(selectedOrder.products_total)} color="text-green-700" />
                      <Row label="Products (cost)" value={fmt(orderDetail?.total_cost_price ?? selectedOrder.total_cost_price)} color="text-indigo-600" />
                      <Row
                        label="Product Markup"
                        value={fmt(
                          Number(selectedOrder.products_total ?? 0) -
                          Number(orderDetail?.total_cost_price ?? selectedOrder.total_cost_price ?? 0)
                        )}
                        color="text-orange-600"
                      />
                      <div className="border-t border-gray-200 pt-1.5 mt-1.5 space-y-1.5">
                        <Row label="Courier Fee" value={fmt(selectedOrder.courier_fee)} color="text-amber-700" />
                        <Row label="Platform Commission" value={fmt(selectedOrder.platform_fee)} color="text-green-700" />
                        {selectedOrder.vat_amount != null && <Row label="VAT" value={fmt(selectedOrder.vat_amount)} />}
                        {selectedOrder.discount_amount != null && (
                          <Row label="Discount" value={`-${fmt(selectedOrder.discount_amount)}`} color="text-red-500" />
                        )}
                      </div>
                    </div>

                    {/* Customer pays */}
                    <div className="bg-gray-900 text-white rounded-xl px-4 py-3 flex justify-between items-center">
                      <span className="text-sm font-medium text-gray-300">Customer Pays</span>
                      <span className="font-bold font-mono text-white text-base">
                        {fmt(selectedOrder.payable_amount ?? selectedOrder.actual_price)}
                      </span>
                    </div>
                  </div>

                  {/* Dates */}
                  <div className="text-xs space-y-1 text-gray-500">
                    <div className="flex justify-between"><span>Created</span><span>{fmtDate(selectedOrder.created_at)}</span></div>
                    {selectedOrder.delivered_at && <div className="flex justify-between"><span>Delivered</span><span>{fmtDate(selectedOrder.delivered_at)}</span></div>}
                    {selectedOrder.canceled_at && <div className="flex justify-between text-red-500"><span>Cancelled</span><span>{fmtDate(selectedOrder.canceled_at)}</span></div>}
                    {selectedOrder.cancelled_reason && <div className="flex justify-between"><span>Reason</span><span className="text-right max-w-[60%]">{selectedOrder.cancelled_reason}</span></div>}
                  </div>
                </>
              ) : (
                <>
                  <div className="bg-red-50 border border-red-100 rounded-xl p-4 text-sm text-red-700">
                    <AlertCircle size={16} className="inline mr-2" />
                    {t("orders.cancelOrder")}: #{selectedOrder.order_number}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1.5">{t("orders.cancelReason")}</label>
                    <textarea value={cancelReason} onChange={e => setCancelReason(e.target.value)}
                      rows={3} placeholder="Explain why this order is being cancelled…"
                      className="w-full border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1.5">{t("orders.cancelFee")}</label>
                    <input type="number" min="0" step="0.001" value={cancelFee} onChange={e => setCancelFee(e.target.value)}
                      placeholder="0.000"
                      className="w-full border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none" />
                  </div>

                  <div className="flex gap-3">
                    <button onClick={() => setShowCancel(false)}
                      className="flex-1 border border-gray-300 rounded-xl py-2.5 text-sm font-medium hover:bg-gray-50">
                      {t("common.cancel")}
                    </button>
                    <button
                      onClick={() => cancelMut.mutate()}
                      disabled={!cancelReason.trim() || cancelMut.isPending}
                      className="flex-1 bg-red-600 hover:bg-red-700 text-white rounded-xl py-2.5 text-sm font-medium disabled:opacity-60">
                      {cancelMut.isPending ? t("common.saving") : t("orders.confirmCancel")}
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Row({ label, value, color = "text-gray-800" }: { label: string; value: string; color?: string }) {
  return (
    <div className="flex justify-between items-center">
      <span className="text-gray-500">{label}</span>
      <span className={cn("font-mono font-semibold", color)}>{value}</span>
    </div>
  );
}
