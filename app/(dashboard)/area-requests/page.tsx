"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchAreaRequests,
  fetchAreaRequestStats,
  deleteAreaRequest,
  type AreaRequest,
} from "@/lib/area-requests";
import { useT } from "@/contexts/LanguageContext";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import {
  AlertTriangle,
  Search,
  Trash2,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  MapPin,
  Truck,
} from "lucide-react";
import toast from "react-hot-toast";

type Column<T> = {
  key: string;
  label: string;
  sortable?: boolean;
  align?: "left" | "center" | "right";
  getValue?: (row: T) => unknown;
  render?: (row: T) => React.ReactNode;
};

type ColumnOption = {
  key: string;
  label: string;
  alwaysVisible?: boolean;
};

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

const ALL_COLUMN_KEYS = [
  "id",
  "request_type",
  "area",
  "governorate",
  "user",
  "created_at",
  "actions",
] as const;

export default function AreaRequestsPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:area-requests", [
    ...ALL_COLUMN_KEYS,
  ]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["area-requests", params],
    queryFn: () => fetchAreaRequests(params),
  });

  const { data: stats } = useQuery({
    queryKey: ["area-request-stats"],
    queryFn: fetchAreaRequestStats,
  });

  const allItems = data?.items ?? [];
  const items = allItems.filter((r) => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    return true;
  });

  const total = data?.total ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const displayTotal = createdFrom || createdTo ? items.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteAreaRequest(id),
    onSuccess: () => {
      toast.success(t("areaRequests.deleted"));
      qc.invalidateQueries({ queryKey: ["area-requests"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("areaRequests.deleteError")),
  });

  const allColumns: Column<AreaRequest>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: (r) => r.id,
      render: (r) => (
        <span className="text-xs font-mono text-gray-400">#{r.id}</span>
      ),
    },
    {
      key: "request_type",
      label: t("areaRequests.type"),
      sortable: true,
      getValue: (r) => r.request_type,
      render: (r) => (
        <span
          className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${r.request_type === "DELIVERY" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"}`}
        >
          {r.request_type === "DELIVERY" ? (
            <Truck size={11} />
          ) : (
            <MapPin size={11} />
          )}
          {r.request_type}
        </span>
      ),
    },
    {
      key: "area",
      label: t("areaRequests.area"),
      sortable: true,
      getValue: (r) => r.area,
      render: (r) => (
        <span className="font-medium text-gray-900">{r.area}</span>
      ),
    },
    {
      key: "governorate",
      label: t("areaRequests.governorate"),
      sortable: true,
      getValue: (r) => r.governorate,
      render: (r) => <span className="text-gray-600">{r.governorate}</span>,
    },
    {
      key: "user",
      label: "Customer",
      render: (r) =>
        r.customer ? (
          <div>
            <p className="text-gray-900">{r.customer.full_name}</p>
            <p className="text-xs text-gray-400">{r.customer.phone}</p>
          </div>
        ) : (
          <span>—</span>
        ),
    },
    {
      key: "created_at",
      label: t("areaRequests.requestedAt"),
      sortable: true,
      getValue: (r) => new Date(r.created_at),
      render: (r) => (
        <span className="text-gray-500 text-xs">{fmtDate(r.created_at)}</span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: (r) => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === r.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button
                onClick={() => deleteMut.mutate(r.id)}
                disabled={deleteMut.isPending}
                className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50"
              >
                {t("common.yes")}
              </button>
              <button
                onClick={() => setDelConfirm(null)}
                className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg"
              >
                {t("common.cancel")}
              </button>
            </>
          ) : (
            <button
              onClick={() => setDelConfirm(r.id)}
              className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"
            >
              <Trash2 size={15} />
            </button>
          )}
        </div>
      ),
    },
  ];

  const columns = allColumns.filter((c) => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map((c) => ({
    key: c.key,
    label: c.label,
    alwaysVisible: c.key === "actions",
  }));

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <AlertTriangle size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("areaRequests.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">{t("areaRequests.subtitle")}</p>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50"
        >
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />{" "}
          {t("common.refresh")}
        </button>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">
          {t("areaRequests.total")}
        </p>
      </div>

      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-white border border-gray-200 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">
              {t("areaRequests.byType")}
            </h3>
            <div className="space-y-2">
              {stats.data.byType.map((item, i) => (
                <div
                  key={`type-${i}-${item.name}`}
                  className="flex items-center justify-between"
                >
                  <span
                    className={`inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded font-medium ${item.name === "DELIVERY" ? "bg-blue-100 text-blue-700" : "bg-green-100 text-green-700"}`}
                  >
                    {item.name === "DELIVERY" ? (
                      <Truck size={11} />
                    ) : (
                      <MapPin size={11} />
                    )}
                    {item.name}
                  </span>
                  <span className="text-sm font-semibold text-indigo-700">
                    {item.count}
                  </span>
                </div>
              ))}
            </div>
          </div>
          <div className="bg-white border border-gray-200 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">
              {t("areaRequests.byGovernorate")}
            </h3>
            <div className="space-y-2 max-h-40 overflow-y-auto">
              {stats.data.byGovernorate.map((item, i) => (
                <div
                  key={`gov-${i}-${item.name}`}
                  className="flex items-center justify-between"
                >
                  <span className="text-sm text-gray-600">{item.name}</span>
                  <span className="text-sm font-semibold text-indigo-700">
                    {item.count}
                  </span>
                </div>
              ))}
            </div>
          </div>
          <div className="bg-white border border-gray-200 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">
              {t("areaRequests.topAreas")}
            </h3>
            <div className="space-y-2 max-h-40 overflow-y-auto">
              {stats.data.byArea.slice(0, 8).map((item, i) => (
                <div
                  key={`area-${i}-${item.name}`}
                  className="flex items-center justify-between"
                >
                  <span className="text-sm text-gray-600">{item.name}</span>
                  <span className="text-sm font-semibold text-indigo-700">
                    {item.count}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {stats?.data.topAreasPerGovernorate &&
        Object.keys(stats.data.topAreasPerGovernorate).length > 0 && (
          <div className="bg-white border border-gray-200 rounded-2xl p-5">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">
              {t("areaRequests.topAreasPerGovernorate")}
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {Object.entries(stats.data.topAreasPerGovernorate).map(
                ([gov, areas]) => (
                  <div key={gov} className="space-y-1">
                    <p className="text-xs font-semibold text-gray-900 border-b border-gray-100 pb-1">
                      {gov}
                    </p>
                    {areas.map((area) => (
                      <div
                        key={area.name}
                        className="flex justify-between text-xs"
                      >
                        <span className="text-gray-500 truncate">
                          {area.name}
                        </span>
                        <span className="font-medium ml-2">{area.count}</span>
                      </div>
                    ))}
                  </div>
                ),
              )}
            </div>
          </div>
        )}

      <div className="relative max-w-md">
        <Search
          size={15}
          className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
        />
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          placeholder={t("areaRequests.searchPlaceholder")}
          className="w-full pl-9 pr-4 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-900 focus:ring-2 focus:ring-indigo-500 outline-none"
        />
      </div>

      {isLoading && (
        <div className="text-center py-20 text-gray-400">
          {t("common.loading")}
        </div>
      )}
      {!isLoading && items.length === 0 && (
        <div className="text-center py-20 border-2 border-dashed border-gray-200 rounded-2xl">
          <AlertTriangle size={36} className="text-gray-300 mx-auto mb-3" />
          <p className="text-gray-400">{t("areaRequests.noResults")}</p>
        </div>
      )}

      {!isLoading && items.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50">
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areaRequests.type")}
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areaRequests.area")}
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areaRequests.governorate")}
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  Customer
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areaRequests.requestedAt")}
                </th>
                <th className="px-5 py-3.5 text-right text-xs font-semibold text-gray-500 uppercase">
                  {t("common.actions")}
                </th>
              </tr>
            </thead>
            <tbody>
              {items.map((r) => (
                <tr
                  key={r.id}
                  className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                >
                  <td className="px-5 py-3.5">
                    <span
                      className={`inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium ${r.request_type === "DELIVERY" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"}`}
                    >
                      {r.request_type === "DELIVERY" ? (
                        <Truck size={11} />
                      ) : (
                        <MapPin size={11} />
                      )}
                      {r.request_type}
                    </span>
                  </td>
                  <td className="px-5 py-3.5 font-medium text-gray-900">
                    {r.area}
                  </td>
                  <td className="px-5 py-3.5 text-gray-600">{r.governorate}</td>
                  <td className="px-5 py-3.5">
                    {r.customer ? (
                      <div>
                        <p className="text-gray-900">{r.customer.full_name}</p>
                        <p className="text-xs text-gray-400">
                          {r.customer.phone}
                        </p>
                      </div>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-5 py-3.5 text-gray-500 text-xs">
                    {fmtDate(r.created_at)}
                  </td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center justify-end gap-2">
                      {delConfirm === r.id ? (
                        <>
                          <span className="text-xs text-gray-600">Delete?</span>
                          <button
                            onClick={() => deleteMut.mutate(r.id)}
                            disabled={deleteMut.isPending}
                            className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50"
                          >
                            {t("common.yes")}
                          </button>
                          <button
                            onClick={() => setDelConfirm(null)}
                            className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg"
                          >
                            {t("common.cancel")}
                          </button>
                        </>
                      ) : (
                        <button
                          onClick={() => setDelConfirm(r.id)}
                          className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"
                        >
                          <Trash2 size={15} />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <span className="text-sm text-gray-500">
            {t("common.page")} {page} {t("common.of")} {totalPages}
          </span>
          <div className="flex gap-2">
            <button
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
              className="flex items-center gap-1.5 px-3 py-2 border border-gray-300 rounded-xl text-sm disabled:opacity-40 hover:bg-gray-50"
            >
              <ChevronLeft size={15} /> {t("common.previous")}
            </button>
            <button
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
              className="flex items-center gap-1.5 px-3 py-2 border border-gray-300 rounded-xl text-sm disabled:opacity-40 hover:bg-gray-50"
            >
              {t("common.next")} <ChevronRight size={15} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
