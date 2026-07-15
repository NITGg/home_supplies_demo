"use client";
import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchCourierCoupons,
  createCourierCoupon,
  updateCourierCoupon,
  deleteCourierCoupon,
  type CourierCoupon,
} from "@/lib/courier-coupons";
import { useT } from "@/contexts/LanguageContext";
import { Repeat, Plus, Pencil, Trash2, RefreshCw, X, CheckCircle, XCircle, ChevronUp, ChevronDown, ChevronsUpDown } from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

const ALL_COLUMN_KEYS = ["id", "title", "price", "bonus_courier_fee", "duration_days", "is_active", "created_at", "updated_at", "actions"] as const;

type SortField =
  | "id"
  | "title"
  | "price"
  | "bonus_courier_fee"
  | "duration_days"
  | "is_active"
  | "created_at";
type SortDir = "asc" | "desc";

const ALL_COLUMNS = [
  "id",
  "title",
  "title_ar",
  "description",
  "price",
  "bonus_courier_fee",
  "duration_days",
  "is_active",
  "created_at",
  "updated_at",
];
const INITIAL_VISIBLE_COLUMNS = [
  "id",
  "title",
  "price",
  "bonus_courier_fee",
  "duration_days",
  "is_active",
];

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc" ? (
    <ChevronUp size={13} className="text-indigo-600" />
  ) : (
    <ChevronDown size={13} className="text-indigo-600" />
  );
}

