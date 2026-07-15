"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api";
import { useRole } from "@/hooks/useRole";
import {
  DollarSign,
  RefreshCw,
  TrendingUp,
  Truck,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { cn } from "@/lib/utils";

// All monetary values from the API are in cents
function fmt(cents: number) {
  return `${(cents / 100).toFixed(2)} EGP`;
}

type Period = "week" | "month" | "year";

export default function OfficeEarningsPage() {
  const { user } = useRole();
  const [period, setPeriod] = useState<Period>("month");
  const [page, setPage] = useState(1);
  const limit = 20;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["office-couriers-earnings", period, page, user?.id],
    queryFn: async () => {
      const res = await api.get("/admin/courier-office/couriers-earnings", {
        params: { period, limit, skip: (page - 1) * limit },
      });
      return res.data?.data;
    },
    enabled: !!user?.id,
    staleTime: 2 * 60 * 1000,
  });

  const summary = data?.summary ?? {};
  const couriers: any[] = data?.couriers ?? [];
  const total = data?.total ?? couriers.length;
  const totalPages = Math.ceil(total / limit);

  const commissionType = summary.commission_type ?? "FIXED_PER_ORDER";
  const commissionValue = summary.commission_value ?? 0;

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <DollarSign size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">Earnings</h1>
            <p className="text-xs text-gray-500">
              Per-courier breakdown for your office
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex bg-gray-100 rounded-lg p-0.5 gap-0.5">
            {(["week", "month", "year"] as Period[]).map((p) => (
              <button
                key={p}
                onClick={() => {
                  setPeriod(p);
                  setPage(1);
                }}
                className={cn(
                  "px-3 py-1.5 text-xs font-medium rounded-md transition capitalize",
                  period === p
                    ? "bg-white text-indigo-700 shadow-sm"
                    : "text-gray-500 hover:text-gray-700",
                )}
              >
                {p}
              </button>
            ))}
          </div>
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50"
          >
            <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
          </button>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[
          {
            label: "Total Earnings",
            value:
              summary.total_earnings_cents != null
                ? fmt(summary.total_earnings_cents)
                : "—",
            icon: TrendingUp,
            color: "bg-green-50 text-green-600",
          },
          {
            label: "Delivered Orders",
            value: summary.total_delivered ?? "—",
            icon: DollarSign,
            color: "bg-indigo-50 text-indigo-600",
          },
          {
            label: "Active Couriers",
            value: summary.active_couriers ?? "—",
            icon: Truck,
            color: "bg-purple-50 text-purple-600",
          },
        ].map(({ label, value, icon: Icon, color }) => (
          <div
            key={label}
            className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4"
          >
            <div
              className={cn(
                "w-11 h-11 rounded-xl flex items-center justify-center shrink-0",
                color,
              )}
            >
              <Icon size={20} />
            </div>
            <div>
              <p className="text-xl font-bold text-gray-900">
                {isLoading ? "…" : value}
              </p>
              <p className="text-sm text-gray-500">{label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Commission info */}
      <div className="text-xs text-gray-500 bg-gray-50 border border-gray-200 rounded-lg px-4 py-2">
        Commission model:{" "}
        <span className="font-medium text-gray-700">
          {commissionType === "FIXED_PER_ORDER"
            ? `${fmt(commissionValue)} per delivered order`
            : `${commissionValue}% of courier fee`}
        </span>
      </div>

      {/* Per-courier table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-100">
          <h2 className="text-base font-semibold text-gray-900">
            Per-Courier Earnings
          </h2>
        </div>
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <RefreshCw size={22} className="animate-spin text-indigo-400" />
          </div>
        ) : couriers.length === 0 ? (
          <div className="text-center py-12 text-gray-400 text-sm">
            No data for this period
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                {["Courier", "Delivered", "Courier Fee", "Earnings"].map(
                  (h) => (
                    <th
                      key={h}
                      className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase"
                    >
                      {h}
                    </th>
                  ),
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {couriers.map((c: any) => (
                <tr key={c.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      {c.personal_photo ? (
                        <img
                          src={c.personal_photo}
                          alt={c.full_name}
                          className="w-7 h-7 rounded-full object-cover"
                        />
                      ) : (
                        <div className="w-7 h-7 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-xs">
                          {c.full_name?.[0]}
                        </div>
                      )}
                      <p className="font-medium text-gray-900">
                        {c.full_name ?? "—"}
                      </p>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-gray-700">
                    {c.delivered_count ?? 0}
                  </td>
                  <td className="px-4 py-3 text-gray-600">
                    {c.courier_fee_total_cents != null
                      ? fmt(c.courier_fee_total_cents)
                      : "—"}
                  </td>
                  <td className="px-4 py-3 font-semibold text-gray-900">
                    {c.earnings_cents != null ? fmt(c.earnings_cents) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-gray-500">
            Page {page} of {totalPages}
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
