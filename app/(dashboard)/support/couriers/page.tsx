"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api";
import { fetchUsers } from "@/lib/users";
import {
  Truck,
  RefreshCw,
  Search,
  ChevronLeft,
  ChevronRight,
  Phone,
  CheckCircle,
  XCircle,
  Wifi,
  WifiOff,
} from "lucide-react";
import { cn } from "@/lib/utils";

export default function SupportCouriersPage() {
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<"all" | "online">("all");
  const [page, setPage] = useState(1);
  const limit = 25;

  // All couriers (paginated)
  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["support-couriers", search, page],
    queryFn: () =>
      fetchUsers({
        limit,
        skip: (page - 1) * limit,
        role_id: 2, // Courier role
        includes: "courier,wallet",
        ...(search ? { search } : {}),
      }),
    staleTime: 30_000,
  });

  // Online couriers list (for badge)
  const { data: onlineData } = useQuery({
    queryKey: ["online-couriers-set"],
    queryFn: async () => {
      const res = await api.get("/users/online-couriers");
      return res.data?.online_courier_ids?.couriers ?? res.data?.couriers ?? [];
    },
    staleTime: 60_000,
    refetchInterval: 60_000,
  });

  const onlineIds = new Set<number>((onlineData ?? []).map((c: any) => c.user.id));

  let users = data?.users ?? [];
  if (filter === "online")
    users = users.filter((u: any) => onlineIds.has(u.id));

  const total =
    filter === "online" ? users.length : (data?.totalUsers ?? users.length);
  const totalPages = filter === "online" ? 1 : Math.ceil(total / limit);

  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <Truck size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">Couriers</h1>
            <p className="text-xs text-gray-500">
              {total.toLocaleString()} couriers ·{" "}
              <span className="text-green-600 font-medium">
                {onlineIds.size} online
              </span>
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
            placeholder="Name or phone…"
            className="pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 w-56"
          />
        </div>
        <div className="flex bg-gray-100 rounded-lg p-0.5 gap-0.5">
          {(["all", "online"] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={cn(
                "px-3 py-1.5 text-xs font-medium rounded-md transition capitalize",
                filter === f
                  ? "bg-white text-indigo-700 shadow-sm"
                  : "text-gray-500 hover:text-gray-700",
              )}
            >
              {f === "online" ? "🟢 Online only" : "All"}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-16">
            <RefreshCw size={24} className="animate-spin text-indigo-400" />
          </div>
        ) : users.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <Truck size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No couriers found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                {[
                  "Courier",
                  "Phone",
                  "Online",
                  "Approved",
                  "Vehicle",
                  "Wallet",
                ].map((h) => (
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
              {users.map((u: any) => {
                const isOnline = onlineIds.has(u.id);
                const isApproved = u.courier?.is_approved;
                return (
                  <tr key={u.id} className="hover:bg-gray-50 transition">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {u.personal_photo ? (
                          <img
                            src={u.personal_photo}
                            alt={u.full_name}
                            className="w-8 h-8 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-8 h-8 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-xs">
                            {u.full_name?.[0] ?? "C"}
                          </div>
                        )}
                        <div>
                          <p className="font-medium text-gray-900 text-sm">
                            {u.full_name}
                          </p>
                          <p className="text-xs text-gray-400">#{u.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      {u.phone ? (
                        <a
                          href={`tel:${u.phone}`}
                          className="flex items-center gap-1 text-sm text-gray-700 hover:text-green-600"
                        >
                          <Phone size={12} />
                          {u.phone}
                        </a>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={cn(
                          "flex items-center gap-1 text-xs font-medium w-fit",
                          isOnline ? "text-green-600" : "text-gray-400",
                        )}
                      >
                        {isOnline ? <Wifi size={12} /> : <WifiOff size={12} />}
                        {isOnline ? "Online" : "Offline"}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={cn(
                          "flex items-center gap-1 text-xs font-medium w-fit",
                          isApproved ? "text-green-600" : "text-amber-600",
                        )}
                      >
                        {isApproved ? (
                          <CheckCircle size={12} />
                        ) : (
                          <XCircle size={12} />
                        )}
                        {isApproved ? "Approved" : "Pending"}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-600">
                      {u.courier?.vehicle_type ?? "—"}
                    </td>
                    <td className="px-4 py-3 text-xs font-medium text-gray-700">
                      {u.wallet?.balance != null
                        ? `${Number(u.wallet.balance).toFixed(2)} EGP`
                        : "—"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {totalPages > 1 && filter !== "online" && (
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