export default function CourierCouponsPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(12);
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<CourierCoupon | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:courier-coupons", [...ALL_COLUMN_KEYS]);

  const params: Record<string, string | number> = { page, limit: 12 };
  if (search) params.keyword = search;
  if (filterStatus === "active") params.is_active = "true";
  if (filterStatus === "inactive") params.is_active = "false";

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["courier-coupons", params],
    queryFn: () => fetchCourierCoupons(params),
  });

  const allCoupons = data?.coupons ?? [];
  const coupons = allCoupons.filter(c => {
    if (createdFrom && new Date(c.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(c.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && c.updated_at && new Date(c.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && c.updated_at && new Date(c.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.total ?? 0;
  const totalPages = data?.total_pages ?? 1;
  const activeCount = allCoupons.filter(c => c.is_active).length;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? coupons.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteCourierCoupon(id),
    onSuccess: () => {
      toast.success(t("courierCoupons.deleted"));
      qc.invalidateQueries({ queryKey: ["courier-coupons"] });
      setDelConfirm(null);
    },
    onError: () => toast.error(t("courierCoupons.deleteError")),
  });

  const allColumns: Column<CourierCoupon>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: c => c.id,
      render: c => <span className="text-xs font-mono text-gray-400">#{c.id}</span>,
    },
    {
      key: "title",
      label: t("courierCoupons.titleEn"),
      sortable: true,
      getValue: c => c.title,
      render: c => (
        <div>
          <p className="font-medium text-gray-900">{c.title}</p>
          {c.title_ar && <p className="text-xs text-gray-400" dir="rtl">{c.title_ar}</p>}
        </div>
      ),
    },
    {
      key: "price",
      label: t("courierCoupons.price"),
      sortable: true,
      getValue: c => c.price,
      render: c => <span className="font-medium text-gray-700">{c.price} EGP</span>,
    },
    {
      key: "bonus_courier_fee",
      label: t("courierCoupons.bonusFee"),
      sortable: true,
      getValue: c => c.bonus_courier_fee,
      render: c => <span className="text-gray-600">{c.bonus_courier_fee} EGP</span>,
    },
    {
      key: "duration_days",
      label: t("courierCoupons.duration"),
      sortable: true,
      getValue: c => c.duration_days,
      render: c => <span className="text-gray-600">{c.duration_days}d</span>,
    },
    {
      key: "is_active",
      label: t("common.status"),
      sortable: true,
      getValue: c => c.is_active ? 1 : 0,
      render: c => c.is_active
        ? <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700"><CheckCircle size={11} /> {t("common.active")}</span>
        : <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-gray-100 text-gray-500"><XCircle size={11} /> {t("common.inactive")}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: c => new Date(c.created_at),
      render: c => (
        <span className="text-xs text-gray-500">
          {new Date(c.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: c => c.updated_at ? new Date(c.updated_at) : undefined,
      render: c => (
        <span className="text-xs text-gray-500">
          {c.updated_at ? new Date(c.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" }) : "—"}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: c => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === c.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button onClick={() => deleteMut.mutate(c.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(c); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(c.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
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
            <Repeat size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("courierCoupons.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">
            {t("courierCoupons.subtitle")}
          </p>
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
            <Plus size={16} /> {t("courierCoupons.new")}
          </button>
        </div>
      </div>

      <div className="flex gap-4">
        <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-indigo-700">{total}</p>
          <p className="text-xs text-indigo-400 mt-1">
            {t("courierCoupons.total")}
          </p>
        </div>
        <div className="bg-green-50 border border-green-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-green-700">{activeCount}</p>
          <p className="text-xs text-green-400 mt-1">
            {t("courierCoupons.active")}
          </p>
        </div>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="coupon"
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("courierCoupons.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
          </div>
        }
      >
        <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value as typeof filterStatus); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-indigo-500">
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
        rows={coupons}
        keyExtractor={c => c.id}
        isLoading={isLoading}
        emptyText={t("courierCoupons.noResults")}
        emptyIcon={<Repeat size={36} className="text-gray-300" />}
      />
      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={12} onPageChange={setPage} />

      {modalOpen && (
        <CourierCouponModal
          coupon={editing}
          onClose={() => {
            setModalOpen(false);
            setEditing(null);
          }}
          onSaved={() => {
            setModalOpen(false);
            setEditing(null);
            qc.invalidateQueries({ queryKey: ["courier-coupons"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

function CourierCouponModal({
  coupon,
  onClose,
  onSaved,
  t,
}: {
  coupon: CourierCoupon | null;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState({
    title: coupon?.title ?? "",
    title_ar: coupon?.title_ar ?? "",
    description: coupon?.description ?? "",
    description_ar: coupon?.description_ar ?? "",
    price: coupon?.price?.toString() ?? "",
    bonus_courier_fee: coupon?.bonus_courier_fee?.toString() ?? "",
    duration_days: coupon?.duration_days?.toString() ?? "",
    is_active: coupon?.is_active ?? true,
  });

  const saveMut = useMutation({
    mutationFn: (d: typeof form) =>
      coupon
        ? updateCourierCoupon(coupon.id, {
            ...d,
            price: Number(d.price),
            bonus_courier_fee: Number(d.bonus_courier_fee),
            duration_days: Number(d.duration_days),
          })
        : createCourierCoupon({
            ...d,
            price: Number(d.price),
            bonus_courier_fee: Number(d.bonus_courier_fee),
            duration_days: Number(d.duration_days),
          }),
    onSuccess: () => {
      toast.success(
        coupon ? t("courierCoupons.updated") : t("courierCoupons.created"),
      );
      onSaved();
    },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string | boolean) =>
    setForm((p) => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {coupon ? t("common.edit") : t("courierCoupons.new")}
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
                {t("courierCoupons.titleEn")}
              </label>
              <input
                required
                value={form.title}
                onChange={(e) => set("title", e.target.value)}
                className="input"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("courierCoupons.titleAr")}
              </label>
              <input
                value={form.title_ar}
                onChange={(e) => set("title_ar", e.target.value)}
                dir="rtl"
                className="input text-right"
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("courierCoupons.descEn")}
              </label>
              <textarea
                value={form.description}
                onChange={(e) => set("description", e.target.value)}
                rows={2}
                className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("courierCoupons.descAr")}
              </label>
              <textarea
                value={form.description_ar}
                onChange={(e) => set("description_ar", e.target.value)}
                rows={2}
                dir="rtl"
                className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none text-right"
              />
            </div>
          </div>
          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("courierCoupons.price")}
              </label>
              <input
                required
                type="number"
                step="0.001"
                value={form.price}
                onChange={(e) => set("price", e.target.value)}
                className="input"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("courierCoupons.bonusFee")}
              </label>
              <input
                required
                type="number"
                step="0.001"
                value={form.bonus_courier_fee}
                onChange={(e) => set("bonus_courier_fee", e.target.value)}
                className="input"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">
                {t("courierCoupons.duration")}
              </label>
              <input
                required
                type="number"
                min="1"
                value={form.duration_days}
                onChange={(e) => set("duration_days", e.target.value)}
                className="input"
              />
            </div>
          </div>
          <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(e) => set("is_active", e.target.checked)}
              className="w-4 h-4 rounded border-gray-300 text-indigo-600"
            />
            {t("courierCoupons.isActive")}
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
                : coupon
                  ? t("common.save")
                  : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
