"use client";
import { useState, useRef, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchCoupons,
  createCoupon,
  updateCoupon,
  deleteCoupon,
  type Coupon,
  type CouponType,
  type DiscountType,
  type CouponScope,
} from "@/lib/coupons";
import { useT } from "@/contexts/LanguageContext";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import {
  Ticket,
  Plus,
  Pencil,
  Trash2,
  RefreshCw,
  X,
  CheckCircle,
  XCircle,
  Upload,
  ChevronsUpDown,
  ChevronUp,
  ChevronDown,
} from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

type FilterType = "all" | CouponType;
type SortField =
  | "id"
  | "code"
  | "title"
  | "type"
  | "discount_value"
  | "is_active"
  | "start_at"
  | "end_at"
  | "created_at";
type SortDir = "asc" | "desc";

const ALL_COLUMNS = [
  "id",
  "code",
  "title",
  "title_ar",
  "description",
  "type",
  "discount_type",
  "discount_value",
  "scope",
  "is_first",
  "max_total_uses",
  "max_user_uses",
  "max_discount_cents",
  "min_order_total_cents",
  "min_orders_count",
  "wallet_amount_cents",
  "wallet_points",
  "is_purchasable",
  "purchase_price_cents",
  "is_active",
  "start_at",
  "end_at",
  "created_at",
  "deleted_at",
];

const INITIAL_VISIBLE_COLUMNS = [
  "id",
  "code",
  "title",
  "type",
  "discount_value",
  "is_active",
  "start_at",
  "end_at",
];

function fmtDate(d?: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function fmtDiscount(c: Coupon) {
  if (c.type === "WALLET_CREDIT") {
    const parts = [];
    if (c.wallet_amount_cents)
      parts.push(`${(c.wallet_amount_cents / 100).toFixed(2)} EGP`);
    if (c.wallet_points) parts.push(`${c.wallet_points} pts`);
    return parts.join(" + ") || "—";
  }
  if (!c.discount_value) return "—";
  return c.discount_type === "PERCENT"
    ? `${c.discount_value}%`
    : `${(c.discount_value / 100).toFixed(2)} EGP`;
}

function fmtCents(v?: number | null) {
  if (v == null) return "—";
  return `${(v / 100).toFixed(2)} EGP`;
}

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc" ? (
    <ChevronUp size={13} className="text-indigo-600" />
  ) : (
    <ChevronDown size={13} className="text-indigo-600" />
  );
}

const ALL_COLUMN_KEYS = [
  "id",
  "code",
  "title",
  "type",
  "discount",
  "validity",
  "is_active",
  "created_at",
  "updated_at",
  "actions",
] as const;

