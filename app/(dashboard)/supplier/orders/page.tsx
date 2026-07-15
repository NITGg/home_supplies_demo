"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { supplierApi } from "@/lib/api";
import toast from "react-hot-toast";
import {
  ShoppingCart,
  RefreshCw,
  Search,
  ChevronLeft,
  ChevronRight,
  ArrowUp,
  ArrowDown,
  ArrowUpDown,
  Calendar,
  Filter,
  Truck,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { ColumnToggle } from "@/components/ui/ColumnToggle";
import { useT } from "@/contexts/LanguageContext";

// Matches the DB OrderStatus enum exactly
const ORDER_STATUSES = [
  "PENDING",
  "SEARCHING_FAILED",
  "IN_PROGRESS",
  "DELIVERED",
  "CANCELLED",
  "EXPIRED",
  "SCHEDULED",
] as const;

const STATUS_STYLES: Record<string, string> = {
  PENDING:          "bg-amber-100 text-amber-700",
  SEARCHING_FAILED: "bg-orange-100 text-orange-700",
  IN_PROGRESS:      "bg-blue-100 text-blue-700",
  DELIVERED:        "bg-green-100 text-green-700",
  CANCELLED:        "bg-red-100 text-red-700",
  EXPIRED:          "bg-gray-100 text-gray-500",
  SCHEDULED:        "bg-purple-100 text-purple-700",
};

const STATUS_LABELS_AR: Record<string, string> = {
  PENDING:          "قيد الانتظار",
  SEARCHING_FAILED: "فشل البحث",
  IN_PROGRESS:      "جارٍ التنفيذ",
  DELIVERED:        "تم التسليم",
  CANCELLED:        "ملغي",
  EXPIRED:          "منتهي",
  SCHEDULED:        "مجدول",
};

const ALL_SUPPLIER_ORDER_COLS = [
  "order_number",
  "status",
  "type",
  "products_total",
  "total_cost_price",
  "courier_fee",
  "payable_amount",
  "payment_method",
  "is_ready_for_pickup",
  "is_scheduled",
  "order_schedule_at",
  "proposed_at",
  "offer_accepted_at",
  "order_collected_at",
  "delivered_at",
  "canceled_at",
  "pickup_address",
  "delivery_address",
  "created_at",
  "updated_at",
  "actions",
] as const;

function fmt(n: number | string | null | undefined) {
  if (n == null) return "—";
  const num = Number(n);
  if (isNaN(num)) return "—";
  return `${(num / 100).toFixed(2)} EGP`;
}

function fmtDate(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-GB", {
    dateStyle: "short",
    timeStyle: "short",
  });
}

