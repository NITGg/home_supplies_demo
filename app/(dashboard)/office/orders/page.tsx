"use client";
import { useState, useEffect, Suspense } from "react"; // Added Suspense
import { useQuery } from "@tanstack/react-query";
import { useSearchParams, useRouter } from "next/navigation";
import api from "@/lib/api";
import { fetchCourierOffices } from "@/lib/courier-offices";
import { useRole } from "@/hooks/useRole";
import { OrdersResponse } from "@/lib/orders";
import {
  ShoppingCart,
  RefreshCw,
  Search,
  ChevronLeft,
  ChevronRight,
  TrendingUp,
  User,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";

const STATUS_STYLES: Record<string, string> = {
  PENDING: "bg-amber-100 text-amber-700",
  IN_PROGRESS: "bg-blue-100 text-blue-700",
  DELIVERED: "bg-green-100 text-green-700",
  CANCELLED: "bg-red-100 text-red-700",
  EXPIRED: "bg-gray-100 text-gray-600",
  SEARCHING_FAILED: "bg-orange-100 text-orange-700",
};

function fmt(cents: number) {
  return `${(cents / 100).toFixed(2)} EGP`;
}

// ── 1. The Wrapper Export containing the Suspense Boundary ────────────────
export default function OfficeOrdersPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[400px]">
          <RefreshCw size={32} className="animate-spin text-indigo-500" />
        </div>
      }
    >
      <OfficeOrdersContent />
    </Suspense>
  );
}