// ── Page ─────────────────────────────────────────────────────────────────────
export default function CouponsPage() {
  const { t } = useT();
  const qc = useQueryClient();

  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(12);
  const [search, setSearch] = useState("");
  const [filterType, setFilterType] = useState<FilterType>("all");
  const [filterStatus, setFilter] = useState<"all" | "active" | "inactive">(
    "all",
  );
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [archiveInstead, setArchiveInstead] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Coupon | null>(null);
  const [sortField, setSortField] = useState<SortField>("id");
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [visibleColumns, setVisibleColumns] = useState<Record<string, boolean>>(
    () => {
      const m: Record<string, boolean> = {};
      ALL_COLUMNS.forEach((c) => {
        m[c] = INITIAL_VISIBLE_COLUMNS.includes(c);
      });
      return m;
    },
  );
  const [showAdvFilters, setShowAdvFilters] = useState(false);
  const [filterDiscountType, setFilterDiscountType] = useState<string>("");
  const [filterScope, setFilterScope] = useState<string>("");
  const [filterIsFirst, setFilterIsFirst] = useState<string>("");
  const [filterIsPurchasable, setFilterIsPurchasable] = useState<string>("");

  const { visible, setVisible } = useColumnVisibility("cols:coupons", [
    ...ALL_COLUMN_KEYS,
  ]);

  const params: Record<string, string | number> = { page, limit };
  if (search) params.search = search;
  if (filterType !== "all") params.type = filterType;
  if (filterStatus === "active") params.is_active = "true";
  if (filterStatus === "inactive") params.is_active = "false";
  if (filterDiscountType) params.discount_type = filterDiscountType;
  if (filterScope) params.scope = filterScope;
  if (filterIsFirst) params.is_first = filterIsFirst;
  if (filterIsPurchasable) params.is_purchasable = filterIsPurchasable;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["coupons", params],
    queryFn: () => fetchCoupons(params),
  });

  const allCoupons = data?.coupons ?? [];
  const coupons = allCoupons.filter((c) => {
    if (createdFrom && new Date(c.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(c.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    if (updatedFrom && new Date(c.updated_at) < new Date(updatedFrom))
      return false;
    if (updatedTo && new Date(c.updated_at) > new Date(updatedTo + "T23:59:59"))
      return false;
    return true;
  });

  const totalPages = data?.totalPages ?? 1;
  const total = data?.totalCoupons ?? 0;
  const displayTotal =
    createdFrom || createdTo || updatedFrom || updatedTo
      ? coupons.length
      : total;

  const deleteMut = useMutation({
    mutationFn: ({ id, archived }: { id: number; archived: boolean }) =>
      deleteCoupon(id, archived),
    onSuccess: () => {
      toast.success(t("coupons.deleted"));
      qc.invalidateQueries({ queryKey: ["coupons"] });
      setDelConfirm(null);
      setArchiveInstead(false);
    },
    onError: () => toast.error(t("coupons.deleteError")),
  });

  function openCreate() {
    setEditing(null);
    setModalOpen(true);
  }
  function openEdit(c: Coupon) {
    setEditing(c);
    setModalOpen(true);
  }
  function closeModal() {
    setModalOpen(false);
    setEditing(null);
  }

  function toggleSort(f: SortField) {
    if (sortField === f) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else {
      setSortField(f);
      setSortDir("asc");
    }
  }

  const sortedCoupons = useMemo(() => {
    const list = [...coupons];
    return list.sort((a, b) => {
      let av: string | number = "",
        bv: string | number = "";
      switch (sortField) {
        case "id":
          av = a.id;
          bv = b.id;
          break;
        case "code":
          av = a.code;
          bv = b.code;
          break;
        case "title":
          av = a.title;
          bv = b.title;
          break;
        case "type":
          av = a.type;
          bv = b.type;
          break;
        case "discount_value":
          av = a.discount_value ?? 0;
          bv = b.discount_value ?? 0;
          break;
        case "is_active":
          av = a.is_active ? 1 : 0;
          bv = b.is_active ? 1 : 0;
          break;
        case "start_at":
          av = a.start_at ?? "";
          bv = b.start_at ?? "";
          break;
        case "end_at":
          av = a.end_at ?? "";
          bv = b.end_at ?? "";
          break;
        case "created_at":
          av = a.created_at;
          bv = b.created_at;
          break;
      }
      if (av < bv) return sortDir === "asc" ? -1 : 1;
      if (av > bv) return sortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [coupons, sortField, sortDir]);

  const activeCount = coupons.filter((c) => c.is_active).length;
  const orderCount = coupons.filter((c) => c.type === "ORDER_DISCOUNT").length;
  const walletCount = coupons.filter((c) => c.type === "WALLET_CREDIT").length;

  function clearFilters() {
    setSearch("");
    setFilterType("all");
    setFilter("all");
    setFilterDiscountType("");
    setFilterScope("");
    setFilterIsFirst("");
    setFilterIsPurchasable("");
    setPage(1);
  }
  const hasActiveFilters =
    search ||
    filterType !== "all" ||
    filterStatus !== "all" ||
    filterDiscountType ||
    filterScope ||
    filterIsFirst ||
    filterIsPurchasable;

  const allColumns: Column<Coupon>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: (c) => c.id,
      render: (c) => (
        <span className="text-xs font-mono text-gray-400">#{c.id}</span>
      ),
    },
    {
      key: "code",
      label: t("coupons.code"),
      sortable: true,
      getValue: (c) => c.code,
      render: (c) => (
        <span className="font-mono text-xs bg-indigo-50 text-indigo-700 px-2.5 py-1 rounded-lg border border-indigo-100">
          {c.code}
        </span>
      ),
    },
    {
      key: "title",
      label: t("common.name"),
      sortable: true,
      getValue: (c) => c.title,
      render: (c) => (
        <div>
          <p className="font-medium text-gray-900">{c.title}</p>
          {c.title_ar && (
            <p className="text-xs text-gray-400" dir="rtl">
              {c.title_ar}
            </p>
          )}
        </div>
      ),
    },
    {
      key: "type",
      label: t("coupons.type"),
      sortable: true,
      getValue: (c) => c.type,
      render: (c) => <TypeBadge type={c.type} t={t} />,
    },
    {
      key: "discount",
      label: t("coupons.discount"),
      sortable: true,
      getValue: (c) => c.discount_value ?? 0,
      render: (c) => (
        <span className="text-gray-700 font-medium">{fmtDiscount(c)}</span>
      ),
    },
    {
      key: "validity",
      label: t("coupons.validity"),
      render: (c) => (
        <div className="text-xs text-gray-500">
          <div>{fmtDate(c.start_at)} →</div>
          <div>{fmtDate(c.end_at)}</div>
        </div>
      ),
    },
    {
      key: "is_active",
      label: t("common.status"),
      sortable: true,
      getValue: (c) => (c.is_active ? 1 : 0),
      render: (c) =>
        c.is_active ? (
          <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700 font-medium">
            <CheckCircle size={11} /> {t("common.active")}
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-gray-100 text-gray-500 font-medium">
            <XCircle size={11} /> {t("common.inactive")}
          </span>
        ),
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: (c) => new Date(c.created_at),
      render: (c) => (
        <span className="text-xs text-gray-500">
          {new Date(c.created_at).toLocaleDateString(undefined, {
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
      getValue: (c) => new Date(c.updated_at),
      render: (c) => (
        <span className="text-xs text-gray-500">
          {new Date(c.updated_at).toLocaleDateString(undefined, {
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
      render: (c) => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === c.id ? (
            <>
              <span className="text-xs text-gray-600">
                {t("coupons.deleteConfirm")}
              </span>
              <button
                onClick={() =>
                  deleteMut.mutate({ id: c.id, archived: archiveInstead })
                }
                disabled={deleteMut.isPending}
                className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50"
              >
                {t("common.yes")}
              </button>
              <button
                onClick={() => setDelConfirm(null)}
                className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                {t("common.cancel")}
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => openEdit(c)}
                className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 transition"
              >
                <Pencil size={15} />
              </button>
              <button
                onClick={() => setDelConfirm(c.id)}
                className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition"
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
      {/* ── Header ── */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Ticket size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("coupons.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">{t("coupons.subtitle")}</p>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition disabled:opacity-50"
        >
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
          {t("common.refresh")}
        </button>
      </div>

      {/* ── Stats ── */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard label={t("coupons.total")} value={total} color="indigo" />
        <StatCard
          label={t("coupons.active")}
          value={activeCount}
          color="green"
        />
        <StatCard
          label={t("coupons.orderDiscount")}
          value={orderCount}
          color="blue"
        />
        <StatCard
          label={t("coupons.walletCredit")}
          value={walletCount}
          color="purple"
        />
      </div>

      {/* ── Toolbar ── */}
      <TableToolbar
        total={displayTotal}
        totalLabel="coupon"
        search={search}
        onSearch={(v) => {
          setSearch(v);
          setPage(1);
        }}
        searchPlaceholder={t("coupons.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle
              columns={columnOptions}
              visible={visible}
              onChange={setVisible}
            />
            <button
              onClick={openCreate}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700 transition"
            >
              <Plus size={16} /> {t("coupons.new")}
            </button>
          </div>
        }
      >
        <select
          value={filterType}
          onChange={(e) => {
            setFilterType(e.target.value as FilterType);
            setPage(1);
          }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
        >
          <option value="all">{t("coupons.allTypes")}</option>
          <option value="ORDER_DISCOUNT">{t("coupons.orderDiscount")}</option>
          <option value="WALLET_CREDIT">{t("coupons.walletCredit")}</option>
        </select>
        <select
          value={filterStatus}
          onChange={(e) => {
            setFilter(e.target.value as "all" | "active" | "inactive");
            setPage(1);
          }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
        >
          <option value="all">{t("coupons.allStatuses")}</option>
          <option value="active">{t("common.active")}</option>
          <option value="inactive">{t("common.inactive")}</option>
        </select>
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

      {/* ── Table ── */}
      <DataTable<Coupon>
        columns={columns}
        rows={coupons}
        keyExtractor={(c) => c.id}
        isLoading={isLoading}
        emptyText={t("coupons.noResults")}
        emptyIcon={<Ticket size={36} className="text-gray-300" />}
      />

      {/* ── Pagination ── */}
      <TablePagination
        page={page}
        totalPages={totalPages}
        total={displayTotal}
        limit={limit}
        onPageChange={setPage}
      />

      {/* ── Modal ── */}
      {modalOpen && (
        <CouponModal
          coupon={editing}
          onClose={closeModal}
          onSaved={() => {
            closeModal();
            qc.invalidateQueries({ queryKey: ["coupons"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

// ── TypeBadge ─────────────────────────────────────────────────────────────────
function TypeBadge({
  type,
  t,
}: {
  type: CouponType;
  t: (k: string) => string;
}) {
  return type === "ORDER_DISCOUNT" ? (
    <span className="text-xs px-2.5 py-1 rounded-full bg-blue-100 text-blue-700 font-medium">
      {t("coupons.orderDiscount")}
    </span>
  ) : (
    <span className="text-xs px-2.5 py-1 rounded-full bg-purple-100 text-purple-700 font-medium">
      {t("coupons.walletCredit")}
    </span>
  );
}

// ── StatCard ──────────────────────────────────────────────────────────────────
function StatCard({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color: "indigo" | "green" | "blue" | "purple";
}) {
  const styles: Record<string, { card: string; val: string; lbl: string }> = {
    indigo: {
      card: "bg-indigo-50 border-indigo-100",
      val: "text-indigo-700",
      lbl: "text-indigo-400",
    },
    green: {
      card: "bg-green-50 border-green-100",
      val: "text-green-700",
      lbl: "text-green-400",
    },
    blue: {
      card: "bg-blue-50 border-blue-100",
      val: "text-blue-700",
      lbl: "text-blue-400",
    },
    purple: {
      card: "bg-purple-50 border-purple-100",
      val: "text-purple-700",
      lbl: "text-purple-400",
    },
  };
  const s = styles[color] ?? styles.indigo;
  return (
    <div className={cn("border rounded-2xl px-5 py-4 text-center", s.card)}>
      <p className={cn("text-3xl font-bold", s.val)}>{value}</p>
      <p className={cn("text-xs mt-1", s.lbl)}>{label}</p>
    </div>
  );
}

// ── CouponModal ───────────────────────────────────────────────────────────────
interface FormState {
  title: string;
  title_ar: string;
  code: string;
  description: string;
  description_ar: string;
  type: CouponType;
  is_active: boolean;
  is_first: boolean;
  discount_type: DiscountType;
  discount_value: string;
  scope: CouponScope;
  max_discount_cents: string;
  min_order_total_cents: string;
  wallet_amount_cents: string;
  wallet_points: string;
  max_total_uses: string;
  max_user_uses: string;
  min_orders_count: string;
  is_purchasable: boolean;
  purchase_price_cents: string;
  button_text: string;
  button_text_ar: string;
  start_at: string;
  end_at: string;
}

const DEFAULT_FORM: FormState = {
  title: "",
  title_ar: "",
  code: "",
  description: "",
  description_ar: "",
  type: "ORDER_DISCOUNT",
  is_active: true,
  is_first: false,
  discount_type: "PERCENT",
  discount_value: "",
  scope: "ORDER_TOTAL",
  max_discount_cents: "",
  min_order_total_cents: "",
  wallet_amount_cents: "",
  wallet_points: "",
  max_total_uses: "",
  max_user_uses: "",
  min_orders_count: "0",
  is_purchasable: false,
  purchase_price_cents: "",
  button_text: "",
  button_text_ar: "",
  start_at: "",
  end_at: "",
};

function CouponModal({
  coupon,
  onClose,
  onSaved,
  t,
}: {
  coupon: Coupon | null;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState<FormState>(() =>
    coupon
      ? {
          title: coupon.title,
          title_ar: coupon.title_ar ?? "",
          code: coupon.code,
          description: coupon.description ?? "",
          description_ar: coupon.description_ar ?? "",
          type: coupon.type,
          is_active: coupon.is_active,
          is_first: coupon.is_first,
          discount_type: coupon.discount_type ?? "PERCENT",
          discount_value: coupon.discount_value?.toString() ?? "",
          scope: coupon.scope,
          max_discount_cents: coupon.max_discount_cents?.toString() ?? "",
          min_order_total_cents: coupon.min_order_total_cents?.toString() ?? "",
          wallet_amount_cents: coupon.wallet_amount_cents?.toString() ?? "",
          wallet_points: coupon.wallet_points?.toString() ?? "",
          max_total_uses: coupon.max_total_uses?.toString() ?? "",
          max_user_uses: coupon.max_user_uses?.toString() ?? "",
          min_orders_count: coupon.min_orders_count?.toString() ?? "0",
          is_purchasable: coupon.is_purchasable ?? false,
          purchase_price_cents: coupon.purchase_price_cents?.toString() ?? "",
          button_text: coupon.button_text ?? "",
          button_text_ar: coupon.button_text_ar ?? "",
          start_at: coupon.start_at ? coupon.start_at.slice(0, 10) : "",
          end_at: coupon.end_at ? coupon.end_at.slice(0, 10) : "",
        }
      : DEFAULT_FORM,
  );

  const [imageFile, setImageFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(
    coupon?.image_url ?? null,
  );
  const fileRef = useRef<HTMLInputElement>(null);

  const set = (k: keyof FormState, v: string | boolean) =>
    setForm((prev) => ({ ...prev, [k]: v }));

  const saveMut = useMutation({
    mutationFn: (fd: FormData) =>
      coupon ? updateCoupon(coupon.id, fd) : createCoupon(fd),
    onSuccess: () => {
      toast.success(coupon ? t("couponForm.updated") : t("couponForm.created"));
      onSaved();
    },
    onError: () => toast.error("Save failed"),
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const fd = new FormData();
    Object.entries(form).forEach(([k, v]) => {
      if (v !== "" && v !== null && v !== undefined) fd.append(k, String(v));
    });
    if (imageFile) fd.append("image", imageFile);
    saveMut.mutate(fd);
  }

  function handleImage(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!validateImageFile(f, e.target)) return;
    setImageFile(f);
    setPreviewUrl(URL.createObjectURL(f));
  }

  const isWallet = form.type === "WALLET_CREDIT";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {coupon ? t("common.edit") : t("coupons.new")}
          </h2>
          <button
            onClick={onClose}
            className="p-2 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-6 py-5 space-y-5">
          {/* Title row */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("couponForm.titleEn")}>
              <input
                required
                value={form.title}
                onChange={(e) => set("title", e.target.value)}
                className="input"
                placeholder="Summer Deal"
              />
            </Field>
            <Field label={t("couponForm.titleAr")}>
              <input
                value={form.title_ar}
                onChange={(e) => set("title_ar", e.target.value)}
                dir="rtl"
                className="input"
                placeholder="عرض الصيف"
              />
            </Field>
          </div>

          {/* Description */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("couponForm.descEn")}>
              <input
                value={form.description}
                onChange={(e) => set("description", e.target.value)}
                className="input"
                placeholder="Coupon description"
              />
            </Field>
            <Field label={t("couponForm.descAr")}>
              <input
                value={form.description_ar}
                onChange={(e) => set("description_ar", e.target.value)}
                dir="rtl"
                className="input"
                placeholder="وصف الكوبون"
              />
            </Field>
          </div>

          {/* Code + Type */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("couponForm.code")}>
              <input
                value={form.code}
                onChange={(e) => set("code", e.target.value)}
                className="input font-mono uppercase"
                placeholder="SAVE20"
              />
            </Field>
            <Field label={t("couponForm.type")}>
              <select
                value={form.type}
                onChange={(e) => set("type", e.target.value as CouponType)}
                className="input"
              >
                <option value="ORDER_DISCOUNT">
                  {t("coupons.orderDiscount")}
                </option>
                <option value="WALLET_CREDIT">
                  {t("coupons.walletCredit")}
                </option>
              </select>
            </Field>
          </div>

          {/* Discount fields (ORDER_DISCOUNT only) */}
          {!isWallet && (
            <>
              <div className="grid grid-cols-3 gap-4">
                <Field label={t("couponForm.discountType")}>
                  <select
                    value={form.discount_type}
                    onChange={(e) =>
                      set("discount_type", e.target.value as DiscountType)
                    }
                    className="input"
                  >
                    <option value="PERCENT">Percent %</option>
                    <option value="FIXED_CENTS">Fixed (fils)</option>
                  </select>
                </Field>
                <Field label={t("couponForm.discountValue")}>
                  <input
                    type="number"
                    min="0"
                    value={form.discount_value}
                    onChange={(e) => set("discount_value", e.target.value)}
                    className="input"
                  />
                </Field>
                <Field label={t("couponForm.scope")}>
                  <select
                    value={form.scope}
                    onChange={(e) =>
                      set("scope", e.target.value as CouponScope)
                    }
                    className="input"
                  >
                    <option value="ORDER_TOTAL">Order Total</option>
                    <option value="DELIVERY_FEE">Delivery Fee</option>
                    <option value="PRODUCTS_ONLY">Products Only</option>
                    <option value="NOT_APPLICABLE">N/A</option>
                  </select>
                </Field>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <Field label={t("couponForm.maxDiscount")}>
                  <input
                    type="number"
                    min="0"
                    value={form.max_discount_cents}
                    onChange={(e) => set("max_discount_cents", e.target.value)}
                    className="input"
                    placeholder="∞"
                  />
                </Field>
                <Field label={t("couponForm.minOrderTotal")}>
                  <input
                    type="number"
                    min="0"
                    value={form.min_order_total_cents}
                    onChange={(e) =>
                      set("min_order_total_cents", e.target.value)
                    }
                    className="input"
                    placeholder="0"
                  />
                </Field>
              </div>
            </>
          )}

          {/* Wallet fields (WALLET_CREDIT only) */}
          {isWallet && (
            <div className="grid grid-cols-2 gap-4">
              <Field label={t("couponForm.walletAmount")}>
                <input
                  type="number"
                  min="0"
                  value={form.wallet_amount_cents}
                  onChange={(e) => set("wallet_amount_cents", e.target.value)}
                  className="input"
                />
              </Field>
              <Field label={t("couponForm.walletPoints")}>
                <input
                  type="number"
                  min="0"
                  value={form.wallet_points}
                  onChange={(e) => set("wallet_points", e.target.value)}
                  className="input"
                />
              </Field>
            </div>
          )}

          {/* Usage limits */}
          <div className="grid grid-cols-3 gap-4">
            <Field label={t("couponForm.maxTotal")}>
              <input
                type="number"
                min="0"
                value={form.max_total_uses}
                onChange={(e) => set("max_total_uses", e.target.value)}
                className="input"
                placeholder="∞"
              />
            </Field>
            <Field label={t("couponForm.maxUser")}>
              <input
                type="number"
                min="0"
                value={form.max_user_uses}
                onChange={(e) => set("max_user_uses", e.target.value)}
                className="input"
                placeholder="∞"
              />
            </Field>
            <Field label={t("couponForm.minOrders")}>
              <input
                type="number"
                min="0"
                value={form.min_orders_count}
                onChange={(e) => set("min_orders_count", e.target.value)}
                className="input"
              />
            </Field>
          </div>

          {/* Validity */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("couponForm.startAt")}>
              <input
                type="date"
                value={form.start_at}
                onChange={(e) => set("start_at", e.target.value)}
                className="input"
              />
            </Field>
            <Field label={t("couponForm.endAt")}>
              <input
                type="date"
                value={form.end_at}
                onChange={(e) => set("end_at", e.target.value)}
                className="input"
              />
            </Field>
          </div>

          {/* Checkboxes */}
          <div className="flex items-center gap-6 flex-wrap">
            <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => set("is_active", e.target.checked)}
                className="w-4 h-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              {t("couponForm.isActive")}
            </label>
            <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
              <input
                type="checkbox"
                checked={form.is_first}
                onChange={(e) => set("is_first", e.target.checked)}
                className="w-4 h-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              {t("couponForm.isFirst")}
            </label>
            <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
              <input
                type="checkbox"
                checked={form.is_purchasable}
                onChange={(e) => set("is_purchasable", e.target.checked)}
                className="w-4 h-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              {t("couponForm.isPurchasable")}
            </label>
          </div>

          {/* Purchase fields */}
          {form.is_purchasable && (
            <div className="grid grid-cols-2 gap-4">
              <Field label={t("couponForm.purchasePrice")}>
                <input
                  type="number"
                  min="0"
                  value={form.purchase_price_cents}
                  onChange={(e) => set("purchase_price_cents", e.target.value)}
                  className="input"
                />
              </Field>
            </div>
          )}

          {/* Button text */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("couponForm.buttonText")}>
              <input
                value={form.button_text}
                onChange={(e) => set("button_text", e.target.value)}
                className="input"
                placeholder="Use Coupon"
              />
            </Field>
            <Field label={t("couponForm.buttonTextAr")}>
              <input
                value={form.button_text_ar}
                onChange={(e) => set("button_text_ar", e.target.value)}
                dir="rtl"
                className="input"
                placeholder="استخدم الكوبون"
              />
            </Field>
          </div>

          {/* Image */}
          <Field label={t("couponForm.image")}>
            <div className="flex items-center gap-4">
              {previewUrl && (
                <img
                  src={previewUrl}
                  alt="preview"
                  className="w-16 h-16 rounded-xl object-cover border border-gray-200"
                />
              )}
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2.5 border-2 border-dashed border-gray-300 rounded-xl text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition"
              >
                <Upload size={16} /> {t("common.uploadPhoto")}
              </button>
              <input
                ref={fileRef}
                type="file"
                accept={ALLOWED_IMAGE_ACCEPT}
                className="hidden"
                onChange={handleImage}
              />
            </div>
          </Field>

          {/* Footer */}
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50 transition"
            >
              {t("common.cancel")}
            </button>
            <button
              type="submit"
              disabled={saveMut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition"
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

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label className="text-xs font-semibold text-gray-600 uppercase tracking-wide">
        {label}
      </label>
      {children}
    </div>
  );
}
