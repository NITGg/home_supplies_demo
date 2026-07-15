"use client";

import { useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { supplierApi } from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import {
  CheckCircle2, BellRing, ShoppingBag,
  Package, Loader2, ChevronRight,
  ListOrdered,
} from "lucide-react";
import toast from "react-hot-toast";
import Link from "next/link";

// ── Inner component (uses useSearchParams) ────────────────────────────────────
function SuccessInner() {
  const { t, isRTL: isRtl } = useT();
  const params = useSearchParams();

  const orderId = params.get("orderId") ?? "";
  const orderNumber = params.get("orderNumber") ?? "";

  const [notifying, setNotifying] = useState(false);
  const [notified, setNotified] = useState(false);

  async function handleNotifyCouriers() {
    if (!orderId || notified) return;
    setNotifying(true);
    try {
      await supplierApi.post(`/order/notify-order-ready/${orderId}`);
      setNotified(true);
      toast.success(t("sp.success.notified"));
    } catch (err: any) {
      const msg =
        err?.response?.data?.message ??
        err?.response?.data?.error ??
        t("sp.success.notifyError");
      toast.error(msg);
    } finally {
      setNotifying(false);
    }
  }

  return (
    <div className="max-w-lg mx-auto px-4 py-12 flex flex-col items-center gap-6 text-center">
      {/* Success icon */}
      <div className="relative">
        <div className="w-24 h-24 rounded-full bg-green-100 flex items-center justify-center">
          <CheckCircle2 className="w-12 h-12 text-green-500" />
        </div>
        <div className="absolute -bottom-1 -right-1 w-8 h-8 rounded-full bg-orange-500 flex items-center justify-center shadow-md">
          <ShoppingBag className="w-4 h-4 text-white" />
        </div>
      </div>

      {/* Title */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 mb-1">{t("sp.success.title")}</h1>
        <p className="text-gray-500 text-sm">{t("sp.success.subtitle")}</p>
      </div>

      {/* Order number card */}
      {orderNumber && (
        <div className="w-full bg-gray-50 border border-gray-200 rounded-2xl p-4">
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">{t("sp.success.orderNumber")}</p>
          <p className="text-xl font-bold text-gray-800 font-mono">#{orderNumber}</p>
        </div>
      )}

      {/* What's next card */}
      <div className="w-full bg-orange-50 border border-orange-100 rounded-2xl p-5 text-start">
        <h3 className="text-sm font-semibold text-orange-800 mb-3">{t("sp.success.whatNext")}</h3>
        <div className="flex items-start gap-3 text-sm text-orange-700">
          <Package className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <p>{t("sp.success.waitCourier")}</p>
        </div>
      </div>

      {/* Notify couriers button */}
      {orderId && (
        <div className="w-full">
          <p className="text-xs text-gray-400 mb-2">{t("sp.success.notifyHint")}</p>
          <button
            onClick={handleNotifyCouriers}
            disabled={notifying || notified}
            className={`w-full flex items-center justify-center gap-2 px-5 py-3 rounded-xl font-semibold transition-all ${
              notified
                ? "bg-green-500 text-white cursor-default"
                : "bg-orange-500 hover:bg-orange-600 text-white disabled:opacity-60 disabled:cursor-not-allowed"
            }`}
          >
            {notifying ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                {t("sp.success.notifying")}
              </>
            ) : notified ? (
              <>
                <CheckCircle2 className="w-5 h-5" />
                {t("sp.success.notified")}
              </>
            ) : (
              <>
                <BellRing className="w-5 h-5" />
                {t("sp.success.notifyCouriers")}
              </>
            )}
          </button>
        </div>
      )}

      {/* Navigation links */}
      <div className="w-full flex flex-col gap-2">
        <Link
          href="/supplier/orders"
          className="flex items-center justify-between px-4 py-3 bg-white border border-gray-200 rounded-xl hover:border-gray-300 hover:bg-gray-50 transition-all group"
        >
          <div className="flex items-center gap-2 text-sm font-medium text-gray-700">
            <ListOrdered className="w-4 h-4 text-gray-500" />
            {t("sp.success.viewOrders")}
          </div>
          {isRtl
            ? <ChevronRight className="w-4 h-4 text-gray-400 rotate-180 group-hover:translate-x-1 transition-transform" />
            : <ChevronRight className="w-4 h-4 text-gray-400 group-hover:translate-x-1 transition-transform" />}
        </Link>

        <Link
          href="/supplier/shop"
          className="flex items-center justify-between px-4 py-3 bg-white border border-gray-200 rounded-xl hover:border-gray-300 hover:bg-gray-50 transition-all group"
        >
          <div className="flex items-center gap-2 text-sm font-medium text-gray-700">
            <ShoppingBag className="w-4 h-4 text-gray-500" />
            {t("sp.success.backToShop")}
          </div>
          {isRtl
            ? <ChevronRight className="w-4 h-4 text-gray-400 rotate-180 group-hover:translate-x-1 transition-transform" />
            : <ChevronRight className="w-4 h-4 text-gray-400 group-hover:translate-x-1 transition-transform" />}
        </Link>
      </div>
    </div>
  );
}

// ── Page (wraps in Suspense for useSearchParams) ──────────────────────────────
export default function SuccessPage() {
  return (
    <Suspense fallback={
      <div className="flex items-center justify-center min-h-[60vh]">
        <Loader2 className="w-8 h-8 animate-spin text-orange-500" />
      </div>
    }>
      <SuccessInner />
    </Suspense>
  );
}
