"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchAreas,
  createArea,
  updateArea,
  deleteArea,
  type Area,
  type Boundaries,
} from "@/lib/areas";
import { fetchGovernorates } from "@/lib/governorates";
import { useT } from "@/contexts/LanguageContext";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import {
  Map,
  Search,
  Plus,
  Pencil,
  Trash2,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  X,
  CheckCircle,
  XCircle,
  MapPin,
} from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";
import AreaBoundariesMap from "@/components/areas/AreaBoundariesMap";
import type { BoundariesRecord } from "@/components/areas/AreaBoundariesMap";

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

const ALL_COLUMN_KEYS = [
  "id",
  "name",
  "name_ar",
  "governorate",
  "is_active",
  "created_at",
  "updated_at",
  "actions",
] as const;

export default function AreasPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [filterGov, setFilterGov] = useState<string>("all");
  const [filterStatus, setFilterStatus] = useState<
    "all" | "active" | "inactive"
  >("all");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Area | null>(null);
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");

  const { visible, setVisible } = useColumnVisibility("cols:areas", [
    ...ALL_COLUMN_KEYS,
  ]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;
  if (filterGov !== "all") params.governorate_id = filterGov;
  if (filterStatus === "active") params.is_active = "true";
  if (filterStatus === "inactive") params.is_active = "false";

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["areas", params],
    queryFn: () => fetchAreas(params),
  });

  const { data: govData } = useQuery({
    queryKey: ["governorates-all"],
    queryFn: () => fetchGovernorates({ limit: 200 }),
  });

  const allAreas = data?.areas ?? [];
  const areas = allAreas.filter((a) => {
    if (createdFrom && new Date(a.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(a.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    if (updatedFrom && new Date(a.updated_at) < new Date(updatedFrom))
      return false;
    if (updatedTo && new Date(a.updated_at) > new Date(updatedTo + "T23:59:59"))
      return false;
    return true;
  });

  const total = data?.totalCount ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const govs = govData?.governorates ?? [];
  const displayTotal =
    createdFrom || createdTo || updatedFrom || updatedTo ? areas.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteArea(id),
    onSuccess: () => {
      toast.success(t("areas.deleted"));
      qc.invalidateQueries({ queryKey: ["areas"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("areas.deleteError")),
  });

  const allColumns: Column<Area>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: (a) => a.id,
      render: (a) => (
        <span className="text-xs font-mono text-gray-400">#{a.id}</span>
      ),
    },
    {
      key: "name",
      label: t("areas.nameEn"),
      sortable: true,
      getValue: (a) => a.name,
      render: (a) => (
        <span className="font-medium text-gray-900">{a.name}</span>
      ),
    },
    {
      key: "name_ar",
      label: t("areas.nameAr"),
      render: (a) => (
        <span className="text-gray-700" dir="rtl">
          {a.name_ar}
        </span>
      ),
    },
    {
      key: "governorate",
      label: t("areas.governorate"),
      sortable: true,
      getValue: (a) => a.governorate?.name ?? "",
      render: (a) => (
        <span className="text-gray-600 text-xs">
          {a.governorate?.name ?? `#${a.governorate_id}`}
        </span>
      ),
    },
    {
      key: "is_active",
      label: t("common.status"),
      sortable: true,
      getValue: (a) => (a.is_active ? 1 : 0),
      render: (a) =>
        a.is_active ? (
          <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700">
            <CheckCircle size={11} /> {t("common.active")}
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-gray-100 text-gray-500">
            <XCircle size={11} /> {t("common.inactive")}
          </span>
        ),
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: (a) => new Date(a.created_at),
      render: (a) => (
        <span className="text-xs text-gray-500">
          {new Date(a.created_at).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric",
          })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: (a) => new Date(a.updated_at),
      render: (a) => (
        <span className="text-xs text-gray-500">
          {new Date(a.updated_at).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric",
          })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: (a) => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === a.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button
                onClick={() => deleteMut.mutate(a.id)}
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
            <>
              <button
                onClick={() => {
                  setEditing(a);
                  setModalOpen(true);
                }}
                className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"
              >
                <Pencil size={15} />
              </button>
              <button
                onClick={() => setDelConfirm(a.id)}
                className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"
              >
                <Trash2 size={15} />
              </button>
            </>
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

  // Unused variables for column visibility feature - keeping for potential future use
  void columns;
  void columnOptions;
  void setVisible;

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Map size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("areas.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">{t("areas.subtitle")}</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50"
          >
            <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />{" "}
            {t("common.refresh")}
          </button>
          <button
            onClick={() => {
              setEditing(null);
              setModalOpen(true);
            }}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700"
          >
            <Plus size={16} /> {t("areas.new")}
          </button>
        </div>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">{t("areas.total")}</p>
      </div>

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[220px]">
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
            placeholder={t("areas.searchPlaceholder")}
            className="w-full pl-9 pr-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
          />
        </div>
        <select
          value={filterGov}
          onChange={(e) => {
            setFilterGov(e.target.value);
            setPage(1);
          }}
          className="input w-auto"
        >
          <option value="all">{t("areas.allGovernorates")}</option>
          {govs.map((g) => (
            <option key={g.id} value={g.id}>
              {g.name}
            </option>
          ))}
        </select>
        <select
          value={filterStatus}
          onChange={(e) => {
            setFilterStatus(e.target.value as typeof filterStatus);
            setPage(1);
          }}
          className="input w-auto"
        >
          <option value="all">{t("common.all")}</option>
          <option value="active">{t("common.active")}</option>
          <option value="inactive">{t("common.inactive")}</option>
        </select>
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-600">
            {t("common.createdAt")}:
          </span>
          <input
            type="date"
            value={createdFrom}
            onChange={(e) => {
              setCreatedFrom(e.target.value);
              setPage(1);
            }}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
          <span className="text-gray-400">-</span>
          <input
            type="date"
            value={createdTo}
            onChange={(e) => {
              setCreatedTo(e.target.value);
              setPage(1);
            }}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-600">
            {t("common.updatedAt")}:
          </span>
          <input
            type="date"
            value={updatedFrom}
            onChange={(e) => {
              setUpdatedFrom(e.target.value);
              setPage(1);
            }}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
          <span className="text-gray-400">-</span>
          <input
            type="date"
            value={updatedTo}
            onChange={(e) => {
              setUpdatedTo(e.target.value);
              setPage(1);
            }}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
          />
        </div>
      </div>

      {isLoading && (
        <div className="text-center py-20 text-gray-400">
          {t("common.loading")}
        </div>
      )}
      {!isLoading && areas.length === 0 && (
        <div className="text-center py-20 border-2 border-dashed border-gray-200 rounded-2xl">
          <Map size={36} className="text-gray-300 mx-auto mb-3" />
          <p className="text-gray-400">{t("areas.noResults")}</p>
        </div>
      )}

      {!isLoading && areas.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50">
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areas.nameEn")}
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areas.nameAr")}
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("areas.governorate")}
                </th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold text-gray-500 uppercase">
                  {t("common.status")}
                </th>
                <th className="px-5 py-3.5 text-right text-xs font-semibold text-gray-500 uppercase">
                  {t("common.actions")}
                </th>
              </tr>
            </thead>
            <tbody>
              {areas.map((a) => (
                <tr
                  key={a.id}
                  className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                >
                  <td className="px-5 py-3.5 font-medium text-gray-900">
                    {a.name}
                  </td>
                  <td className="px-5 py-3.5 text-gray-700" dir="rtl">
                    {a.name_ar}
                  </td>
                  <td className="px-5 py-3.5 text-gray-600 text-xs">
                    {a.governorate?.name ?? `#${a.governorate_id}`}
                  </td>
                  <td className="px-5 py-3.5">
                    {a.is_active ? (
                      <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700">
                        <CheckCircle size={11} /> {t("common.active")}
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-gray-100 text-gray-500">
                        <XCircle size={11} /> {t("common.inactive")}
                      </span>
                    )}
                  </td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center justify-end gap-2">
                      {delConfirm === a.id ? (
                        <>
                          <span className="text-xs text-gray-600">Delete?</span>
                          <button
                            onClick={() => deleteMut.mutate(a.id)}
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
                        <>
                          <button
                            onClick={() => {
                              setEditing(a);
                              setModalOpen(true);
                            }}
                            className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"
                          >
                            <Pencil size={15} />
                          </button>
                          <button
                            onClick={() => setDelConfirm(a.id)}
                            className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"
                          >
                            <Trash2 size={15} />
                          </button>
                        </>
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

      {modalOpen && (
        <AreaModal
          area={editing}
          govs={govs}
          onClose={() => {
            setModalOpen(false);
            setEditing(null);
          }}
          onSaved={() => {
            setModalOpen(false);
            setEditing(null);
            qc.invalidateQueries({ queryKey: ["areas"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

function AreaModal({
  area,
  govs,
  onClose,
  onSaved,
  t,
}: {
  area: Area | null;
  govs: { id: number; name: string }[];
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const qc = useQueryClient();
  const [form, setForm] = useState({
    name: area?.name ?? "",
    name_ar: area?.name_ar ?? "",
    governorate_id: area?.governorate_id ?? 0,
    is_active: area?.is_active ?? true,
  });
  const [boundariesStr, setBoundariesStr] = useState("");
  const [parsedBoundaries, setParsedBoundaries] =
    useState<BoundariesRecord | null>(null);
  const [boundariesError, setBoundariesError] = useState<string | null>(null);

  // Parse boundaries from existing area on mount
  useEffect(() => {
    if (area?.boundaries) {
      const str = JSON.stringify(area.boundaries, null, 2);
      setBoundariesStr(str);
      validateAndSetBoundaries(str);
    }
  }, [area]);

  const validateAndSetBoundaries = (str: string) => {
    if (!str.trim()) {
      setParsedBoundaries(null);
      setBoundariesError(null);
      return true;
    }
    try {
      const parsed = JSON.parse(str);
      if (!parsed || typeof parsed !== "object") {
        throw new Error("Boundaries must be an object");
      }
      // Validate structure
      const keys = Object.keys(parsed);
      if (keys.length < 2) {
        throw new Error("Boundaries must have at least 2 points");
      }
      for (const key of keys) {
        const point = parsed[key];
        if (
          !point ||
          typeof point.lat !== "number" ||
          typeof point.lng !== "number"
        ) {
          throw new Error(`Point ${key} must have lat and lng as numbers`);
        }
      }
      setParsedBoundaries(parsed);
      setBoundariesError(null);
      return true;
    } catch (err) {
      setParsedBoundaries(null);
      setBoundariesError(err instanceof Error ? err.message : "Invalid JSON");
      return false;
    }
  };

  const handleBoundariesChange = (str: string) => {
    setBoundariesStr(str);
    validateAndSetBoundaries(str);
  };

  const handleMapBoundariesChange = (boundaries: BoundariesRecord) => {
    const str = JSON.stringify(boundaries, null, 2);
    setBoundariesStr(str);
    setParsedBoundaries(boundaries);
    setBoundariesError(null);
  };

  const saveMut = useMutation({
    mutationFn: async (d: typeof form) => {
      const payload = {
        ...d,
        governorate_id: Number(d.governorate_id),
        boundaries: parsedBoundaries || undefined,
      };
      if (area) {
        return updateArea(area.id, payload);
      }
      return createArea(payload);
    },
    onSuccess: () => {
      toast.success(area ? t("areas.updated") : t("areas.created"));
      qc.invalidateQueries({ queryKey: ["areas"] });
      onSaved();
    },
    onError: (err: any) => {
      toast.error(err?.response?.data?.message || "Save failed");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.governorate_id) {
      toast.error("Governorate is required");
      return;
    }
    if (!form.name.trim() || !form.name_ar.trim()) {
      toast.error("Name is required");
      return;
    }
    if (boundariesStr.trim() && boundariesError) {
      toast.error("Please fix boundaries JSON errors");
      return;
    }
    saveMut.mutate(form);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <div className="flex items-center gap-2">
            <MapPin size={20} className="text-indigo-600" />
            <h2 className="text-lg font-bold text-gray-900">
              {area ? t("common.edit") : t("areas.new")}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-6 py-5 space-y-5">
          {/* Governorate */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              {t("areas.governorate")} *
            </label>
            <select
              required
              value={form.governorate_id}
              onChange={(e) =>
                setForm((p) => ({
                  ...p,
                  governorate_id: Number(e.target.value),
                }))
              }
              className="input"
            >
              <option value={0}>— Select —</option>
              {govs.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.name}
                </option>
              ))}
            </select>
          </div>

          {/* Names */}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("areas.nameEn")} *
              </label>
              <input
                required
                value={form.name}
                onChange={(e) =>
                  setForm((p) => ({ ...p, name: e.target.value }))
                }
                placeholder="e.g. Nasr City"
                className="input"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("areas.nameAr")} *
              </label>
              <input
                required
                value={form.name_ar}
                onChange={(e) =>
                  setForm((p) => ({ ...p, name_ar: e.target.value }))
                }
                placeholder="e.g. مدينة نصر"
                dir="rtl"
                className="input text-right"
              />
            </div>
          </div>

          {/* Active */}
          <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(e) =>
                setForm((p) => ({ ...p, is_active: e.target.checked }))
              }
              className="w-4 h-4 rounded border-gray-300 text-indigo-600"
            />
            {t("areas.isActive")}
          </label>

          {/* Boundaries */}
          <div className="space-y-3">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              Boundaries
            </label>

            <AreaBoundariesMap
              boundaries={parsedBoundaries}
              onBoundariesChange={handleMapBoundariesChange}
              heightClassName="h-72"
              governorates={govs}
            />

            <div className="space-y-2">
              <textarea
                value={boundariesStr}
                onChange={(e) => handleBoundariesChange(e.target.value)}
                placeholder={
                  '{\n  "point1": { "lat": 30.0561, "lng": 31.3300 },\n  "point2": { "lat": 30.0200, "lng": 31.3700 }\n}'
                }
                rows={6}
                className={`w-full rounded-xl border px-3 py-2 text-sm font-mono focus:ring-2 focus:ring-indigo-500 outline-none resize-y ${
                  boundariesError
                    ? "border-red-300 bg-red-50"
                    : "border-gray-300"
                }`}
              />
              {boundariesError && (
                <p className="text-xs text-red-600">{boundariesError}</p>
              )}
              <p className="text-xs text-gray-500">
                Draw on the map or enter at least 2 points with lat/lng as
                numbers.
              </p>
            </div>
          </div>

          {/* Actions */}
          <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50"
            >
              {t("common.cancel")}
            </button>
            <button
              type="submit"
              disabled={saveMut.isPending || !!boundariesError}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
            >
              {saveMut.isPending
                ? t("common.saving")
                : area
                  ? t("common.save")
                  : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
