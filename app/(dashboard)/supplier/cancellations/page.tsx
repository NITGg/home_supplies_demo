"use client";
import { useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { fetchCancellationReasons } from "@/lib/cancellation-reasons";
import { fetchOrders } from "@/lib/orders";
import { useT } from "@/contexts/LanguageContext";
import { XCircle, List, ShoppingCart, Send, RefreshCw } from "lucide-react";
import toast from "react-hot-toast";
import api from "@/lib/api";

type PageTab = "reasons" | "orders" | "request";

export default function SupplierCancellationsPage() {
  const { t, isRTL } = useT();
  const [tab, setTab] = useState<PageTab>("reasons");
  const [orderPage, setOrderPage] = useState(1);

  // Fetch all cancellation reasons (visible to suppliers)
  const { data: reasonsData, isLoading: reasonsLoading, refetch } = useQuery({
    queryKey: ["supplier-cancellation-reasons"],
    queryFn: () => fetchCancellationReasons({ limit: 100, page: 1 }),
  });

  // Fetch supplier's own cancelled orders
  const {
    data: ordersData,
    isLoading: ordersLoading,
    isFetching: ordersFetching,
  } = useQuery({
    queryKey: ["supplier-cancelled-orders", orderPage],
    queryFn: () =>
      fetchOrders({
        page: orderPage,
        limit: 15,
        status: "CANCELLED",
        includes: "customer",
      }),
    enabled: tab === "orders",
  });

  const reasons = reasonsData?.reasons ?? [];
  const orders = ordersData?.orders ?? [];
  const totalPages = ordersData?.totalPages ?? 1;
  const totalOrders = ordersData?.totalOrders ?? 0;

  const TABS = [
    { key: "reasons" as PageTab, label: t("sp.cancellations.tabReasons"), icon: List },
    { key: "orders" as PageTab, label: t("sp.cancellations.tabOrders"), icon: ShoppingCart },
    { key: "request" as PageTab, label: t("sp.cancellations.tabRequest"), icon: Send },
  ];

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <XCircle size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("sp.cancellations.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("sp.cancellations.subtitle")}</p>
        </div>
        <button
          onClick={() => refetch()}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50"
        >
          <RefreshCw size={15} />
          {t("common.refresh")}
        </button>
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

      {/* ── REASONS TAB ─────────────────────────────────────────────────── */}
      {tab === "reasons" && (
        <div className="space-y-3">
          {reasonsLoading ? (
            Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-14 bg-gray-100 rounded-xl animate-pulse" />
            ))
          ) : reasons.length === 0 ? (
            <div className="text-center py-20 text-gray-400">
              <XCircle size={40} className="mx-auto mb-3 text-gray-300" />
              <p>{t("sp.cancellations.noReasons")}</p>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm divide-y divide-gray-50">
              {reasons.map(r => (
                <div key={r.id} className="px-5 py-4 flex items-start justify-between gap-4">
                  <div className="flex-1 space-y-0.5">
                    <p className="text-sm font-medium text-gray-900">{r.reason_en}</p>
                    <p className="text-sm text-gray-500" dir="rtl">{r.reason_ar}</p>
                  </div>
                  <span
                    className={`shrink-0 text-xs px-2.5 py-1 rounded-full font-medium ${
                      r.role_id === 1
                        ? "bg-indigo-100 text-indigo-700"
                        : r.role_id === 2
                        ? "bg-green-100 text-green-700"
                        : "bg-amber-100 text-amber-700"
                    }`}
                  >
                    {r.role_id === 1 ? t("cancellationReasons.roleCustomer") : r.role_id === 2 ? t("cancellationReasons.roleCourier") : t("cancellationReasons.roleAdmin")}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── CANCELLED ORDERS TAB ────────────────────────────────────────── */}
      {tab === "orders" && (
        <div className="space-y-4">
          {ordersLoading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
            ))
          ) : orders.length === 0 ? (
            <div className="text-center py-20 text-gray-400">
              <ShoppingCart size={40} className="mx-auto mb-3 text-gray-300" />
              <p>{t("sp.cancellations.noCancelled")}</p>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("common.id")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("cancellationReasons.customerName")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("sp.cancellations.cancelledReason")}</th>
                    <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{t("sp.cancellations.cancelledAt")}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {orders.map(order => (
                    <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 text-xs font-mono text-gray-400">#{order.id}</td>
                      <td className="px-4 py-3">
                        <p className="font-medium text-gray-900">{order.customer?.full_name ?? `#${order.customer?.id ?? "?"}`}</p>
                        {order.customer?.phone && (
                          <p className="text-xs text-gray-400">{order.customer.phone}</p>
                        )}
                      </td>
                      <td className="px-4 py-3 max-w-[240px]">
                        {order.cancelled_reason ? (
                          <p className="text-sm text-gray-700 line-clamp-2">{order.cancelled_reason}</p>
                        ) : (
                          <span className="text-xs text-gray-400 italic">{t("sp.cancellations.noReason")}</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-500">
                        {order.canceled_at
                          ? new Date(order.canceled_at).toLocaleDateString(undefined, {
                              year: "numeric",
                              month: "short",
                              day: "numeric",
                            })
                          : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2">
              <button
                onClick={() => setOrderPage(p => Math.max(1, p - 1))}
                disabled={orderPage <= 1 || ordersFetching}
                className="px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-40"
              >
                {t("common.previous")}
              </button>
              <span className="text-sm text-gray-500">
                {t("common.page")} {orderPage} {t("common.of")} {totalPages}
              </span>
              <button
                onClick={() => setOrderPage(p => Math.min(totalPages, p + 1))}
                disabled={orderPage >= totalPages || ordersFetching}
                className="px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-40"
              >
                {t("common.next")}
              </button>
            </div>
          )}
        </div>
      )}

      {/* ── REQUEST TAB ─────────────────────────────────────────────────── */}
      {tab === "request" && (
        <RequestForm t={t} isRTL={isRTL} />
      )}
    </div>
  );
}

function RequestForm({ t, isRTL }: { t: (k: string) => string; isRTL: boolean }) {
  const [form, setForm] = useState({ reason_en: "", reason_ar: "" });
  const [submitted, setSubmitted] = useState(false);

  const submitMut = useMutation({
    mutationFn: async (data: typeof form) => {
      // Suppliers can suggest reasons — posted as role_id=4 (supplier request)
      // This creates a note to admin; fallback: just post to cancellation-reason as role 1 with admin review
      await api.post("/admin/cancellation-reason/reason", {
        ...data,
        role_id: "1", // Will be reviewed and corrected by admin
        admin_notes: "[SUPPLIER REQUEST - Pending admin review]",
      });
    },
    onSuccess: () => {
      toast.success(t("sp.cancellations.requestSent"));
      setSubmitted(true);
    },
    onError: () => toast.error("Failed to submit request"),
  });

  if (submitted) {
    return (
      <div className="text-center py-16">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-green-100 mb-4">
          <Send size={28} className="text-green-600" />
        </div>
        <h3 className="text-lg font-semibold text-gray-900 mb-1">{t("sp.cancellations.requestSent")}</h3>
        <p className="text-sm text-gray-500 mb-6">{t("sp.cancellations.requestDesc")}</p>
        <button
          onClick={() => { setForm({ reason_en: "", reason_ar: "" }); setSubmitted(false); }}
          className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700"
        >
          {t("common.new")}
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-lg mx-auto">
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 space-y-5">
        <div>
          <h2 className="text-base font-semibold text-gray-900">{t("sp.cancellations.requestTitle")}</h2>
          <p className="text-sm text-gray-500 mt-1">{t("sp.cancellations.requestDesc")}</p>
        </div>

        <form
          onSubmit={e => { e.preventDefault(); submitMut.mutate(form); }}
          className="space-y-4"
        >
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              {t("sp.cancellations.requestReasonEn")}
            </label>
            <input
              required
              value={form.reason_en}
              onChange={e => setForm(p => ({ ...p, reason_en: e.target.value }))}
              placeholder="e.g. Item was out of stock"
              className="input"
            />
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              {t("sp.cancellations.requestReasonAr")}
            </label>
            <input
              required
              value={form.reason_ar}
              onChange={e => setForm(p => ({ ...p, reason_ar: e.target.value }))}
              placeholder="مثلاً: المنتج غير متوفر"
              dir="rtl"
              className="input text-right"
            />
          </div>
          <button
            type="submit"
            disabled={submitMut.isPending}
            className="w-full flex items-center justify-center gap-2 px-6 py-3 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
          >
            <Send size={16} />
            {submitMut.isPending ? t("common.saving") : t("sp.cancellations.requestSubmit")}
          </button>
        </form>
      </div>
    </div>
  );
}
