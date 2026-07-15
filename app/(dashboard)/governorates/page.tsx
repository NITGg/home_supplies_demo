"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchGovernorates,
  createGovernorate,
  updateGovernorate,
  deleteGovernorate,
  type Governorate,
} from "@/lib/governorates";
import { useT } from "@/contexts/LanguageContext";
import { MapPin, Plus, Pencil, Trash2, RefreshCw, X, CheckCircle, XCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

const ALL_COLUMN_KEYS = ["id", "name", "name_ar", "is_active", "created_at", "updated_at", "actions"] as const;

export default function GovernoratesPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Governorate | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:governorates", [...ALL_COLUMN_KEYS]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;
  if (filterStatus === "active") params.is_active = "true";
  if (filterStatus === "inactive") params.is_active = "false";

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["governorates", params],
    queryFn: () => fetchGovernorates(params),
  });

  const allGovs = data?.governorates ?? [];
  const govs = allGovs.filter(g => {
    if (createdFrom && new Date(g.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(g.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(g.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(g.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.totalCount ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const activeCount = govs.filter(g => g.is_active).length;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? govs.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteGovernorate(id),
    onSuccess: () => {
      toast.success(t("governorates.deleted"));
      qc.invalidateQueries({ queryKey: ["governorates"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("governorates.deleteError")),
  });

  const allColumns: Column<Governorate>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: g => g.id,
      render: g => <span className="text-xs font-mono text-gray-400">#{g.id}</span>,
    },
    {
      key: "name",
      label: t("governorates.nameEn"),
      sortable: true,
      getValue: g => g.name,
      render: g => <span className="font-medium text-gray-900">{g.name}</span>,
    },
    {
      key: "name_ar",
      label: t("governorates.nameAr"),
      render: g => <span className="text-gray-700" dir="rtl">{g.name_ar}</span>,
    },
    {
      key: "is_active",
      label: t("common.status"),
      sortable: true,
      getValue: g => g.is_active ? 1 : 0,
      render: g => g.is_active
        ? <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700"><CheckCircle size={11} /> {t("common.active")}</span>
        : <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-gray-100 text-gray-500"><XCircle size={11} /> {t("common.inactive")}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: g => new Date(g.created_at),
      render: g => (
        <span className="text-xs text-gray-500">
          {new Date(g.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: g => new Date(g.updated_at),
      render: g => (
        <span className="text-xs text-gray-500">
          {new Date(g.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: g => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === g.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button onClick={() => deleteMut.mutate(g.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(g); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(g.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
            </>
          )}
        </div>
      ),
    },
  ];

  const columns = allColumns.filter(c => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map(c => ({ key: c.key, label: c.label, alwaysVisible: c.key === "actions" }));

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <MapPin size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("governorates.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">{t("governorates.subtitle")}</p>
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
        </div>
      </div>

      <div className="flex gap-4">
        {[
          { label: t("governorates.total"), value: total, c: "indigo" },
          { label: t("governorates.active"), value: activeCount, c: "green" },
        ].map(({ label, value, c }) => (
          <div
            key={label}
            className={cn(
              "border rounded-2xl px-5 py-4 text-center",
              c === "indigo"
                ? "bg-indigo-50 border-indigo-100"
                : "bg-green-50 border-green-100",
            )}
          >
            <p
              className={cn(
                "text-3xl font-bold",
                c === "indigo" ? "text-indigo-700" : "text-green-700",
              )}
            >
              {value}
            </p>
            <p
              className={cn(
                "text-xs mt-1",
                c === "indigo" ? "text-indigo-400" : "text-green-400",
              )}
            >
              {label}
            </p>
          </div>
        ))}
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="governorate"
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("governorates.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditing(null); setModalOpen(true); }} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700">
              <Plus size={16} /> {t("governorates.new")}
            </button>
          </div>
        }
      >
        <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value as typeof filterStatus); setPage(1); }} className="input w-auto">
          <option value="all">{t("common.all")}</option>
          <option value="active">{t("common.active")}</option>
          <option value="inactive">{t("common.inactive")}</option>
        </select>
        <DateRangeFilter
          label={t("common.createdAt")}
          from={createdFrom} to={createdTo}
          onFromChange={v => { setCreatedFrom(v); setPage(1); }}
          onToChange={v => { setCreatedTo(v); setPage(1); }}
        />
        <DateRangeFilter
          label={t("common.updatedAt")}
          from={updatedFrom} to={updatedTo}
          onFromChange={v => { setUpdatedFrom(v); setPage(1); }}
          onToChange={v => { setUpdatedTo(v); setPage(1); }}
        />
      </TableToolbar>

      <DataTable
        columns={columns}
        rows={govs}
        keyExtractor={g => g.id}
        isLoading={isLoading}
        emptyText={t("governorates.noResults")}
        emptyIcon={<MapPin size={36} className="text-gray-300" />}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={displayTotal}
        limit={20}
        onPageChange={setPage}
      />

      {modalOpen && (
        <GovModal
          gov={editing}
          onClose={() => {
            setModalOpen(false);
            setEditing(null);
          }}
          onSaved={() => {
            setModalOpen(false);
            setEditing(null);
            qc.invalidateQueries({ queryKey: ["governorates"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

function GovModal({
  gov,
  onClose,
  onSaved,
  t,
}: {
  gov: Governorate | null;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState({
    name: gov?.name ?? "",
    name_ar: gov?.name_ar ?? "",
    is_active: gov?.is_active ?? true,
  });
  const saveMut = useMutation({
    mutationFn: (d: typeof form) =>
      gov ? updateGovernorate(gov.id, d) : createGovernorate(d),
    onSuccess: () => {
      toast.success(
        gov ? t("governorates.updated") : t("governorates.created"),
      );
      onSaved();
    },
    onError: () => toast.error("Save failed"),
  });
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {gov ? t("common.edit") : t("governorates.new")}
          </h2>
          <button
            onClick={onClose}
            className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"
          >
            <X size={18} />
          </button>
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            saveMut.mutate(form);
          }}
          className="px-6 py-5 space-y-4"
        >
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("governorates.nameEn")}
              </label>
              <input
                required
                value={form.name}
                onChange={(e) =>
                  setForm((p) => ({ ...p, name: e.target.value }))
                }
                className="input"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("governorates.nameAr")}
              </label>
              <input
                required
                value={form.name_ar}
                onChange={(e) =>
                  setForm((p) => ({ ...p, name_ar: e.target.value }))
                }
                dir="rtl"
                className="input text-right"
              />
            </div>
          </div>
          <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(e) =>
                setForm((p) => ({ ...p, is_active: e.target.checked }))
              }
              className="w-4 h-4 rounded border-gray-300 text-indigo-600"
            />
            {t("governorates.isActive")}
          </label>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50"
            >
              {t("common.cancel")}
            </button>
            <button
              type="submit"
              disabled={saveMut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
            >
              {saveMut.isPending
                ? t("common.saving")
                : gov
                  ? t("common.save")
                  : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
