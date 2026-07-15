"use client";
import * as React from "react";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { supplierApi } from "@/lib/api";
import toast from "react-hot-toast";
import { ArrowLeft, ArrowRight, ShoppingBag, Calendar, RefreshCw, XCircle, Truck } from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";

const STATUS_STYLES: Record<string, string> = {
  PENDING:          "bg-amber-100 text-amber-700 border-amber-200",
  SEARCHING_FAILED: "bg-orange-100 text-orange-700 border-orange-200",
  IN_PROGRESS:      "bg-blue-100 text-blue-700 border-blue-200",
  DELIVERED:        "bg-green-100 text-green-700 border-green-200",
  CANCELLED:        "bg-red-100 text-red-700 border-red-200",
  EXPIRED:          "bg-gray-100 text-gray-500 border-gray-200",
  SCHEDULED:        "bg-purple-100 text-purple-700 border-purple-200",
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

function fmt(n: number | string | null | undefined) {
  if (n == null) return "—";
  const num = Number(n);
  if (isNaN(num)) return "—";
  return `${(num / 100).toFixed(2)} EGP`;
}

function fmtDate(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" });
}

// 12-hour format with am/pm
function fmtDate12(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

export default function OrderDetailsPage({ params }: { params: { id: string } | Promise<{ id: string }> }) {
  const { lang, isRTL } = useT();
  const router = useRouter();
  const unwrappedParams = (React.use ? React.use(params as any) : params) as any;
  const id = unwrappedParams.id;

  // Main order info (customer, financials, status, addresses)
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["supplier-order-detail", id],
    queryFn: async () => {
      const res = await supplierApi.get(`/order/order-details/${id}`);
      // Response: { status, data: { order: {...} } }
      return res.data?.data?.order ?? res.data?.data ?? res.data?.order ?? res.data;
    },
    enabled: !!id,
  });

  const qc = useQueryClient();

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
  React.useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(t);
  }, []);

  const [notified, setNotified] = useState(false);

  // Notify courier search
  const notifyMutation = useMutation({
    mutationFn: async () => {
      const res = await supplierApi.post(`/order/notify-order-ready/${id}`);
      return res.data;
    },
    onSuccess: () => {
      toast.success(lang === "AR" ? "تم إرسال الطلب للبحث عن مندوب!" : "Searching for a courier started!");
      setNotified(true);
      qc.invalidateQueries({ queryKey: ["supplier-order-detail", id] });
    },
    onError: (err: any) => {
      toast.error(err?.response?.data?.message || (lang === "AR" ? "حدث خطأ، حاول مرة أخرى" : "Something went wrong"));
    },
  });

  // Order items (separate call — order-details endpoint doesn't include items)
  const { data: itemsData } = useQuery({
    queryKey: ["supplier-order-items", id],
    queryFn: async () => {
      const res = await supplierApi.get("/order/list-orders", {
        params: { limit: 1, skip: 0, id, includes: "orderItems.product" },
      });
      const orders = res.data?.data?.orders ?? res.data?.orders ?? [];
      return orders.find((o: any) => String(o.id) === String(id))?.orderItems ?? orders[0]?.orderItems ?? [];
    },
    enabled: !!id,
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <RefreshCw className="w-8 h-8 animate-spin text-indigo-600" />
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="p-6 text-center space-y-4" dir={isRTL ? "rtl" : "ltr"}>
        <XCircle className="w-16 h-16 text-red-500 mx-auto" />
        <h2 className="text-xl font-bold text-gray-900">
          {lang === "AR" ? "فشل تحميل تفاصيل الطلب" : "Failed to load order details"}
        </h2>
        <button
          onClick={() => refetch()}
          className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition"
        >
          {lang === "AR" ? "إعادة المحاولة" : "Retry"}
        </button>
      </div>
    );
  }

  const o = data;
  const orderItems: any[] = itemsData ?? [];
  const statusLabel = lang === "AR" ? (STATUS_LABELS_AR[o.status] ?? o.status) : o.status.replace(/_/g, " ");

  // Supplier may request couriers from (order_schedule_at - minNotice) onwards.
  const scheduleAt: string | null = o.order_schedule_at ?? null;
  const earliestRequestAt = scheduleAt
    ? new Date(new Date(scheduleAt).getTime() - minNoticeMinutes * 60_000)
    : null;
  const canRequestCourier = !earliestRequestAt || now >= earliestRequestAt.getTime();

  // total_cost_price comes from the order object (API returns it as string from Decimal)
  const costTotal = Number(o.total_cost_price ?? 0);
  // Fallback: sum from items if API total is missing
  const computedCostTotal = costTotal > 0
    ? costTotal
    : orderItems.reduce((sum: number, item: any) => {
        const cp = Number(item.cost_price ?? item.supplierProduct?.cost_price ?? 0);
        return sum + cp * Number(item.quantity ?? 1);
      }, 0);
  const shippingTotal = Number(o.courier_fee ?? 0) + Number(o.platform_fee ?? 0);

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto" dir={isRTL ? "rtl" : "ltr"}>
      {/* Breadcrumb & Navigation */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <button
          onClick={() => router.back()}
          className="flex items-center gap-2 text-sm text-gray-500 hover:text-indigo-600 transition font-medium"
        >
          {isRTL ? <ArrowRight size={18} /> : <ArrowLeft size={18} />}
          <span>{lang === "AR" ? "العودة للطلبات" : "Back to Orders"}</span>
        </button>

        <div className="flex items-center gap-3">
          <span className={cn(
            "px-3 py-1 rounded-full text-xs font-semibold border shadow-sm",
            STATUS_STYLES[o.status] ?? "bg-gray-100 text-gray-700 border-gray-200"
          )}>
            {statusLabel}
          </span>

          {/* Notify courier button — for SCHEDULED and PENDING orders */}
          {(o.status === "SCHEDULED" || o.status === "PENDING") && (
            <button
              onClick={() => notifyMutation.mutate()}
              disabled={notifyMutation.isPending || notified || !canRequestCourier}
              title={
                !canRequestCourier && earliestRequestAt
                  ? (lang === "AR"
                      ? `يمكن طلب مندوب بدءًا من ${fmtDate12(earliestRequestAt.toISOString())}`
                      : `Available from ${fmtDate12(earliestRequestAt.toISOString())}`)
                  : undefined
              }
              className={cn(
                "flex items-center gap-2 px-4 py-2 text-white text-sm font-semibold rounded-xl shadow-sm transition",
                notified || !canRequestCourier
                  ? "bg-gray-400 cursor-not-allowed opacity-60"
                  : "bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60"
              )}
            >
              {notifyMutation.isPending ? (
                <RefreshCw size={15} className="animate-spin" />
              ) : (
                <Truck size={15} />
              )}
              {notified
                ? (lang === "AR" ? "تم الإرسال" : "Sent")
                : (lang === "AR" ? "طلب مندوب" : "Request Courier")}
            </button>
          )}
        </div>
      </div>

      {/* Main Order Info Card */}
      <div className="bg-white border border-gray-100 rounded-2xl shadow-sm p-6">
        <div className="flex items-center gap-4 flex-wrap justify-between">
          <div className="space-y-1">
            <span className="text-xs text-gray-400 font-mono block">#{o.id}</span>
            <h1 className="text-xl font-bold text-gray-900 tracking-tight flex items-center gap-2">
              <ShoppingBag size={20} className="text-indigo-600" />
              {o.order_number ?? `#${o.id}`}
            </h1>
          </div>
          <div className="text-right">
            <span className="text-xs text-gray-400 block">{lang === "AR" ? "تاريخ الطلب" : "Order Date"}</span>
            <span className="text-sm font-semibold text-gray-700">{fmtDate(o.created_at)}</span>
          </div>
        </div>
      </div>

      {/* Scheduling / Courier Request Window */}
      {(o.status === "SCHEDULED" || o.status === "PENDING") && (
        <div className={cn(
          "border rounded-2xl shadow-sm p-5",
          canRequestCourier
            ? "bg-green-50/50 border-green-100"
            : "bg-amber-50/50 border-amber-100"
        )}>
          <h2 className="text-sm font-bold text-gray-800 flex items-center gap-2 mb-3">
            <Calendar size={16} className={canRequestCourier ? "text-green-600" : "text-amber-600"} />
            {lang === "AR" ? "جدولة طلب المندوب" : "Courier Request Scheduling"}
          </h2>
          {scheduleAt ? (
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
              <div className="space-y-0.5">
                <span className="text-xs text-gray-500 block">
                  {lang === "AR" ? "موعد جدولة الطلب" : "Scheduled At"}
                </span>
                <span className="font-semibold text-gray-800">{fmtDate12(scheduleAt)}</span>
              </div>
              <div className="space-y-0.5">
                <span className="text-xs text-gray-500 block">
                  {lang === "AR" ? "أقل مهلة قبل الموعد" : "Min Notice Before"}
                </span>
                <span className="font-semibold text-gray-800">
                  {minNoticeMinutes} {lang === "AR" ? "دقيقة" : "min"}
                </span>
              </div>
              <div className="space-y-0.5">
                <span className="text-xs text-gray-500 block">
                  {lang === "AR" ? "يمكن طلب مندوب بدءًا من" : "Can Request From"}
                </span>
                <span className="font-semibold text-gray-800">
                  {earliestRequestAt ? fmtDate12(earliestRequestAt.toISOString()) : "—"}
                </span>
              </div>
            </div>
          ) : null}
          <p className={cn(
            "text-xs font-medium",
            scheduleAt ? "mt-3" : "",
            canRequestCourier ? "text-green-700" : "text-amber-700"
          )}>
            {canRequestCourier
              ? (lang === "AR"
                  ? "هذا الطلب جاهز — يمكنك الآن طلب مندوب."
                  : "This order is ready — you can now request a courier.")
              : (lang === "AR"
                  ? `لا يمكنك طلب مندوب بعد. يمكنك طلب مندوب في موعد الجدولة أو قبله بـ ${minNoticeMinutes} دقيقة.`
                  : `You can't request a courier yet. You may request at the scheduled time or up to ${minNoticeMinutes} minutes earlier.`)}
          </p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Order Items + Financial Breakdown */}
        <div className="lg:col-span-2 space-y-6">

          {/* Order Items Table */}
          <div className="bg-white border border-gray-100 rounded-2xl shadow-sm p-6 space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              {lang === "AR" ? "المنتجات المطلوبة" : "Order Items"} ({orderItems.length})
            </h2>
            {orderItems.length === 0 ? (
              <div className="text-center py-10 text-gray-400 text-sm">
                {lang === "AR" ? "لا توجد منتجات في هذا الطلب" : "No items in this order."}
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-gray-100 text-xs text-gray-400 font-semibold uppercase tracking-wide">
                      <th className="text-start pb-3 pr-4">{lang === "AR" ? "المنتج" : "Product"}</th>
                      <th className="text-center pb-3 px-3">{lang === "AR" ? "الكمية" : "Qty"}</th>
                      <th className="text-end pb-3 px-3">{lang === "AR" ? "سعر التكلفة" : "Cost/unit"}</th>
                      <th className="text-end pb-3 px-3">{lang === "AR" ? "سعر البيع" : "Sell/unit"}</th>
                      <th className="text-end pb-3 ps-3">{lang === "AR" ? "المجموع" : "Subtotal"}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {orderItems.map((item: any, idx: number) => {
                      const product = item.product ?? item.supplierProduct?.product;
                      const quantity = Number(item.quantity ?? 1);
                      const costPrice = Number(item.cost_price ?? item.supplierProduct?.cost_price ?? 0);
                      const unitPrice = Number(item.unit_price ?? 0);
                      const subtotal = costPrice * quantity;

                      let imgUrl: string | null = null;
                      const rawImages = product?.images;
                      if (rawImages) {
                        try { const p = JSON.parse(rawImages); imgUrl = Array.isArray(p) ? p[0] : p; }
                        catch { imgUrl = rawImages; }
                      }
                      const name = lang === "AR"
                        ? (product?.name_ar ?? product?.name ?? "—")
                        : (product?.name ?? product?.name_ar ?? "—");

                      return (
                        <tr key={item.id ?? idx}>
                          <td className="py-3 pr-4">
                            <div className="flex items-center gap-3">
                              {imgUrl ? (
                                <img src={imgUrl} alt={name} className="w-10 h-10 rounded-lg object-cover border border-gray-200 shrink-0" />
                              ) : (
                                <div className="w-10 h-10 rounded-lg bg-gray-50 flex items-center justify-center border border-gray-200 shrink-0">
                                  <ShoppingBag size={16} className="text-gray-300" />
                                </div>
                              )}
                              <span className="font-semibold text-gray-900 truncate max-w-[200px]" title={name}>{name}</span>
                            </div>
                          </td>
                          <td className="py-3 px-3 text-center font-bold text-gray-700">{quantity}</td>
                          <td className="py-3 px-3 text-end font-mono text-indigo-600">{fmt(costPrice)}</td>
                          <td className="py-3 px-3 text-end font-mono text-green-600">{fmt(unitPrice)}</td>
                          <td className="py-3 ps-3 text-end font-mono font-bold text-gray-800">{fmt(subtotal)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {/* Financial Breakdown */}
          <div className="bg-white border border-gray-100 rounded-2xl shadow-sm p-6 space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              {lang === "AR" ? "ملخص مالي" : "Financial Summary"}
            </h2>

            {/* Products subtotal */}
            <div className="space-y-2 text-sm">
              <div className="flex justify-between text-gray-600">
                <span>{lang === "AR" ? "إجمالي المنتجات (سعر التكلفة)" : "Products subtotal (cost)"}</span>
                <span className="font-mono font-semibold text-indigo-600">{fmt(computedCostTotal)}</span>
              </div>
            </div>

            {/* Shipping breakdown */}
            <div className="bg-gray-50 rounded-xl border border-gray-100 p-4 space-y-2 text-sm">
              <p className="text-xs font-bold text-gray-400 uppercase tracking-wide mb-3">
                {lang === "AR" ? "تفاصيل الشحن" : "Shipping Breakdown"}
              </p>
              <div className="flex justify-between text-gray-600">
                <span>{lang === "AR" ? "رسوم التوصيل (المندوب)" : "Courier Delivery Fee"}</span>
                <span className="font-mono">{fmt(o.courier_fee)}</span>
              </div>
              <div className="flex justify-between text-gray-600">
                <span>{lang === "AR" ? "عمولة المنصة" : "Platform Commission"}</span>
                <span className="font-mono">{fmt(o.platform_fee)}</span>
              </div>
              <div className="flex justify-between font-semibold text-gray-700 border-t border-gray-200 pt-2 mt-1">
                <span>{lang === "AR" ? "إجمالي الشحن" : "Shipping Total"}</span>
                <span className="font-mono">{fmt(shippingTotal)}</span>
              </div>
            </div>

            {/* Supplier grand total */}
            <div className="flex justify-between items-center bg-indigo-600 text-white rounded-xl px-5 py-4">
              <span className="font-bold text-base">
                {lang === "AR" ? "الإجمالي للمورد" : "Supplier Order Total"}
              </span>
              <span className="font-mono font-bold text-xl">
                {fmt(computedCostTotal + shippingTotal)}
              </span>
            </div>
          </div>

        </div>

        {/* Right Column: Tracking & Addresses */}
        <div className="space-y-6">
          {/* Timeline Tracking */}
          <div className="bg-white border border-gray-100 rounded-2xl shadow-sm p-6 space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3 flex items-center gap-2">
              <Calendar size={18} className="text-indigo-600" />
              {lang === "AR" ? "المخطط الزمني" : "Timeline"}
            </h2>
            <div className="space-y-4 text-sm relative border-l-2 border-gray-100 pl-4 ml-2">
              {[
                { label: lang === "AR" ? "تم إنشاء الطلب" : "Order Created", date: o.created_at, active: true },
                { label: lang === "AR" ? "تم عرض السعر" : "Proposed Offer", date: o.proposed_at, active: !!o.proposed_at },
                { label: lang === "AR" ? "تم قبول العرض" : "Offer Accepted", date: o.offer_accepted_at, active: !!o.offer_accepted_at },
                { label: lang === "AR" ? "تم استلام الشحنة" : "Collected for Delivery", date: o.order_collected_at, active: !!o.order_collected_at },
                { label: lang === "AR" ? "تم التوصيل" : "Delivered", date: o.delivered_at, active: !!o.delivered_at },
                { label: lang === "AR" ? "تم إلغاء الطلب" : "Cancelled", date: o.canceled_at, active: !!o.canceled_at },
              ].map((step, idx) => {
                if (!step.date && !step.active) return null;
                return (
                  <div key={idx} className="relative space-y-0.5">
                    <span className={cn(
                      "absolute -left-[23px] top-1 w-2.5 h-2.5 rounded-full border-2 bg-white",
                      step.active ? "border-indigo-600 bg-indigo-600" : "border-gray-300"
                    )} />
                    <div className="font-semibold text-xs text-gray-700">{step.label}</div>
                    <div className="text-[10px] text-gray-400">{step.date ? fmtDate(step.date) : (lang === "AR" ? "معلق" : "Pending")}</div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
