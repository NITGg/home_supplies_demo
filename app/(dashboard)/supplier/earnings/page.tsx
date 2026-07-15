"use client";
import { useQuery } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import { TrendingUp, RefreshCw, DollarSign, ShoppingCart, Package } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from "recharts";

function fmt(n: number) { return `${(n / 100).toFixed(2)} EGP`; }

export default function SupplierEarningsPage() {
  const { t, isRTL } = useT();

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["supplier-all-stat"],
    queryFn: async () => {
      const res = await supplierApi.get("/stat/all-stat");
      return res.data?.data ?? res.data;
    },
    staleTime: 2 * 60 * 1000,
  });

  // Destructure the nested sections from the API response
  const rev = data?.revenue_stats ?? {};
  const ord = data?.order_stats ?? {};
  const prod = data?.product_stats ?? {};

  const chartData = data
    ? [
        { label: t("sp.earnings.today"),  earnings: rev.today_revenue      ?? 0 },
        { label: t("sp.earnings.week"),   earnings: rev.this_week_revenue  ?? 0 },
        { label: t("sp.earnings.month"),  earnings: rev.this_month_revenue ?? 0 },
        { label: t("sp.earnings.allTime"), earnings: rev.total_revenue     ?? 0 },
      ]
    : [];

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <TrendingUp size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">{t("sp.earnings.title")}</h1>
            <p className="text-xs text-gray-500">{t("sp.earnings.subtitle")}</p>
          </div>
        </div>
        <button onClick={() => refetch()} disabled={isFetching}
          className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[
          {
            label: t("sp.earnings.totalRevenue"),
            value: rev.total_revenue != null ? fmt(rev.total_revenue) : "—",
            icon: DollarSign,
            color: "bg-green-50 text-green-600",
          },
          {
            label: t("sp.earnings.totalOrders"),
            value: ord.total_orders ?? "—",
            icon: ShoppingCart,
            color: "bg-indigo-50 text-indigo-600",
          },
          {
            label: t("sp.earnings.activeProducts"),
            value: prod.active_products ?? prod.total_products ?? "—",
            icon: Package,
            color: "bg-purple-50 text-purple-600",
          },
        ].map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
            <div className={cn("w-11 h-11 rounded-xl flex items-center justify-center shrink-0", color)}>
              <Icon size={20} />
            </div>
            <div>
              <p className="text-xl font-bold text-gray-900">{isLoading ? "…" : value}</p>
              <p className="text-sm text-gray-500">{label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Revenue breakdown chart */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="text-base font-semibold text-gray-900 mb-4">{t("sp.earnings.breakdown")}</h2>
        {isLoading ? (
          <div className="flex items-center justify-center h-48">
            <RefreshCw size={24} className="animate-spin text-indigo-400" />
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={chartData} margin={{ top: 4, right: 8, left: -10, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
              <XAxis dataKey="label" tick={{ fontSize: 11, fill: "#9ca3af" }} />
              <YAxis tick={{ fontSize: 11, fill: "#9ca3af" }} allowDecimals={false}
                tickFormatter={(v) => `${(v / 100).toFixed(0)}`} />
              <Tooltip
                contentStyle={{ borderRadius: 8, border: "1px solid #e5e7eb", fontSize: 12 }}
                formatter={(v) => [fmt(Number(v ?? 0)), t("sp.earnings.revenue")]}
              />
              <Bar dataKey="earnings" fill="#6366f1" radius={[4, 4, 0, 0]} maxBarSize={56} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      {/* Period breakdown table */}
      {data && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="text-base font-semibold text-gray-900">{t("sp.earnings.periodStats")}</h2>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                {[t("sp.earnings.period"), t("sp.earnings.revenue"), t("sp.earnings.orders")].map((h) => (
                  <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {[
                { period: t("sp.earnings.today"),   revenue: rev.today_revenue,      orders: ord.today_orders },
                { period: t("sp.earnings.week"),    revenue: rev.this_week_revenue,  orders: ord.this_week_orders },
                { period: t("sp.earnings.month"),   revenue: rev.this_month_revenue, orders: ord.this_month_orders },
                { period: t("sp.earnings.year"),    revenue: rev.this_year_revenue,  orders: ord.this_year_orders },
                { period: t("sp.earnings.allTime"), revenue: rev.total_revenue,      orders: ord.total_orders },
              ].map((row) => (
                <tr key={row.period} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-700 font-medium">{row.period}</td>
                  <td className="px-4 py-3 font-semibold text-indigo-700">{row.revenue != null ? fmt(row.revenue) : "—"}</td>
                  <td className="px-4 py-3 text-gray-600">{row.orders ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
