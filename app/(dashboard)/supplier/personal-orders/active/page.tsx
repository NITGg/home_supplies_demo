"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useT } from "@/contexts/LanguageContext";
import {
  fetchMyOrders,
  formatCents,
  ACTIVE_STATUSES,
  type PersonalOrder,
} from "@/lib/personalOrders";
import ProposalsSheet from "@/components/personal-orders/ProposalsSheet";
import CancelOrderSheet from "@/components/personal-orders/CancelOrderSheet";
import LocationViewerModal from "@/components/maps/LocationViewerModal";
import {
  PackageSearch,
  RefreshCw,
  Plus,
  Users,
  XCircle,
  MapPin,
  Truck,
  Phone,
  KeyRound,
  CheckCircle2,
  Loader2,
  Calendar,
  PackageCheck,
} from "lucide-react";

const STATUS_BADGE: Record<string, string> = {
  SCHEDULED: "bg-purple-100 text-purple-700",
  PENDING: "bg-amber-100 text-amber-700",
  IN_PROGRESS: "bg-blue-100 text-blue-700",
};

function hasCoords(lat?: number | string | null, long?: number | string | null) {
  if (lat == null || long == null) return false;
  const la = Number(lat);
  const lo = Number(long);
  return (
    Number.isFinite(la) &&
    Number.isFinite(lo) &&
    Math.abs(la) <= 90 &&
    Math.abs(lo) <= 180
  );
}

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

