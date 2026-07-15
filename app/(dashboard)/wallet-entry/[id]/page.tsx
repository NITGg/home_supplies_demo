"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchWalletEntries } from "@/lib/wallet";
import { useParams, useRouter } from "next/navigation";
import { useT } from "@/contexts/LanguageContext";
import { ArrowLeft, FileText, CheckCircle } from "lucide-react";
import { cn } from "@/lib/utils";

export default function WalletEntryDetailsPage() {
  const { t, lang } = useT();
  const { id } = useParams();
  const router = useRouter();

  const { data, isLoading } = useQuery({
    queryKey: ["walletEntry", id],
    queryFn: () =>
      fetchWalletEntries({
        id: id as string,
        limit: 1,
        includes: "wallet,settlement,order,penalty,unpaidCommission,customerCoupon,courierCoupon",
      }),
  });

  const entry = data?.walletEntries?.[0];

  function fmtAmt(n: number | string | undefined) {
    if (n === undefined || n === null) return "0.00 EGP";
    const num = typeof n === "string" ? parseFloat(n) : n;
    return `${(num / 100).toFixed(2)} EGP`;
  }

  function fmtDate(d: string) {
    return new Date(d).toLocaleDateString(lang === "AR" ? "ar-EG" : "en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    });
  }

  if (isLoading) {
    return <div className="p-6 text-center text-gray-500">{t("common.loading")}</div>;
  }

  if (!entry) {
    return (
      <div className="p-6">
        <button onClick={() => router.back()} className="flex items-center gap-2 text-gray-500 mb-4 hover:text-gray-900 transition">
          <ArrowLeft size={18} /> {lang === "AR" ? "رجوع" : "Back"}
        </button>
        <div className="text-center py-20 text-gray-500">
          {lang === "AR" ? "لم يتم العثور على الإدخال" : "Entry not found"}
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6">
      <div className="flex items-center gap-4 mb-6">
        <button onClick={() => router.back()} className="p-2 bg-white rounded-xl shadow-sm border border-gray-100 text-gray-500 hover:text-gray-900 transition">
          <ArrowLeft size={20} />
        </button>
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold text-gray-900">
              {lang === "AR" ? "تفاصيل إدخال المحفظة" : "Wallet Entry Details"} #{entry.id}
            </h1>
            <span
              className={cn(
                "px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider ml-2",
                entry.is_settled 
                  ? "bg-green-100 text-green-700" 
                  : "bg-yellow-100 text-yellow-700"
              )}
            >
              {entry.is_settled ? (lang === "AR" ? "مسوى" : "Settled") : (lang === "AR" ? "معلق" : "Pending")}
            </span>
          </div>
          <p className="text-sm text-gray-500 mt-1">
            {fmtDate(entry.created_at)}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Basic Information */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <FileText size={18} className="text-indigo-600" />
            {lang === "AR" ? "المعلومات الأساسية" : "Basic Information"}
          </h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-xs text-gray-500 mb-1">Wallet ID</p>
              <p className="font-medium text-gray-900">{entry.wallet_id}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500 mb-1">Amount</p>
              <p className={cn("font-bold text-lg", entry.amount < 0 ? "text-red-600" : "text-green-600")}>
                {fmtAmt(entry.amount)}
              </p>
            </div>
            {entry.notes && (
              <div className="col-span-2 mt-2">
                <p className="text-xs text-gray-500 mb-1">Notes</p>
                <p className="text-sm text-gray-800 bg-gray-50 p-3 rounded-xl border border-gray-100">
                  {entry.notes}
                </p>
              </div>
            )}
            {entry.points_to_money && (
              <div className="col-span-2">
                <p className="text-xs text-gray-500 mb-1">Points to Money</p>
                <p className="font-medium text-gray-900">{entry.points_to_money}</p>
              </div>
            )}
          </div>
        </div>

        {/* Settlement Information */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <CheckCircle size={18} className="text-green-600" />
            {lang === "AR" ? "معلومات التسوية" : "Settlement Information"}
          </h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-xs text-gray-500 mb-1">Status</p>
              <p className="font-medium text-gray-900">
                {entry.is_settled ? (lang === "AR" ? "مسوى" : "Settled") : (lang === "AR" ? "معلق" : "Pending")}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 mb-1">Settled At</p>
              <p className="font-medium text-gray-900">
                {entry.settled_at ? fmtDate(entry.settled_at) : "—"}
              </p>
            </div>
            <div className="col-span-2">
              <p className="text-xs text-gray-500 mb-1">Settlement ID</p>
              <p className="font-medium text-gray-900">{entry.settlement_id || "—"}</p>
            </div>
          </div>
        </div>

        {/* Relations */}
        {entry.wallet && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4 md:col-span-2">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Wallet Details
            </h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">User ID</p>
                <p className="font-medium text-gray-900">{entry.wallet.user_id || "—"}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Owner Type</p>
                <p className="font-medium text-gray-900">{entry.wallet.owner_type || "—"}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Current Balance</p>
                <p className="font-bold text-indigo-600 text-lg">{fmtAmt(entry.wallet.balance)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Status</p>
                <p className="font-medium text-gray-900">{entry.wallet.status}</p>
              </div>
              {entry.wallet.platform_money !== undefined && entry.wallet.platform_money !== null && (
                <div>
                  <p className="text-xs text-gray-500 mb-1">Platform Money</p>
                  <p className="font-medium text-gray-900">{fmtAmt(entry.wallet.platform_money)}</p>
                </div>
              )}
            </div>
          </div>
        )}

        {entry.order && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Order Details
            </h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">Order ID</p>
                <p className="font-medium text-gray-900">#{entry.order.id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Order Number</p>
                <p className="font-medium text-gray-900">{entry.order.order_number}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Type</p>
                <p className="font-medium text-xs bg-gray-100 inline-block px-2.5 py-1 rounded-full text-gray-700">{entry.order.type}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Status</p>
                <p className="font-medium text-xs bg-gray-100 inline-block px-2.5 py-1 rounded-full text-gray-700">{entry.order.status}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Payable Amount</p>
                <p className="font-medium text-gray-900">{fmtAmt(entry.order.payable_amount)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Payment Method</p>
                <p className="font-medium text-gray-900">{entry.order.payment_method}</p>
              </div>
            </div>
          </div>
        )}

        {entry.penalty && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Penalty Details
            </h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">Penalty ID</p>
                <p className="font-medium text-gray-900">#{entry.penalty.id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Amount</p>
                <p className="font-bold text-red-600">{fmtAmt(entry.penalty.amount)}</p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-gray-500 mb-1">Reason</p>
                <p className="text-sm bg-gray-50 p-3 rounded-xl border border-gray-100">{entry.penalty.reason}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Is Paid</p>
                <p className="font-medium text-gray-900">{entry.penalty.is_paid ? "Yes" : "No"}</p>
              </div>
            </div>
          </div>
        )}

        {entry.unpaidCommission && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Unpaid Commission
            </h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">Commission ID</p>
                <p className="font-medium text-gray-900">#{entry.unpaidCommission.id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Amount</p>
                <p className="font-medium text-gray-900">{fmtAmt(entry.unpaidCommission.amount)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Is Paid</p>
                <p className="font-medium text-gray-900">{entry.unpaidCommission.is_paid ? "Yes" : "No"}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Created At</p>
                <p className="text-sm text-gray-900">{fmtDate(entry.unpaidCommission.created_at)}</p>
              </div>
            </div>
          </div>
        )}

        {entry.customerCoupon && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Customer Coupon
            </h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">Coupon ID</p>
                <p className="font-medium text-gray-900">#{entry.customerCoupon.id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Code</p>
                <p className="font-medium text-gray-900">{entry.customerCoupon.code}</p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-gray-500 mb-1">Title</p>
                <p className="font-medium text-gray-900">{lang === "AR" ? entry.customerCoupon.title_ar : entry.customerCoupon.title}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Type</p>
                <p className="font-medium text-gray-900">{entry.customerCoupon.type}</p>
              </div>
              {entry.customerCoupon.wallet_amount_cents !== null && (
                <div>
                  <p className="text-xs text-gray-500 mb-1">Wallet Amount</p>
                  <p className="font-medium text-gray-900">{fmtAmt(entry.customerCoupon.wallet_amount_cents)}</p>
                </div>
              )}
            </div>
          </div>
        )}

        {entry.courierCoupon && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Courier Coupon
            </h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">Coupon ID</p>
                <p className="font-medium text-gray-900">#{entry.courierCoupon.id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Bonus Fee</p>
                <p className="font-medium text-gray-900">{entry.courierCoupon.bonus_courier_fee}</p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-gray-500 mb-1">Title</p>
                <p className="font-medium text-gray-900">{lang === "AR" ? entry.courierCoupon.title_ar : entry.courierCoupon.title}</p>
              </div>
            </div>
          </div>
        )}

        {entry.settlement && (
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm space-y-4 md:col-span-2">
            <h2 className="text-lg font-bold text-gray-900 border-b border-gray-100 pb-3">
              Settlement Document Details
            </h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <p className="text-xs text-gray-500 mb-1">Settlement ID</p>
                <p className="font-medium text-gray-900">#{entry.settlement.id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Total Amount</p>
                <p className="font-bold text-indigo-600 text-lg">{fmtAmt(entry.settlement.total_amount)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Processed By</p>
                <p className="font-medium text-gray-900">{entry.settlement.processed_by || "—"}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500 mb-1">Wallets Count</p>
                <p className="font-medium text-gray-900">{entry.settlement.wallets_count}</p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-gray-500 mb-1">Period</p>
                <p className="font-medium text-sm text-gray-900">
                  {fmtDate(entry.settlement.period_from)} to {fmtDate(entry.settlement.period_to)}
                </p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-gray-500 mb-1">Note</p>
                <p className="text-sm text-gray-800 bg-gray-50 p-3 rounded-xl border border-gray-100">{entry.settlement.note || "—"}</p>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
