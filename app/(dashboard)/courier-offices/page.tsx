"use client";
import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchCourierOffices,
  createCourierOffice,
  updateCourierOffice,
  deleteCourierOffice,
  type CourierOffice,
} from "@/lib/courier-offices";
import { fetchUsers } from "@/lib/users";
import { useT } from "@/contexts/LanguageContext";
import {
  Building2,
  Plus,
  Pencil,
  Trash2,
  RefreshCw,
  X,
  Users,
  Wallet,
  Percent,
  Coins,
} from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { cn } from "@/lib/utils";

const ALL_COLUMN_KEYS = [
  "id",
  "name",
  "couriers",
  "wallet_total",
  "commission",
  "address",
  "phone",
  "email",
  "created_at",
  "updated_at",
  "actions",
] as const;

function fmtCommission(type: string, value: string) {
  const n = Number(value);
  if (type === "PERCENTAGE") return `${n}%`;
  return `${(n / 100).toFixed(2)} EGP / order`;
}

export default function CourierOfficesPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<CourierOffice | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:courier-offices", [
    ...ALL_COLUMN_KEYS,
  ]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["courier-offices", params],
    queryFn: () => fetchCourierOffices(params),
  });

  // Fetch all courier users with wallet so we can compute per-office stats
  const { data: courierUsersData } = useQuery({
    queryKey: ["courier-users-for-offices"],
    queryFn: () =>
      fetchUsers({ limit: 9999, includes: "courier,wallet", role_id: 2 }),
    staleTime: 5 * 60 * 1000,
  });

  // officeId → { total, approved, walletSum }
  const officeStats = useMemo(() => {
    const map: Record<
      number,
      { total: number; approved: number; walletSum: number }
    > = {};
    for (const u of courierUsersData?.users ?? []) {
      const oid = u.courier?.courier_office_id;
      if (!oid) continue;
      const id = Number(oid);
      if (!map[id]) map[id] = { total: 0, approved: 0, walletSum: 0 };
      map[id].total++;
      if (u.courier?.is_approved) map[id].approved++;
      map[id].walletSum += u.wallet?.balance ?? 0;
    }
    return map;
  }, [courierUsersData]);

  const allOffices = data?.couriers ?? [];
  const offices = allOffices.filter((o) => {
    if (createdFrom && new Date(o.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(o.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    if (updatedFrom && new Date(o.updated_at) < new Date(updatedFrom))
      return false;
    if (updatedTo && new Date(o.updated_at) > new Date(updatedTo + "T23:59:59"))
      return false;
    return true;
  });

  const total = data?.total ?? 0;
  const totalPages = data?.total_pages ?? 1;
  const displayTotal =
    createdFrom || createdTo || updatedFrom || updatedTo
      ? offices.length
      : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteCourierOffice(id),
    onSuccess: () => {
      toast.success(t("courierOffices.deleted"));
      qc.invalidateQueries({ queryKey: ["courier-offices"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("courierOffices.deleteError")),
  });

  const allColumns: Column<CourierOffice>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: (o) => o.id,
      render: (o) => (
        <span className="text-xs font-mono text-gray-400">#{o.id}</span>
      ),
    },
    {
      key: "name",
      label: t("courierOffices.nameLabel"),
      sortable: true,
      getValue: (o) => o.name,
      render: (o) => (
        <span className="font-medium text-gray-900">{o.name}</span>
      ),
    },
    {
      key: "couriers",
      label: t("courierOffices.couriersCol"),
      sortable: true,
      getValue: (o) => officeStats[o.id]?.total ?? 0,
      render: (o) => {
        const s = officeStats[o.id];
        if (!s) return <span className="text-gray-400 text-xs">—</span>;
        return (
          <div className="flex items-center gap-1.5">
            <Users size={13} className="text-gray-400 shrink-0" />
            <span className="font-semibold text-gray-900">{s.approved}</span>
            <span className="text-gray-400 text-xs">/ {s.total}</span>
          </div>
        );
      },
    },
    {
      key: "wallet_total",
      label: t("courierOffices.walletTotal"),
      sortable: true,
      getValue: (o) => officeStats[o.id]?.walletSum ?? 0,
      render: (o) => {
        const s = officeStats[o.id];
        if (!s) return <span className="text-gray-400 text-xs">—</span>;
        return (
          <div className="flex items-center gap-1.5">
            <Wallet size={13} className="text-emerald-500 shrink-0" />
            <span
              className={cn(
                "font-semibold text-xs tabular-nums",
                s.walletSum > 0
                  ? "text-emerald-700"
                  : s.walletSum < 0
                    ? "text-red-600"
                    : "text-gray-400",
              )}
            >
              {s.walletSum.toFixed(2)}
            </span>
          </div>
        );
      },
    },
    {
      key: "commission",
      label: t("courierOffices.commission"),
      render: (o) => (
        <div className="flex items-center gap-1.5 text-xs">
          <span className={cn(
            "px-1.5 py-0.5 rounded font-medium",
            o.commission_type === "PERCENTAGE"
              ? "bg-purple-100 text-purple-700"
              : "bg-indigo-100 text-indigo-700",
          )}>
            {o.commission_type === "PERCENTAGE" ? "%" : "Fixed"}
          </span>
          <span className="text-gray-700 font-medium">
            {fmtCommission(o.commission_type, o.commission_value)}
          </span>
        </div>
      ),
    },
    {
      key: "address",
      label: t("courierOffices.address"),
      render: (o) => (
        <span className="text-gray-500 text-xs">{o.address ?? "—"}</span>
      ),
    },
    {
      key: "phone",
      label: t("courierOffices.phone"),
      render: (o) => <span className="text-gray-600">{o.phone ?? "—"}</span>,
    },
    {
      key: "email",
      label: t("courierOffices.email"),
      sortable: true,
      getValue: (o) => o.email ?? "",
      render: (o) => <span className="text-gray-600">{o.email ?? "—"}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: (o) => new Date(o.created_at),
      render: (o) => (
        <span className="text-xs text-gray-500">
          {new Date(o.created_at).toLocaleDateString(undefined, {
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
      getValue: (o) => new Date(o.updated_at),
      render: (o) => (
        <span className="text-xs text-gray-500">
          {new Date(o.updated_at).toLocaleDateString(undefined, {
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
      render: (o) => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === o.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button
                onClick={() => deleteMut.mutate(o.id)}
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
                  setEditing(o);
                  setModalOpen(true);
                }}
                className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"
              >
                <Pencil size={15} />
              </button>
              <button
                onClick={() => setDelConfirm(o.id)}
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

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Building2 size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("courierOffices.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">
            {t("courierOffices.subtitle")}
          </p>
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

      <TableToolbar
        total={displayTotal}
        totalLabel={t("courierOffices.total")}
        search={search}
        onSearch={(v) => {
          setSearch(v);
          setPage(1);
        }}
        searchPlaceholder={t("courierOffices.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle
              columns={columnOptions}
              visible={visible}
              onChange={setVisible}
            />
            <button
              onClick={() => {
                setEditing(null);
                setModalOpen(true);
              }}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700"
            >
              <Plus size={16} /> {t("courierOffices.new")}
            </button>
          </div>
        }
      >
        <DateRangeFilter
          label={t("common.createdAt")}
          from={createdFrom}
          to={createdTo}
          onFromChange={(v) => {
            setCreatedFrom(v);
            setPage(1);
          }}
          onToChange={(v) => {
            setCreatedTo(v);
            setPage(1);
          }}
        />
        <DateRangeFilter
          label={t("common.updatedAt")}
          from={updatedFrom}
          to={updatedTo}
          onFromChange={(v) => {
            setUpdatedFrom(v);
            setPage(1);
          }}
          onToChange={(v) => {
            setUpdatedTo(v);
            setPage(1);
          }}
        />
      </TableToolbar>

      <DataTable
        columns={columns}
        rows={offices}
        keyExtractor={(o) => o.id}
        isLoading={isLoading}
        emptyText={t("courierOffices.noResults")}
        emptyIcon={<Building2 size={36} className="text-gray-300" />}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={displayTotal}
        limit={20}
        onPageChange={setPage}
      />

      {modalOpen && (
        <OfficeModal
          key={editing?.id ?? "new"}
          office={editing}
          onClose={() => {
            setModalOpen(false);
            setEditing(null);
          }}
          onSaved={() => {
            setModalOpen(false);
            setEditing(null);
            qc.invalidateQueries({ queryKey: ["courier-offices"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

function OfficeModal({
  office,
  onClose,
  onSaved,
  t,
}: {
  office: CourierOffice | null;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState({
    name: office?.name ?? "",
    address: office?.address ?? "",
    phone: office?.phone ?? "",
    email: office?.email ?? "",
    website: office?.website ?? "",
    description: office?.description ?? "",
    commission_type: (office?.commission_type ?? "FIXED_PER_ORDER") as "FIXED_PER_ORDER" | "PERCENTAGE",
    commission_value: office?.commission_value ?? "0",
  });

  const saveMut = useMutation({
    mutationFn: ({ commission_value, commission_type, ...rest }: typeof form) =>
      office
        ? updateCourierOffice(office.id, { ...rest, commission_type, commission_value: Number(commission_value) })
        : createCourierOffice({ ...rest, commission_type, commission_value: Number(commission_value) }),
    onSuccess: () => {
      toast.success(
        office ? t("courierOffices.updated") : t("courierOffices.created"),
      );
      onSaved();
    },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string) =>
    setForm((p) => ({ ...p, [k]: v }));

  const commissionHint = form.commission_type === "FIXED_PER_ORDER"
    ? "Enter amount in cents (e.g. 200 = 2.00 EGP per order)"
    : "Enter percentage (e.g. 10 = 10% of courier fee)";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {office ? t("common.edit") : t("courierOffices.new")}
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
          {(
            [
              ["name", t("courierOffices.nameLabel"), true],
              ["phone", t("courierOffices.phone"), false],
              ["email", t("courierOffices.email"), false],
              ["website", t("courierOffices.website"), false],
              ["address", t("courierOffices.address"), false],
              ["description", t("courierOffices.description"), false],
            ] as [keyof typeof form, string, boolean][]
          ).map(([key, label, required]) => (
            <div key={key} className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {label}
              </label>
              {key === "description" ? (
                <textarea
                  value={form[key]}
                  onChange={(e) => set(key, e.target.value)}
                  rows={3}
                  className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none"
                />
              ) : (
                <input
                  required={required}
                  value={form[key]}
                  onChange={(e) => set(key, e.target.value)}
                  className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                />
              )}
            </div>
          ))}

          {/* Commission section */}
          <div className="border-t border-gray-100 pt-4 space-y-3">
            <p className="text-xs font-semibold text-gray-600 uppercase">Commission</p>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <label className="text-xs text-gray-500">Type</label>
                <select
                  value={form.commission_type}
                  onChange={(e) => set("commission_type", e.target.value)}
                  className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                >
                  <option value="FIXED_PER_ORDER">Fixed per order</option>
                  <option value="PERCENTAGE">Percentage (%)</option>
                </select>
              </div>
              <div className="space-y-1.5">
                <label className="text-xs text-gray-500">Value</label>
                <div className="relative">
                  <input
                    type="number"
                    min={0}
                    step={form.commission_type === "PERCENTAGE" ? "0.01" : "1"}
                    value={form.commission_value}
                    onChange={(e) => set("commission_value", e.target.value)}
                    className="w-full border border-gray-300 rounded-xl px-3 py-2 pr-8 text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
                    {form.commission_type === "PERCENTAGE" ? <Percent size={13} /> : <Coins size={13} />}
                  </span>
                </div>
              </div>
            </div>
            <p className="text-xs text-gray-400">{commissionHint}</p>
          </div>

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
                : office
                  ? t("common.save")
                  : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
