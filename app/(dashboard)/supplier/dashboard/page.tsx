"use client";
import { useQuery } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useRole } from "@/hooks/useRole";
import { getCurrentUserId } from "@/lib/auth";
import { useT } from "@/contexts/LanguageContext";
import {
  ShoppingCart, TrendingUp, Star, Package,
  CheckCircle, Clock, XCircle, Loader2, RefreshCw,
} from "lucide-react";
import { cn } from "@/lib/utils";

function fmt(n: number) { return `${(n / 100).toFixed(2)} EGP`; }

function StatCard({ label, value, icon: Icon, color }: {
  label: string; value: string | number; icon: React.ElementType; color: string;
}) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
      <div className={cn("w-12 h-12 rounded-xl flex items-center justify-center shrink-0", color)}>
        <Icon size={22} />
      </div>
      <div>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
        <p className="text-sm text-gray-500">{label}</p>
      </div>
    </div>
  );
}

export default function SupplierDashboardPage() {
  const { user } = useRole();
  const userId = user?.id ?? getCurrentUserId();
  const { t, isRTL } = useT();

  const { data: stats, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["supplier-stats"],
    queryFn: async () => {
      const res = await supplierApi.get("/stat/all-stat");
      return res.data?.data ?? res.data;
    },
    staleTime: 2 * 60 * 1000,
  });

  const { data: profile } = useQuery({
    queryKey: ["supplier-profile", userId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/get-profile/${userId}`);
      return res.data?.data?.user ?? res.data?.data;
    },
    enabled: !!userId,
    staleTime: 5 * 60 * 1000,
  });

  // Destructure nested API sections
  const rev  = stats?.revenue_stats  ?? {};
  const ord  = stats?.order_stats    ?? {};
  const prod = stats?.product_stats  ?? {};
  const rev_ = stats?.review_stats   ?? {};

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {t("sp.dashboard.welcome")}, {user?.full_name ?? "Supplier"} 👋
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">{t("sp.dashboard.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
          {t("sp.dashboard.refresh")}
        </button>
      </div>

      {/* Approval status banner */}
      {profile?.supplier && !profile.supplier.is_approved && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 flex items-center gap-3">
          <Clock size={18} className="text-amber-600 shrink-0" />
          <div>
            <p className="text-sm font-medium text-amber-800">{t("sp.dashboard.pendingApproval")}</p>
            <p className="text-xs text-amber-600 mt-0.5">{t("sp.dashboard.pendingMsg")}</p>
          </div>
        </div>
      )}

      {/* Top stats */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="bg-white rounded-xl border border-gray-200 p-5 h-24 animate-pulse bg-gray-100" />
          ))}
        </div>
      ) : stats ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard label={t("sp.dashboard.totalOrders")}    value={ord.total_orders  ?? "—"}                                          icon={ShoppingCart} color="bg-indigo-50 text-indigo-600" />
          <StatCard label={t("sp.dashboard.totalRevenue")}   value={rev.total_revenue  != null ? fmt(rev.total_revenue)  : "—"}        icon={TrendingUp}   color="bg-green-50 text-green-600" />
          <StatCard label={t("sp.dashboard.avgRating")}      value={rev_.overall_avg_rating != null ? rev_.overall_avg_rating.toFixed(1) + " ★" : "—"} icon={Star} color="bg-yellow-50 text-yellow-600" />
          <StatCard label={t("sp.dashboard.activeProducts")} value={prod.active_products ?? prod.total_products ?? "—"}                icon={Package}      color="bg-purple-50 text-purple-600" />
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            t("sp.dashboard.totalOrders"),
            t("sp.dashboard.totalRevenue"),
            t("sp.dashboard.avgRating"),
            t("sp.dashboard.activeProducts"),
          ].map((label, i) => (
            <StatCard key={label} label={label} value="—"
              icon={[ShoppingCart, TrendingUp, Star, Package][i]}
              color={["bg-indigo-50 text-indigo-600","bg-green-50 text-green-600","bg-yellow-50 text-yellow-600","bg-purple-50 text-purple-600"][i]} />
          ))}
        </div>
      )}

      {/* Order status breakdown */}
      {stats && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-base font-semibold text-gray-900 mb-4">{t("sp.dashboard.ordersByStatus")}</h2>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[
              { label: t("sp.dashboard.delivered"),   value: ord.delivered_orders   ?? 0, icon: CheckCircle, color: "text-green-600 bg-green-50" },
              { label: t("sp.dashboard.pending"),     value: ord.pending_orders     ?? 0, icon: Clock,        color: "text-amber-600 bg-amber-50" },
              { label: t("sp.dashboard.inProgress"),  value: ord.in_progress_orders ?? 0, icon: Loader2,      color: "text-blue-600 bg-blue-50" },
              { label: t("sp.dashboard.cancelled"),   value: ord.cancelled_orders   ?? 0, icon: XCircle,      color: "text-red-600 bg-red-50" },
            ].map(({ label, value, icon: Icon, color }) => {
              const [textColor, bgColor] = color.split(" ");
              return (
                <div key={label} className={cn("rounded-xl p-4 flex items-center gap-3", bgColor)}>
                  <Icon size={20} className={textColor} />
                  <div>
                    <p className="text-xl font-bold text-gray-900">{value}</p>
                    <p className="text-xs text-gray-500">{label}</p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Profile snapshot */}
      {profile && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-base font-semibold text-gray-900 mb-4">{t("sp.dashboard.storeProfile")}</h2>
          <div className="flex items-center gap-4">
            {profile.personal_photo ? (
              <img src={profile.personal_photo} alt={profile.full_name} className="w-16 h-16 rounded-xl object-cover border border-gray-200" />
            ) : (
              <div className="w-16 h-16 rounded-xl bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-2xl border border-gray-200">
                {profile.full_name?.[0] ?? "S"}
              </div>
            )}
            <div>
              <p className="text-lg font-semibold text-gray-900">{profile.full_name}</p>
              <p className="text-sm text-gray-500">{profile.phone}</p>
              <span className={cn(
                "inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-medium mt-1",
                profile.supplier?.is_approved ? "bg-green-100 text-green-700" : "bg-amber-100 text-amber-700"
              )}>
                {profile.supplier?.is_approved ? `✓ ${t("sp.dashboard.approved")}` : `⏳ ${t("sp.dashboard.pendingBadge")}`}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