export default function ActiveOrdersPage() {
  const { t, isRTL, lang } = useT();
  const locale = lang.toLowerCase();

  const [proposalsFor, setProposalsFor] = useState<number | null>(null);
  const [cancelFor, setCancelFor] = useState<number | null>(null);

  const { data, isLoading, isError, refetch, isFetching } = useQuery({
    queryKey: ["active-orders"],
    queryFn: () => fetchMyOrders({ limit: 100, lang }),
    refetchInterval: 15000, // catch status transitions (proposal accepted, delivered…)
  });

  const orders = useMemo(
    () =>
      (data?.orders ?? []).filter((o) =>
        ACTIVE_STATUSES.includes(o.status),
      ),
    [data],
  );

  // Rating a delivered order's courier now happens once from Orders History
  // (see history/page.tsx) — no auto popup here on delivery.

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 space-y-5" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-11 h-11 rounded-2xl bg-indigo-50 flex items-center justify-center">
          <PackageSearch className="w-5 h-5 text-indigo-600" />
        </div>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-gray-900">{t("sp.activeOrders.title")}</h1>
          <p className="text-sm text-gray-500">{t("sp.activeOrders.subtitle")}</p>
        </div>
        <button
          onClick={() => refetch()}
          className="p-2 rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50"
          title={t("common.refresh")}
        >
          <RefreshCw className={`w-4 h-4 ${isFetching ? "animate-spin" : ""}`} />
        </button>
        <Link
          href="/supplier/personal-orders/create"
          className="flex items-center gap-1.5 px-3 py-2 bg-indigo-600 text-white rounded-xl text-sm font-semibold hover:bg-indigo-700"
        >
          <Plus className="w-4 h-4" />
          {t("sp.createOrder.title")}
        </Link>
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
          <p className="text-sm">{t("sp.activeOrders.loadError")}</p>
          <button
            onClick={() => refetch()}
            className="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm"
          >
            {t("common.refresh")}
          </button>
        </div>
      ) : orders.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-gray-400 gap-2 text-center">
          <PackageSearch className="w-12 h-12 text-gray-300" />
          <p className="text-base font-medium text-gray-600">{t("sp.activeOrders.empty")}</p>
          <p className="text-sm">{t("sp.activeOrders.emptyHint")}</p>
          <Link
            href="/supplier/personal-orders/create"
            className="mt-2 flex items-center gap-1.5 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-semibold"
          >
            <Plus className="w-4 h-4" />
            {t("sp.createOrder.title")}
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          {orders.map((order) => (
            <ActiveOrderCard
              key={order.id}
              order={order}
              locale={locale}
              onViewProposals={() => setProposalsFor(order.id)}
              onCancel={() => setCancelFor(order.id)}
            />
          ))}
        </div>
      )}

      {/* Proposals sheet */}
      {proposalsFor != null && (
        <ProposalsSheet
          orderId={proposalsFor}
          open
          onClose={() => setProposalsFor(null)}
          onAccepted={() => refetch()}
        />
      )}

      {/* Cancel sheet */}
      {cancelFor != null && (
        <CancelOrderSheet
          orderId={cancelFor}
          open
          onClose={() => setCancelFor(null)}
          onCancelled={() => refetch()}
        />
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

function ActiveOrderCard({
  order,
  locale,
  onViewProposals,
  onCancel,
}: {
  order: PersonalOrder;
  locale: string;
  onViewProposals: () => void;
  onCancel: () => void;
}) {
  const { t } = useT();
  const [viewLoc, setViewLoc] = useState<{
    lat: number | string;
    long: number | string;
    label: string;
  } | null>(null);
  const isPending = order.status === "PENDING";
  const isScheduled = order.status === "SCHEDULED";
  const isInProgress = order.status === "IN_PROGRESS";
  const collected = !!order.order_collected_at;
  const courierName = order.courier?.user?.full_name ?? "—";
  const courierPhone = order.courier?.user?.phone ?? "";
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
        {showBudget && (
          <InfoRow label={t("sp.createOrder.budget")} value={formatCents(order.budget)} />
        )}
        {(order.pickup_address_description ||
          hasCoords(order.pickup_lat, order.pickup_long)) && (
          <InfoRow
            label={t("sp.createOrder.pickupLocation")}
            value={
              <span className="flex flex-col items-end gap-1">
                {order.pickup_address_description && (
                  <span className="flex items-center gap-1 justify-end">
                    <MapPin className="w-3.5 h-3.5 text-gray-400" />
                    {order.pickup_address_description}
                  </span>
                )}
                {hasCoords(order.pickup_lat, order.pickup_long) && (
                  <button
                    type="button"
                    onClick={() =>
                      setViewLoc({
                        lat: order.pickup_lat!,
                        long: order.pickup_long!,
                        label: t("sp.createOrder.pickupLocation"),
                      })
                    }
                    className="flex items-center gap-1 text-[11px] font-medium text-indigo-600 hover:underline"
                  >
                    <MapPin className="w-3 h-3" />
                    {t("sp.activeOrders.viewLocation")}
                  </button>
                )}
              </span>
            }
          />
        )}
        {(order.delivery_address_description ||
          hasCoords(order.delivery_lat, order.delivery_long)) && (
          <InfoRow
            label={t("sp.createOrder.deliveryLocation")}
            value={
              <span className="flex flex-col items-end gap-1">
                {order.delivery_address_description && (
                  <span className="flex items-center gap-1 justify-end">
                    <MapPin className="w-3.5 h-3.5 text-gray-400" />
                    {order.delivery_address_description}
                  </span>
                )}
                {hasCoords(order.delivery_lat, order.delivery_long) && (
                  <button
                    type="button"
                    onClick={() =>
                      setViewLoc({
                        lat: order.delivery_lat!,
                        long: order.delivery_long!,
                        label: t("sp.createOrder.deliveryLocation"),
                      })
                    }
                    className="flex items-center gap-1 text-[11px] font-medium text-indigo-600 hover:underline"
                  >
                    <MapPin className="w-3 h-3" />
                    {t("sp.activeOrders.viewLocation")}
                  </button>
                )}
              </span>
            }
          />
        )}
        {order.total_fee != null && order.total_fee > 0 && (
          <InfoRow label={t("sp.createOrder.estimatedDeliveryFee")} value={formatCents(order.total_fee)} />
        )}
        {isScheduled && order.scheduled_at && (
          <InfoRow
            label={t("sp.activeOrders.scheduledFor")}
            value={
              <span className="flex items-center gap-1 justify-end">
                <Calendar className="w-3.5 h-3.5 text-gray-400" />
                {fmtDate(order.scheduled_at, locale)}
              </span>
            }
          />
        )}
      </div>

      {/* IN_PROGRESS: courier + delivery confirmation code */}
      {isInProgress && (
        <div className="space-y-3 pt-1">
          {/* Collected banner */}
          {collected && (
            <div className="flex items-center gap-2 px-3 py-2 bg-blue-50 border border-blue-200 rounded-xl">
              <PackageCheck className="w-4 h-4 text-blue-500 shrink-0" />
              <p className="text-xs text-blue-700">{t("sp.activeOrders.collected")}</p>
            </div>
          )}

          {/* Courier */}
          <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
            <div className="w-9 h-9 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center">
              <Truck className="w-4 h-4" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-[11px] text-gray-400">{t("sp.activeOrders.courier")}</p>
              <p className="text-sm font-semibold text-gray-800 truncate">{courierName}</p>
            </div>
            {courierPhone && (
              <a
                href={`tel:${courierPhone}`}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-white border border-gray-200 rounded-lg text-sm text-indigo-600 hover:bg-indigo-50"
              >
                <Phone className="w-3.5 h-3.5" />
                {t("sp.activeOrders.call")}
              </a>
            )}
          </div>

          {/* Delivery confirmation OTP */}
          <div className="flex items-center gap-3 p-3 rounded-xl border-2 border-dashed border-indigo-200 bg-indigo-50/50">
            <KeyRound className="w-5 h-5 text-indigo-500 shrink-0" />
            <div className="flex-1">
              <p className="text-[11px] text-indigo-500">{t("sp.activeOrders.confirmationCode")}</p>
              <p className="text-xl font-bold tracking-[0.3em] text-indigo-700">
                {order.confirmation_otp ?? "----"}
              </p>
            </div>
            <CheckCircle2 className="w-5 h-5 text-indigo-300" />
          </div>
          <p className="text-[11px] text-gray-400">{t("sp.activeOrders.confirmationHint")}</p>
        </div>
      )}

      {/* Actions */}
      {(isPending || isScheduled) && (
        <div className="flex gap-2 pt-1">
          {isPending && (
            <button
              onClick={onViewProposals}
              className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-semibold hover:bg-indigo-700"
            >
              <Users className="w-4 h-4" />
              {t("sp.activeOrders.viewProposals")}
            </button>
          )}
          <button
            onClick={onCancel}
            className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2.5 border-2 border-red-200 text-red-600 rounded-xl text-sm font-semibold hover:bg-red-50"
          >
            <XCircle className="w-4 h-4" />
            {t("sp.activeOrders.cancelOrder")}
          </button>
        </div>
      )}

      {/* Location viewer */}
      {viewLoc && (
        <LocationViewerModal
          isOpen
          onClose={() => setViewLoc(null)}
          lat={viewLoc.lat}
          long={viewLoc.long}
          label={viewLoc.label}
        />
      )}
    </div>
  );
}
