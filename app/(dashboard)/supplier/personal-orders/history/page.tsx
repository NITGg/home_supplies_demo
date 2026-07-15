"use client";

import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useT } from "@/contexts/LanguageContext";
import {
  fetchMyOrders,
  fetchReviewStatus,
  retryOrder,
  formatCents,
  HISTORY_STATUSES,
  type PersonalOrder,
  type PersonalOrderStatus,
  type ReviewStatusReview,
} from "@/lib/personalOrders";
import RateSupplierDialog from "@/components/personal-orders/RateSupplierDialog";
import RateCourierDialog from "@/components/personal-orders/RateCourierDialog";
import RefundDialog from "@/components/personal-orders/RefundDialog";
import toast from "react-hot-toast";
import {
  History,
  RefreshCw,
  XCircle,
  MapPin,
  Loader2,
  RotateCw,
  Star,
  RotateCcw,
  Store,
} from "lucide-react";

const STATUS_BADGE: Record<string, string> = {
  DELIVERED: "bg-green-100 text-green-700",
  CANCELLED: "bg-red-100 text-red-600",
  EXPIRED: "bg-gray-100 text-gray-500",
};

function fmtDate(s?: string | null, locale = "en") {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString(locale === "ar" ? "ar-EG" : "en-GB", {
      dateStyle: "medium",
      timeStyle: "short",
    });
  } catch {
    return s;
  }
}

type Filter = "ALL" | PersonalOrderStatus;
const FILTERS: Filter[] = ["ALL", "DELIVERED", "CANCELLED", "EXPIRED"];