// ── 2. The Content Component (Safe from CSR Bailout errors) ─────────────────
function OfficeOrdersContent() {
  const { user } = useRole();
  const searchParams = useSearchParams();
  const router = useRouter();

  // ── URL params ─────────────────────────────────────────────────────────────
  const urlCourierId = searchParams.get("courier_id") ?? "";
  const urlDateFrom = searchParams.get("date_from") ?? "";
  const urlDateTo = searchParams.get("date_to") ?? "";

  // ── Filter state ───────────────────────────────────────────────────────────
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [courierId, setCourierId] = useState(urlCourierId);
  const [dateFrom, setDateFrom] = useState(urlDateFrom);
  const [dateTo, setDateTo] = useState(urlDateTo);
  const [page, setPage] = useState(1);
  const limit = 25;

  useEffect(() => {
    setCourierId(searchParams.get("courier_id") ?? "");
    setDateFrom(searchParams.get("date_from") ?? "");
    setDateTo(searchParams.get("date_to") ?? "");
    setPage(1);
  }, [searchParams]);

  function pushUrl(next: {
    courier_id?: string;
    date_from?: string;
    date_to?: string;
  }) {
    const p = new URLSearchParams(searchParams.toString());
    Object.entries(next).forEach(([k, v]) => (v ? p.set(k, v) : p.delete(k)));
    router.replace(`?${p.toString()}`);
  }

  // ── Office couriers — used to always scope the orders query ───────────────
  const { data: officesData } = useQuery({
    queryKey: ["my-office", user?.id],
    queryFn: () =>
      fetchCourierOffices({ includes: "couriers", limit: 100 } as any),
    enabled: !!user?.id,
    staleTime: 5 * 60 * 1000,
  });

  const myOffice =
    officesData?.couriers?.find((o: any) =>
      (o.couriers as any[])?.some((c: any) => c.user_id === user?.id),
    ) ?? null;

  // All courier IDs in this office
  const officeCourierIds: number[] = ((myOffice?.couriers as any[]) ?? []).map(
    (c: any) => c.id,
  );

  // ── Earnings — dedicated endpoint ──────────────────────────────────────────
  const earningsParams: Record<string, string> = {};
  if (courierId) earningsParams["courier_id"] = courierId;
  if (dateFrom)
    earningsParams["created_at[gte]"] = new Date(dateFrom).toISOString();
  if (dateTo)
    earningsParams["created_at[lte]"] = new Date(
      `${dateTo}T23:59:59`,
    ).toISOString();

  const { data: earningsData } = useQuery({
    queryKey: ["office-earnings", courierId, dateFrom, dateTo, user?.id],
    queryFn: async () => {
      const res = await api.get("/admin/courier-office/earnings", {
        params: earningsParams,
      });
      return res.data?.data;
    },
    enabled: !!user?.id,
    staleTime: 30_000,
  });

  // ── Orders (paginated) ─────────────────────────────────────────────────────
  // Always scope to this office's couriers; narrow to a single courier when selected
  // ── Orders (paginated) ─────────────────────────────────────────────────────

  const officeCourierIdsExceptMe = ((myOffice?.couriers as any[]) ?? [])
    .filter((c: any) => c.user_id !== user?.id)
    .map((c: any) => c.id);

  const activeCourierIds = courierId
    ? [Number(courierId)]
    : officeCourierIdsExceptMe;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: [
      "office-orders",
      page,
      search,
      status,
      courierId,
      dateFrom,
      dateTo,
      user?.id,
      officeCourierIdsExceptMe,
    ],
    queryFn: async () => {
      const params: Record<string, any> = {
        limit,
        skip: (page - 1) * limit,
        includes: "customer,courier.user",
        items: "courier.user.full_name",
        ...(search && { keyword: search }),
        ...(status && { status }),
        // Fix how array values are formatted depending on your backend expectation:
        ...(activeCourierIds.length > 0 && {
          // If your backend handles arrays cleanly via standard Axios serialization params:
          "courier_id[in]": activeCourierIds,

          // OR if your backend specifically requires a comma-separated string WITHOUT square brackets:
          // "courier_id[in]": activeCourierIds.join(","),
        }),
        ...(dateFrom && {
          "created_at[gte]": new Date(dateFrom).toISOString(),
        }),
        ...(dateTo && {
          "created_at[lte]": new Date(`${dateTo}T23:59:59`).toISOString(),
        }),
      };
      const res = await api.get<OrdersResponse>("/admin/orders", { params });
      return res.data;
    },
    enabled: !!user?.id && officeCourierIdsExceptMe.length > 0,
    staleTime: 30_000,
  });

  const orders: any[] = data?.orders ?? [];
  const total: number = data?.totalOrders ?? orders.length;
  const totalPages = Math.ceil(total / limit);

  const isFiltered = !!(courierId || dateFrom || dateTo);

  const earningsCents = earningsData?.earnings_cents ?? 0;
  const deliveredCount = earningsData?.delivered_count ?? 0;
  const commissionType = earningsData?.commission_type ?? "FIXED_PER_ORDER";
  const commissionValue = earningsData?.commission_value ?? 0;

  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <ShoppingCart size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">Office Orders</h1>
            <p className="text-xs text-gray-500">
              {total.toLocaleString()} orders
              {courierId && ` · courier #${courierId}`}
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

      {/* Active courier badge */}
      {courierId && (
        <div className="flex items-center gap-2">
          <span className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50 border border-indigo-200 text-indigo-700 rounded-full text-xs font-medium">
            <User size={12} />
            Courier #{courierId}
            <button
              onClick={() => {
                setCourierId("");
                setPage(1);
                pushUrl({
                  courier_id: "",
                  date_from: dateFrom,
                  date_to: dateTo,
                });
              }}
              className="ml-1 hover:text-indigo-900"
            >
              <X size={11} />
            </button>
          </span>
        </div>
      )}

      {/* Earnings card */}
      <div
        className={cn(
          "rounded-xl border p-4 flex items-center gap-4",
          isFiltered
            ? "bg-indigo-50 border-indigo-200"
            : "bg-green-50 border-green-200",
        )}
      >
        <div
          className={cn(
            "p-3 rounded-xl",
            isFiltered ? "bg-indigo-100" : "bg-green-100",
          )}
        >
          <TrendingUp
            size={20}
            className={isFiltered ? "text-indigo-600" : "text-green-600"}
          />
        </div>
        <div>
          <p className="text-xs font-medium text-gray-500 mb-0.5">
            {isFiltered ? "Filtered Earnings" : "Total Earnings"} (
            {deliveredCount} delivered)
          </p>
          <p
            className={cn(
              "text-2xl font-bold",
              isFiltered ? "text-indigo-700" : "text-green-700",
            )}
          >
            {fmt(earningsCents)}
          </p>
          <p className="text-xs text-gray-400 mt-0.5">
            Commission:{" "}
            {commissionType === "FIXED_PER_ORDER"
              ? `${fmt(commissionValue)} / order`
              : `${commissionValue}% of courier fee`}
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder="Search orders…"
            className="pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 w-56"
          />
        </div>

        <select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          className="border border-gray-200 rounded-lg text-sm px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-500"
        >
          <option value="">All Statuses</option>
          {Object.keys(STATUS_STYLES).map((s) => (
            <option key={s} value={s}>
              {s.replace(/_/g, " ")}
            </option>
          ))}
        </select>

        {/* Date range */}
        <div className="flex items-center gap-2">
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => {
              setDateFrom(e.target.value);
              setPage(1);
              pushUrl({
                courier_id: courierId,
                date_from: e.target.value,
                date_to: dateTo,
              });
            }}
            className="border border-gray-200 rounded-lg text-sm px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <span className="text-gray-400 text-sm">→</span>
          <input
            type="date"
            value={dateTo}
            onChange={(e) => {
              setDateTo(e.target.value);
              setPage(1);
              pushUrl({
                courier_id: courierId,
                date_from: dateFrom,
                date_to: e.target.value,
              });
            }}
            className="border border-gray-200 rounded-lg text-sm px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-500"
          />
          {(dateFrom || dateTo) && (
            <button
              onClick={() => {
                setDateFrom("");
                setDateTo("");
                setPage(1);
                pushUrl({ courier_id: courierId, date_from: "", date_to: "" });
              }}
              className="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg"
            >
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-16">
            <RefreshCw size={24} className="animate-spin text-indigo-400" />
          </div>
        ) : orders.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <ShoppingCart size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No orders found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                {["ID", "Courier", "Courier Fee", "Status", "Date"].map((h) => (
                  <th
                    key={h}
                    className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.map((o: any) => (
                <tr key={o.id} className="hover:bg-gray-50 transition">
                  <td className="px-4 py-3 font-mono text-xs">#{o.id}</td>
                  <td className="px-4 py-3 text-gray-600">
                    {o.courier?.user?.full_name ?? o.courier?.full_name ?? "—"}
                  </td>
                  <td className="px-4 py-3 font-medium">
                    {o.courier_fee != null ? fmt(o.courier_fee) : "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={cn(
                        "px-2 py-0.5 rounded-full text-xs font-medium",
                        STATUS_STYLES[o.status] ?? "bg-gray-100 text-gray-700",
                      )}
                    >
                      {o.status?.replace(/_/g, " ")}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-500">
                    {o.created_at
                      ? new Date(o.created_at).toLocaleDateString()
                      : "—"}
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