export default function SupplierOrdersPage() {
  const { t, lang, isRTL } = useT();
  const router = useRouter();
  const qc = useQueryClient();

  const [notifiedIds, setNotifiedIds] = useState<Set<number>>(new Set());

  // App settings — min notice (minutes) before order_schedule_at when supplier may request couriers
  const { data: appSettings } = useQuery({
    queryKey: ["app-settings"],
    queryFn: async () => {
      const res = await supplierApi.get("/order/app-settings");
      return res.data?.data?.ApplicationSettings ?? res.data?.data ?? res.data;
    },
    staleTime: 5 * 60_000,
  });
  const minNoticeMinutes = Number(appSettings?.order_scheduled_min_notice_minutes_from_supplier ?? 0);

  // Tick every 30s so button eligibility re-evaluates against the current time
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(t);
  }, []);

  // Supplier may request couriers from (order_schedule_at - minNotice) onwards.
  const canRequestCourier = (scheduleAt: string | null | undefined) => {
    if (!scheduleAt) return true; // non-scheduled orders are always eligible
    const earliest = new Date(scheduleAt).getTime() - minNoticeMinutes * 60_000;
    return now >= earliest;
  };

  const notifyMutation = useMutation({
    mutationFn: async (orderId: number) => {
      const res = await supplierApi.post(`/order/notify-order-ready/${orderId}`);
      return res.data;
    },
    onSuccess: (_, orderId) => {
      toast.success(lang === "AR" ? "تم إرسال الطلب للبحث عن مندوب!" : "Searching for a courier started!");
      setNotifiedIds(prev => new Set(prev).add(orderId));
      qc.invalidateQueries({ queryKey: ["supplier-orders"] });
    },
    onError: (err: any) => {
      toast.error(err?.response?.data?.message || (lang === "AR" ? "حدث خطأ" : "Something went wrong"));
    },
  });
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [status, setStatus] = useState("");
  const [paymentMethod, setPaymentMethod] = useState("");
  const [sortBy, setSortBy] = useState<string | null>("created_at");
  const [sortOrder, setSortOrder] = useState<"asc" | "desc" | null>("desc");
  const [showDateFilters, setShowDateFilters] = useState(false);
  const [dateFilters, setDateFilters] = useState({
    created_at: { gte: "", lte: "" },
    updated_at: { gte: "", lte: "" },
    proposed_at: { gte: "", lte: "" },
    offer_accepted_at: { gte: "", lte: "" },
    order_collected_at: { gte: "", lte: "" },
    delivered_at: { gte: "", lte: "" },
    canceled_at: { gte: "", lte: "" },
  });
  const limit = 20;

  // Debounce search input — wait 350ms after last keystroke before querying
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search), 350);
    return () => clearTimeout(timer);
  }, [search]);

  const { visible, setVisible } = useColumnVisibility(
    "cols:supplier-orders",
    ["order_number", "status", "products_total", "total_cost_price", "courier_fee", "created_at", "actions"],
    [...ALL_SUPPLIER_ORDER_COLS],
  );

  const formatApiDate = (dateStr: string) => {
    return dateStr || undefined; // YYYY-MM-DD format as expected by API
  };

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: [
      "supplier-orders",
      page,
      debouncedSearch,
      status,
      paymentMethod,
      dateFilters,
      sortBy,
      sortOrder,
    ],
    queryFn: async () => {
      const params: Record<string, any> = { limit, skip: (page - 1) * limit };
      if (debouncedSearch) {
        params.keyword = debouncedSearch;
        params.items = "order_number,product_description,customer.full_name";
      }
      if (status) params.status = status;
      if (paymentMethod) params.payment_method = paymentMethod;

      // Date filters
      Object.entries(dateFilters).forEach(([field, bounds]) => {
        if (bounds.gte) {
          params[`${field}[gte]`] = formatApiDate(bounds.gte);
        }
        if (bounds.lte) {
          params[`${field}[lte]`] = formatApiDate(bounds.lte);
        }
      });

      // Sorting
      if (sortBy && sortOrder) {
        params.sort = sortOrder === "desc" ? `-${sortBy}` : sortBy;
      }

      const res = await supplierApi.get("/order/list-orders", { params });
      return res.data?.data ?? res.data;
    },
    staleTime: 10_000,
  });

  const orders: any[] = data?.orders ?? data ?? [];
  const total = data?.totalOrders ?? data?.total ?? orders.length;
  const totalPages = Math.ceil(total / limit);

  const statusLabel = (s: string) =>
    lang === "AR"
      ? (STATUS_LABELS_AR[s] ?? s.replace(/_/g, " "))
      : s.replace(/_/g, " ");

  const colLabels: Record<string, string> = {
    order_number:      lang === "AR" ? "رقم الطلب"        : "Order #",
    status:            lang === "AR" ? "الحالة"            : "Status",
    type:              lang === "AR" ? "النوع"             : "Type",
    products_total:    lang === "AR" ? "سعر الأوردر"      : "Order Price",
    total_cost_price:  lang === "AR" ? "سعر المورد"       : "Supplier Cost",
    courier_fee:       lang === "AR" ? "سعر الشحن"        : "Shipping Fee",
    payable_amount:    lang === "AR" ? "المبلغ المدفوع"   : "Payable",
    payment_method:    lang === "AR" ? "طريقة الدفع"      : "Payment",
    is_ready_for_pickup: lang === "AR" ? "جاهز للاستلام"  : "Ready",
    is_scheduled:      lang === "AR" ? "مجدول"             : "Scheduled",
    order_schedule_at: lang === "AR" ? "موعد الجدولة"      : "Scheduled At",
    proposed_at:       lang === "AR" ? "تاريخ العرض"      : "Proposed At",
    offer_accepted_at: lang === "AR" ? "قبول العرض"       : "Offer Accepted",
    order_collected_at:lang === "AR" ? "تاريخ الاستلام"   : "Collected At",
    delivered_at:      lang === "AR" ? "تاريخ التسليم"    : "Delivered At",
    canceled_at:       lang === "AR" ? "تاريخ الإلغاء"   : "Cancelled At",
    pickup_address:    lang === "AR" ? "عنوان الاستلام"   : "Pickup",
    delivery_address:  lang === "AR" ? "عنوان التوصيل"   : "Delivery",
    created_at:        lang === "AR" ? "تاريخ الإنشاء"    : "Created",
    updated_at:        lang === "AR" ? "آخر تحديث"        : "Updated",
    actions:           lang === "AR" ? "إجراءات"           : "Actions",
  };

  const toggleSort = (field: string) => {
    if (sortBy === field) {
      if (sortOrder === "asc") {
        setSortOrder("desc");
      } else if (sortOrder === "desc") {
        setSortBy(null);
        setSortOrder(null);
      }
    } else {
      setSortBy(field);
      setSortOrder("asc");
    }
    setPage(1);
  };

  const handleDateChange = (
    field: string,
    bound: "gte" | "lte",
    value: string,
  ) => {
    setDateFilters((prev) => ({
      ...prev,
      [field]: {
        ...prev[field as keyof typeof dateFilters],
        [bound]: value,
      },
    }));
    setPage(1);
  };

  const clearDateFilters = () => {
    setDateFilters({
      created_at: { gte: "", lte: "" },
      updated_at: { gte: "", lte: "" },
      proposed_at: { gte: "", lte: "" },
      offer_accepted_at: { gte: "", lte: "" },
      order_collected_at: { gte: "", lte: "" },
      delivered_at: { gte: "", lte: "" },
      canceled_at: { gte: "", lte: "" },
    });
    setPage(1);
  };

  const clearAllFilters = () => {
    setSearch("");
    setDebouncedSearch("");
    setStatus("");
    setPaymentMethod("");
    clearDateFilters();
    setSortBy(null);
    setSortOrder(null);
    setPage(1);
  };

  const hasActiveFilters =
    !!search ||
    !!status ||
    !!paymentMethod ||
    Object.values(dateFilters).some((bounds) => bounds.gte || bounds.lte) ||
    sortBy !== null;

  const dateFieldsConfig = [
    { key: "created_at", label: colLabels.created_at || "Created At" },
    { key: "updated_at", label: colLabels.updated_at || "Updated At" },
    { key: "proposed_at", label: colLabels.proposed_at || "Proposed At" },
    {
      key: "offer_accepted_at",
      label: colLabels.offer_accepted_at || "Offer Accepted At",
    },
    {
      key: "order_collected_at",
      label: colLabels.order_collected_at || "Collected At",
    },
    { key: "delivered_at", label: colLabels.delivered_at || "Delivered At" },
    { key: "canceled_at", label: colLabels.canceled_at || "Cancelled At" },
  ] as const;

  const renderHeader = (colKey: string, label: string) => {
    const isSorted = sortBy === colKey;
    return (
      <th
        onClick={() => toggleSort(colKey)}
        className={cn(
          "px-4 py-3 text-xs font-semibold text-gray-500 uppercase whitespace-nowrap cursor-pointer select-none hover:bg-gray-100 transition duration-150 group",
          isRTL ? "text-right" : "text-left",
        )}
      >
        <div className="flex items-center gap-1">
          <span>{label}</span>
          <span className="inline-flex">
            {isSorted && sortOrder ? (
              sortOrder === "asc" ? (
                <ArrowUp
                  size={12}
                  className="text-indigo-600 animate-fade-in"
                />
              ) : (
                <ArrowDown
                  size={12}
                  className="text-indigo-600 animate-fade-in"
                />
              )
            ) : (
              <ArrowUpDown
                size={12}
                className="text-gray-300 opacity-0 group-hover:opacity-100 transition-opacity duration-150"
              />
            )}
          </span>
        </div>
      </th>
    );
  };

  return (
    <div className="p-6 space-y-5" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <ShoppingCart size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">
              {t("sp.orders.title")}
            </h1>
            <p className="text-xs text-gray-500">
              {total} {t("sp.orders.total")}
            </p>
          </div>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50"
        >
          <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Filters + column toggle */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative">
          <Search
            size={14}
            className={cn(
              "absolute top-1/2 -translate-y-1/2 text-gray-400",
              isRTL ? "right-3" : "left-3",
            )}
          />
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder={t("sp.orders.searchPlaceholder")}
            className={cn(
              "py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 w-52",
              isRTL ? "pr-9 pl-4 text-right" : "pl-9 pr-4",
            )}
          />
          {isFetching && (
            <RefreshCw
              size={10}
              className={cn(
                "absolute top-1/2 -translate-y-1/2 text-indigo-400 animate-spin",
                isRTL ? "left-3" : "right-3",
              )}
            />
          )}
        </div>
        <select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          className="border border-gray-200 rounded-lg text-sm px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-500"
        >
          <option value="">{t("sp.orders.allStatuses")}</option>
          {ORDER_STATUSES.map((s) => (
            <option key={s} value={s}>
              {statusLabel(s)}
            </option>
          ))}
        </select>

        {/* Payment Method Filter */}
        <select
          value={paymentMethod}
          onChange={(e) => {
            setPaymentMethod(e.target.value);
            setPage(1);
          }}
          className="border border-gray-200 rounded-lg text-sm px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-500 bg-white"
        >
          <option value="">
            {lang === "AR" ? "كل طرق الدفع" : "All Payment Methods"}
          </option>
          <option value="WALLET">{lang === "AR" ? "محفظة" : "Wallet"}</option>
          <option value="CASH">{lang === "AR" ? "نقداً" : "Cash"}</option>
        </select>

        {/* Date Filters Toggle */}
        <button
          onClick={() => setShowDateFilters(!showDateFilters)}
          className={cn(
            "flex items-center gap-2 border text-sm px-3 py-2 rounded-lg transition duration-200",
            showDateFilters
              ? "border-indigo-600 bg-indigo-50 text-indigo-700 font-semibold"
              : "border-gray-200 bg-white text-gray-700 hover:bg-gray-50",
          )}
        >
          <Calendar size={14} />
          <span>{lang === "AR" ? "فلترة التواريخ" : "Date Filters"}</span>
          {Object.values(dateFilters).some(
            (bounds) => bounds.gte || bounds.lte,
          ) && (
            <span className="w-2 h-2 rounded-full bg-indigo-600 animate-pulse" />
          )}
        </button>

        {/* Clear Applied Filters Button */}
        {hasActiveFilters && (
          <button
            onClick={clearAllFilters}
            className="flex items-center gap-1.5 border border-red-200 bg-red-50 text-red-700 hover:bg-red-100 text-sm px-3 py-2 rounded-lg transition duration-200"
          >
            <Filter size={14} className="text-red-500" />
            <span>{lang === "AR" ? "مسح التصفية" : "Clear Filters"}</span>
          </button>
        )}

        <div className={isRTL ? "mr-auto" : "ml-auto"}>
          <ColumnToggle
            columns={ALL_SUPPLIER_ORDER_COLS.map((key) => ({
              key,
              label: colLabels[key],
            }))}
            visible={visible}
            onChange={setVisible}
          />
        </div>
      </div>

      {/* Collapsible Date Filters Panel */}
      {showDateFilters && (
        <div className="bg-slate-50/50 backdrop-blur-sm border border-indigo-100 rounded-xl p-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 animate-fade-in">
          {dateFieldsConfig.map(({ key, label }) => {
            const currentFilter = dateFilters[
              key as keyof typeof dateFilters
            ] || { gte: "", lte: "" };
            return (
              <div
                key={key}
                className="space-y-1.5 bg-white p-3 rounded-lg border border-gray-100 shadow-sm transition hover:shadow-md"
              >
                <span className="text-xs font-semibold text-gray-700">
                  {label}
                </span>
                <div className="flex items-center gap-2">
                  <div className="flex-1 space-y-0.5">
                    <span className="text-[10px] text-gray-400 block">
                      {lang === "AR" ? "من" : "From"}
                    </span>
                    <input
                      type="date"
                      value={currentFilter.gte}
                      onChange={(e) =>
                        handleDateChange(key, "gte", e.target.value)
                      }
                      className="w-full border border-gray-200 rounded-md text-xs px-2 py-1 outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="flex-1 space-y-0.5">
                    <span className="text-[10px] text-gray-400 block">
                      {lang === "AR" ? "إلى" : "To"}
                    </span>
                    <input
                      type="date"
                      value={currentFilter.lte}
                      onChange={(e) =>
                        handleDateChange(key, "lte", e.target.value)
                      }
                      className="w-full border border-gray-200 rounded-md text-xs px-2 py-1 outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                </div>
              </div>
            );
          })}
          <div className="flex items-end justify-end md:col-span-2 lg:col-span-3 xl:col-span-4 mt-2">
            <button
              onClick={clearDateFilters}
              disabled={
                !Object.values(dateFilters).some(
                  (bounds) => bounds.gte || bounds.lte,
                )
              }
              className="text-xs font-semibold text-red-600 hover:text-red-700 disabled:opacity-40 flex items-center gap-1 px-3 py-1.5 rounded-md hover:bg-red-50 transition duration-150"
            >
              <Filter size={12} />
              {lang === "AR" ? "إعادة تعيين التواريخ" : "Reset Date Filters"}
            </button>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-x-auto">
        {isLoading ? (
          <div className="flex items-center justify-center py-16">
            <RefreshCw size={24} className="animate-spin text-indigo-400" />
          </div>
        ) : orders.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <ShoppingCart size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">{t("sp.orders.noOrders")}</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                {visible.includes("order_number") &&
                  renderHeader("order_number", colLabels.order_number)}
                {visible.includes("status") &&
                  renderHeader("status", colLabels.status)}
                {visible.includes("type") &&
                  renderHeader("type", colLabels.type)}
                {visible.includes("products_total") &&
                  renderHeader("products_total", colLabels.products_total)}
                {visible.includes("total_cost_price") &&
                  renderHeader("total_cost_price", colLabels.total_cost_price)}
                {visible.includes("courier_fee") &&
                  renderHeader("courier_fee", colLabels.courier_fee)}
                {visible.includes("payable_amount") &&
                  renderHeader("payable_amount", colLabels.payable_amount)}
                {visible.includes("payment_method") &&
                  renderHeader("payment_method", colLabels.payment_method)}
                {visible.includes("is_ready_for_pickup") &&
                  renderHeader(
                    "is_ready_for_pickup",
                    colLabels.is_ready_for_pickup,
                  )}
                {visible.includes("is_scheduled") &&
                  renderHeader("is_scheduled", colLabels.is_scheduled)}
                {visible.includes("order_schedule_at") &&
                  renderHeader("order_schedule_at", colLabels.order_schedule_at)}
                {visible.includes("proposed_at") &&
                  renderHeader("proposed_at", colLabels.proposed_at)}
                {visible.includes("offer_accepted_at") &&
                  renderHeader(
                    "offer_accepted_at",
                    colLabels.offer_accepted_at,
                  )}
                {visible.includes("order_collected_at") &&
                  renderHeader(
                    "order_collected_at",
                    colLabels.order_collected_at,
                  )}
                {visible.includes("delivered_at") &&
                  renderHeader("delivered_at", colLabels.delivered_at)}
                {visible.includes("canceled_at") &&
                  renderHeader("canceled_at", colLabels.canceled_at)}
                {visible.includes("pickup_address") &&
                  renderHeader("pickup_address", colLabels.pickup_address)}
                {visible.includes("delivery_address") &&
                  renderHeader("delivery_address", colLabels.delivery_address)}
                {visible.includes("created_at") &&
                  renderHeader("created_at", colLabels.created_at)}
                {visible.includes("updated_at") &&
                  renderHeader("updated_at", colLabels.updated_at)}
                {visible.includes("actions") && (
                  <th className="px-4 py-3 text-xs font-semibold text-gray-500 uppercase whitespace-nowrap text-right">
                    {colLabels.actions}
                  </th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.map((o: any) => {
                const isPending = notifyMutation.isPending && notifyMutation.variables === o.id;
                const isNotified = notifiedIds.has(o.id);
                return (
                  <tr
                    key={o.id}
                    onClick={() => router.push(`/supplier/orders/${o.id}`)}
                    className="hover:bg-gray-50 cursor-pointer transition"
                  >
                    {visible.includes("order_number") && (
                      <td className="px-4 py-3">
                        <p className="font-mono text-xs font-semibold text-indigo-700">
                          {o.order_number ?? `#${o.id}`}
                        </p>
                      </td>
                    )}
                    {visible.includes("status") && (
                      <td className="px-4 py-3">
                        <span className={cn("px-2 py-0.5 rounded-full text-xs font-medium", STATUS_STYLES[o.status] ?? "bg-gray-100 text-gray-700")}>
                          {statusLabel(o.status)}
                        </span>
                      </td>
                    )}
                    {visible.includes("type") && (
                      <td className="px-4 py-3">
                        {o.type === "CATALOG_PURCHASE" ? (
                          <span className="text-xs px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700">كتالوج</span>
                        ) : o.type === "CUSTOM_PICKUP" ? (
                          <span className="text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">مخصص</span>
                        ) : (
                          <span className="text-gray-300 text-xs">—</span>
                        )}
                      </td>
                    )}
                    {visible.includes("products_total") && (
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className="font-semibold text-green-700 font-mono">{fmt(o.products_total)}</span>
                      </td>
                    )}
                    {visible.includes("total_cost_price") && (
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className="font-semibold text-indigo-700 font-mono">{fmt(o.total_cost_price)}</span>
                      </td>
                    )}
                    {visible.includes("courier_fee") && (
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className="text-amber-700 font-mono">{fmt(o.courier_fee)}</span>
                      </td>
                    )}
                    {visible.includes("payable_amount") && (
                      <td className="px-4 py-3 font-semibold text-gray-900 whitespace-nowrap font-mono">
                        {fmt(o.payable_amount)}
                      </td>
                    )}
                    {visible.includes("payment_method") && (
                      <td className="px-4 py-3 text-xs text-gray-600 whitespace-nowrap">
                        {o.payment_method ?? "—"}
                      </td>
                    )}
                    {visible.includes("is_ready_for_pickup") && (
                      <td className="px-4 py-3">
                        {o.is_ready_for_pickup ? (
                          <span className="text-xs px-2 py-0.5 rounded-full bg-cyan-50 text-cyan-700">
                            {t("sp.orders.ready")}
                          </span>
                        ) : (
                          <span className="text-gray-300 text-xs">—</span>
                        )}
                      </td>
                    )}
                    {visible.includes("is_scheduled") && (
                      <td className="px-4 py-3">
                        {o.is_scheduled ? (
                          <span className="text-xs px-2 py-0.5 rounded-full bg-purple-50 text-purple-700">
                            {t("sp.orders.yes")}
                          </span>
                        ) : (
                          <span className="text-gray-300 text-xs">
                            {t("sp.orders.no")}
                          </span>
                        )}
                      </td>
                    )}
                    {visible.includes("order_schedule_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.order_schedule_at)}
                      </td>
                    )}
                    {visible.includes("proposed_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.proposed_at)}
                      </td>
                    )}
                    {visible.includes("offer_accepted_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.offer_accepted_at)}
                      </td>
                    )}
                    {visible.includes("order_collected_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.order_collected_at)}
                      </td>
                    )}
                    {visible.includes("delivered_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.delivered_at)}
                      </td>
                    )}
                    {visible.includes("canceled_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.canceled_at)}
                      </td>
                    )}
                    {visible.includes("pickup_address") && (
                      <td
                        className="px-4 py-3 text-xs text-gray-600 max-w-[140px] truncate"
                        title={o.pickup_address_description ?? ""}
                      >
                        {o.pickup_address_description ?? "—"}
                      </td>
                    )}
                    {visible.includes("delivery_address") && (
                      <td
                        className="px-4 py-3 text-xs text-gray-600 max-w-[140px] truncate"
                        title={o.delivery_address_description ?? ""}
                      >
                        {o.delivery_address_description ?? "—"}
                      </td>
                    )}
                    {visible.includes("created_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.created_at)}
                      </td>
                    )}
                    {visible.includes("updated_at") && (
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.updated_at)}
                      </td>
                    )}
                    {visible.includes("actions") && (
                      <td className="px-4 py-3 text-right" onClick={e => e.stopPropagation()}>
                        {(o.status === "SCHEDULED" || o.status === "PENDING") && (() => {
                          const eligible = canRequestCourier(o.order_schedule_at);
                          return (
                            <button
                              onClick={() => notifyMutation.mutate(o.id)}
                              disabled={isPending || isNotified || !eligible}
                              title={
                                !eligible && o.order_schedule_at
                                  ? (lang === "AR"
                                      ? `يمكن طلب مندوب بدءًا من ${fmtDate(new Date(new Date(o.order_schedule_at).getTime() - minNoticeMinutes * 60_000).toISOString())}`
                                      : `Available from ${fmtDate(new Date(new Date(o.order_schedule_at).getTime() - minNoticeMinutes * 60_000).toISOString())}`)
                                  : undefined
                              }
                              className={cn(
                                "inline-flex items-center gap-1.5 px-3 py-1.5 text-white text-xs font-semibold rounded-lg transition whitespace-nowrap",
                                isNotified || !eligible
                                  ? "bg-gray-400 cursor-not-allowed opacity-60"
                                  : "bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60"
                              )}
                            >
                              {isPending ? <RefreshCw size={12} className="animate-spin" /> : <Truck size={12} />}
                              {isNotified
                                ? (lang === "AR" ? "تم الإرسال" : "Sent")
                                : (lang === "AR" ? "طلب مندوب" : "Request Courier")}
                            </button>
                          );
                        })()}
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-500">
          {total} {t("sp.orders.total")} · {t("sp.orders.page")} {page}{" "}
          {t("sp.orders.of")} {Math.max(1, totalPages)}
        </p>
        <div className="flex gap-2">
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page === 1}
            className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
          >
            {isRTL ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
          </button>
          <button
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page >= totalPages}
            className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
          >
            {isRTL ? <ChevronLeft size={16} /> : <ChevronRight size={16} />}
          </button>
        </div>
      </div>
    </div>
  );
}