export default function OrderHistoryPage() {
  const { t, isRTL, lang } = useT();
  const locale = lang.toLowerCase();
  const queryClient = useQueryClient();

  const [filter, setFilter] = useState<Filter>("ALL");
  const [retrying, setRetrying] = useState<number | null>(null);
  const [rateSupplierFor, setRateSupplierFor] = useState<PersonalOrder | null>(null);
  const [rateCourierFor, setRateCourierFor] = useState<{
    order: PersonalOrder;
    existingReview: ReviewStatusReview | null;
  } | null>(null);
  const [refundFor, setRefundFor] = useState<PersonalOrder | null>(null);

  const { data, isLoading, isError, refetch, isFetching } = useQuery({
    queryKey: ["order-history"],
    queryFn: () => fetchMyOrders({ limit: 100, lang }),
  });

  const orders = useMemo(() => {
    const history = (data?.orders ?? []).filter((o) => HISTORY_STATUSES.includes(o.status));
    if (filter === "ALL") return history;
    return history.filter((o) => o.status === filter);
  }, [data, filter]);

  async function handleRetry(orderId: number) {
    setRetrying(orderId);
    try {
      await retryOrder(orderId, lang);
      toast.success(t("sp.history.retrySuccess"));
      refetch();
    } catch (err: any) {
      toast.error(err?.response?.data?.message ?? t("sp.history.retryError"));
    } finally {
      setRetrying(null);
    }
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 space-y-5" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-11 h-11 rounded-2xl bg-indigo-50 flex items-center justify-center">
          <History className="w-5 h-5 text-indigo-600" />
        </div>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-gray-900">{t("sp.history.title")}</h1>
          <p className="text-sm text-gray-500">{t("sp.history.subtitle")}</p>
        </div>
        <button
          onClick={() => refetch()}
          className="p-2 rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50"
          title={t("common.refresh")}
        >
          <RefreshCw className={`w-4 h-4 ${isFetching ? "animate-spin" : ""}`} />
        </button>
      </div>

      {/* Status filter */}
      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => {
          const active = filter === f;
          return (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-full text-xs font-medium border transition ${
                active
                  ? "bg-indigo-600 text-white border-indigo-600"
                  : "bg-white text-gray-600 border-gray-200 hover:border-gray-300"
              }`}
            >
              {f === "ALL" ? t("common.all") : t(`sp.orderStatus.${f}`)}
            </button>
          );
        })}
      </div>

      {/* Body */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-20 text-gray-400 gap-2">
          <Loader2 className="w-6 h-6 animate-spin" />
          <span className="text-sm">{t("common.loading")}</span>
        </div>
      ) : isError ? (
        <div className="flex flex-col items-center justify-center py-20 text-gray-500 gap-3">
          <XCircle className="w-8 h-8 text-red-400" />
          <p className="text-sm">{t("sp.history.loadError")}</p>
          <button
            onClick={() => refetch()}
            className="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm"
          >
            {t("common.refresh")}
          </button>
        </div>
      ) : orders.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-gray-400 gap-2 text-center">
          <History className="w-12 h-12 text-gray-300" />
          <p className="text-base font-medium text-gray-600">{t("sp.history.empty")}</p>
        </div>
      ) : (
        <div className="space-y-4">
          {orders.map((order) => (
            <HistoryOrderCard
              key={order.id}
              order={order}
              locale={locale}
              retrying={retrying === order.id}
              onRetry={() => handleRetry(order.id)}
              onRateSupplier={() => setRateSupplierFor(order)}
              onRateCourier={(existingReview) => setRateCourierFor({ order, existingReview })}
              onRefund={() => setRefundFor(order)}
            />
          ))}
        </div>
      )}

      {/* Rate supplier */}
      {rateSupplierFor && rateSupplierFor.supplier?.id && (
        <RateSupplierDialog
          orderId={rateSupplierFor.id}
          supplierId={rateSupplierFor.supplier.id}
          supplierName={rateSupplierFor.supplier.user?.full_name}
          open
          onClose={() => setRateSupplierFor(null)}
        />
      )}

      {/* Rate courier — only once per delivered order */}
      {rateCourierFor && (
        <RateCourierDialog
          orderId={rateCourierFor.order.id}
          courierId={rateCourierFor.order.courier?.id ?? rateCourierFor.order.courier_id ?? 0}
          courierUserId={rateCourierFor.order.courier?.user?.id ?? null}
          courierName={rateCourierFor.order.courier?.user?.full_name ?? ""}
          open
          onClose={() => setRateCourierFor(null)}
          onSubmitted={() => {
            refetch();
            queryClient.invalidateQueries({ queryKey: ["review-status"] });
          }}
          existingReview={rateCourierFor.existingReview}
        />
      )}

      {/* Refund request */}
      {refundFor && (
        <RefundDialog orderId={refundFor.id} open onClose={() => setRefundFor(null)} />
      )}
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-3 text-sm">
      <span className="text-gray-500 shrink-0">{label}</span>
      <span className="text-gray-800 text-end">{value}</span>
    </div>
  );
}

function HistoryOrderCard({
  order,
  locale,
  retrying,
  onRetry,
  onRateSupplier,
  onRateCourier,
  onRefund,
}: {
  order: PersonalOrder;
  locale: string;
  retrying: boolean;
  onRetry: () => void;
  onRateSupplier: () => void;
  onRateCourier: (existingReview: ReviewStatusReview | null) => void;
  onRefund: () => void;
}) {
  const { t } = useT();
  const isExpired = order.status === "EXPIRED";
  const isDelivered = order.status === "DELIVERED";
  const hasSupplier = !!order.supplier?.id;
  const courierId = order.courier?.id ?? order.courier_id ?? null;
  const hasCourier = !!courierId;
  const canRateCourier = isDelivered && hasCourier;

  // Ask the Courier API whether this customer already reviewed the courier for
  // this order. A delivered order can be rated exactly once — once a review
  // exists we show "view review" instead of "rate".
  const { data: reviewStatus } = useQuery({
    queryKey: ["review-status", order.id, courierId],
    queryFn: () => fetchReviewStatus(order.id, courierId as number),
    enabled: canRateCourier,
  });
  const customerReview = reviewStatus?.customer_review ?? null;
  const alreadyRatedCourier = reviewStatus?.reviewed_by_customer ?? false;
  const showBudget = order.budget != null && order.budget > 1;

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 space-y-4">
      {/* Header */}
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-bold text-gray-900">#{order.order_number}</p>
          <p className="text-[11px] text-gray-400">{fmtDate(order.created_at, locale)}</p>
        </div>
        <span
          className={`text-[11px] px-2 py-1 rounded-full font-medium ${
            STATUS_BADGE[order.status] ?? "bg-gray-100 text-gray-600"
          }`}
        >
          {t(`sp.orderStatus.${order.status}`)}
        </span>
      </div>

      {/* Details */}
      <div className="space-y-2">
        {order.product_description && (
          <InfoRow label={t("sp.createOrder.productDescription")} value={order.product_description} />
        )}
        {showBudget && <InfoRow label={t("sp.createOrder.budget")} value={formatCents(order.budget)} />}
        {hasSupplier && (
          <InfoRow
            label={t("sp.history.supplier")}
            value={
              <span className="flex items-center gap-1 justify-end">
                <Store className="w-3.5 h-3.5 text-gray-400" />
                {order.supplier?.user?.full_name ?? `#${order.supplier?.id}`}
              </span>
            }
          />
        )}
        {order.delivery_address_description && (
          <InfoRow
            label={t("sp.createOrder.deliveryLocation")}
            value={
              <span className="flex items-center gap-1 justify-end">
                <MapPin className="w-3.5 h-3.5 text-gray-400" />
                {order.delivery_address_description}
              </span>
            }
          />
        )}
        {order.total_fee != null && order.total_fee > 0 && (
          <InfoRow label={t("sp.createOrder.estimatedDeliveryFee")} value={formatCents(order.total_fee)} />
        )}
        {order.delivered_at && (
          <InfoRow label={t("sp.history.deliveredAt")} value={fmtDate(order.delivered_at, locale)} />
        )}
      </div>

      {/* Actions */}
      <div className="flex flex-wrap gap-2 pt-1">
        {isExpired && (
          <button
            onClick={onRetry}
            disabled={retrying}
            className="flex items-center justify-center gap-1.5 px-3 py-2 bg-indigo-600 text-white rounded-xl text-sm font-semibold hover:bg-indigo-700 disabled:opacity-50"
          >
            {retrying ? <Loader2 className="w-4 h-4 animate-spin" /> : <RotateCw className="w-4 h-4" />}
            {t("sp.history.retry")}
          </button>
        )}
        {canRateCourier &&
          (alreadyRatedCourier ? (
            <button
              onClick={() => onRateCourier(customerReview)}
              className="flex items-center justify-center gap-1.5 px-3 py-2 border-2 border-green-200 text-green-600 rounded-xl text-sm font-semibold hover:bg-green-50"
            >
              <Star className="w-4 h-4 fill-current" />
              {t("sp.history.viewReview")}
            </button>
          ) : (
            <button
              onClick={() => onRateCourier(null)}
              className="flex items-center justify-center gap-1.5 px-3 py-2 border-2 border-amber-200 text-amber-600 rounded-xl text-sm font-semibold hover:bg-amber-50"
            >
              <Star className="w-4 h-4" />
              {t("sp.history.rateCourier")}
            </button>
          ))}
        {hasSupplier && (
          <>
            <button
              onClick={onRateSupplier}
              className="flex items-center justify-center gap-1.5 px-3 py-2 border-2 border-amber-200 text-amber-600 rounded-xl text-sm font-semibold hover:bg-amber-50"
            >
              <Star className="w-4 h-4" />
              {t("sp.history.rateSupplier")}
            </button>
            <button
              onClick={onRefund}
              className="flex items-center justify-center gap-1.5 px-3 py-2 border-2 border-gray-200 text-gray-600 rounded-xl text-sm font-semibold hover:bg-gray-50"
            >
              <RotateCcw className="w-4 h-4" />
              {t("sp.history.requestRefund")}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
