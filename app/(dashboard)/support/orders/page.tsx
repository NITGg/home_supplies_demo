"use client";
import { Fragment, useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import api from "@/lib/api";
import {
  ClipboardList,
  RefreshCw,
  Search,
  ChevronLeft,
  ChevronRight,
  X,
  Check,
  AlertTriangle,
  Truck,
  RotateCcw,
  Ban,
  ChevronDown,
  Phone,
  MessageSquare,
  AlertCircle,
  ChevronUp,
} from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";

// ── Helpers ───────────────────────────────────────────────────────────────────
const STATUS_STYLES: Record<string, string> = {
  PENDING: "bg-amber-100 text-amber-700",
  IN_PROGRESS: "bg-blue-100 text-blue-700",
  DELIVERED: "bg-green-100 text-green-700",
  CANCELLED: "bg-red-100 text-red-700",
  EXPIRED: "bg-gray-100 text-gray-600",
  SEARCHING_FAILED: "bg-orange-100 text-orange-700",
};

// Recoverable: assign / retry / soft-cancel all work for these states.
// EXPIRED is included — same failure as SEARCHING_FAILED (no courier accepted in time).
const RECOVERABLE_STATUSES = ["PENDING", "SEARCHING_FAILED", "EXPIRED"];

function fmt(cents?: number | null) {
  if (cents == null) return "—";
  return `${(Number(cents) / 100).toFixed(2)} EGP`;
}
function fmtDate(d?: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

// ── Assign Courier Modal ──────────────────────────────────────────────────────
// POST /admin/orders/:orderId/assign
// Body: { courier_id: number, admin_notes: string, agreed_total_fee?: number }
function AssignModal({ order, onClose }: { order: any; onClose: () => void }) {
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [notes, setNotes] = useState("");
  const [agreedFee, setAgreedFee] = useState("");

  const { data: couriersData, isLoading } = useQuery({
    queryKey: ["online-couriers-assign"],
    queryFn: async () => {
      const res = await api.get("/users/online-couriers");
      return res.data?.online_courier_ids?.couriers ?? res.data?.couriers ?? [];
    },
    staleTime: 30_000,
  });
console.log("couriersData", couriersData);

  const couriers: any[] = (couriersData ?? []).filter(
    (c: any) =>
      !search ||
      c.user.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      c.user.phone?.includes(search),
  );

  const assignMut = useMutation({
    mutationFn: async () => {
      await api.post(`/admin/orders/${order.id}/assign`, {
        courier_id: selectedId,
        admin_notes: notes,
        ...(agreedFee ? { agreed_total_fee: Number(agreedFee) } : {}),
      });
    },
    onSuccess: () => {
      toast.success("Courier assigned");
      qc.invalidateQueries({ queryKey: ["support-orders"] });
      onClose();
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? "Assignment failed"),
  });

  const canSubmit =
    !!selectedId && notes.trim().length > 0 && !assignMut.isPending;

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md flex flex-col max-h-[85vh]">
        <div className="flex items-center justify-between p-5 border-b border-gray-100 shrink-0">
          <div>
            <h2 className="text-base font-semibold text-gray-900">
              Assign Courier
            </h2>
            <p className="text-xs text-gray-400">
              Order #{order.order_number ?? order.id}
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={18} />
          </button>
        </div>

        {/* Courier search list */}
        <div className="p-4 border-b border-gray-100 shrink-0">
          <div className="relative">
            <Search
              size={13}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
            />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by name or phone…"
              className="w-full pl-8 pr-4 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>
        <div className="overflow-y-auto flex-1 p-2 min-h-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <RefreshCw size={20} className="animate-spin text-indigo-400" />
            </div>
          ) : couriers.length === 0 ? (
            <p className="text-center text-sm text-gray-400 py-8">
              No online couriers found
            </p>
          ) : (
            couriers.map((c: any) => (
              <button
                key={c.id}
                onClick={() => setSelectedId(c.id)}
                className={cn(
                  "w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left transition mb-0.5",
                  selectedId === c.id
                    ? "bg-indigo-50 ring-1 ring-indigo-300"
                    : "hover:bg-gray-50",
                )}
              >
                <div className="w-8 h-8 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-xs shrink-0">
                  {c.user.full_name?.[0] ?? "C"}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {c.user.full_name ?? "—"}
                  </p>
                  {c.user.phone && (
                    <p className="text-xs text-gray-400 flex items-center gap-1">
                      <Phone size={10} />
                      {c.user.phone}
                    </p>
                  )}
                </div>
                {selectedId === c.id && (
                  <Check size={15} className="text-indigo-600 shrink-0" />
                )}
              </button>
            ))
          )}
        </div>

        {/* Required fields */}
        <div className="p-4 border-t border-gray-100 space-y-3 shrink-0">
          <div>
            <label className="text-xs text-gray-500 block mb-1">
              Admin notes <span className="text-red-500">*</span>
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              placeholder="Reason for manual assignment…"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
            />
          </div>
          <div>
            <label className="text-xs text-gray-500 block mb-1">
              Agreed fee override{" "}
              <span className="text-gray-400">(optional, in cents)</span>
            </label>
            <input
              type="number"
              min={0}
              value={agreedFee}
              onChange={(e) => setAgreedFee(e.target.value)}
              placeholder="e.g. 5000 = 50.00 EGP"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="flex justify-end gap-2 p-4 border-t border-gray-100 shrink-0">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={() => assignMut.mutate()}
            disabled={!canSubmit}
            className="flex items-center gap-2 px-4 py-2 text-sm bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50"
          >
            {assignMut.isPending ? (
              <RefreshCw size={13} className="animate-spin" />
            ) : (
              <Truck size={13} />
            )}
            Assign
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Retry Modal ───────────────────────────────────────────────────────────────
// POST /admin/orders/:orderId/retry
// Body: { admin_notes: string, new_delivery_fee?: number,
//         deadline_extension_minutes?: number, expiry_extension_minutes?: number }
function RetryModal({ order, onClose }: { order: any; onClose: () => void }) {
  const qc = useQueryClient();
  const [notes, setNotes] = useState("");
  const [newFee, setNewFee] = useState("");
  const [deadline, setDeadline] = useState("10");
  const [expiry, setExpiry] = useState("30");

  const retryMut = useMutation({
    mutationFn: async () => {
      await api.post(`/admin/orders/${order.id}/retry`, {
        admin_notes: notes,
        deadline_extension_minutes: Number(deadline),
        expiry_extension_minutes: Number(expiry),
        ...(newFee ? { new_delivery_fee: Number(newFee) } : {}),
      });
    },
    onSuccess: () => {
      toast.success("Order re-queued for bidding");
      qc.invalidateQueries({ queryKey: ["support-orders"] });
      onClose();
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? "Retry failed"),
  });

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <div>
            <h2 className="text-base font-semibold text-gray-900">
              Retry Bidding
            </h2>
            <p className="text-xs text-gray-400">
              Order #{order.order_number ?? order.id}
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={18} />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <div className="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-xl p-3">
            <AlertTriangle
              size={15}
              className="text-amber-500 mt-0.5 shrink-0"
            />
            <p className="text-xs text-amber-700">
              Re-opens bidding so couriers can accept again. Extends deadlines
              from now.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs text-gray-500 block mb-1">
                Deadline extension (min)
              </label>
              <input
                type="number"
                min={1}
                max={120}
                value={deadline}
                onChange={(e) => setDeadline(e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>
            <div>
              <label className="text-xs text-gray-500 block mb-1">
                Expiry extension (min)
              </label>
              <input
                type="number"
                min={1}
                max={1440}
                value={expiry}
                onChange={(e) => setExpiry(e.target.value)}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>
          </div>

          <div>
            <label className="text-xs text-gray-500 block mb-1">
              New delivery fee{" "}
              <span className="text-gray-400">(optional, in cents)</span>
            </label>
            <input
              type="number"
              min={0}
              value={newFee}
              onChange={(e) => setNewFee(e.target.value)}
              placeholder="Leave empty to keep current fee"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div>
            <label className="text-xs text-gray-500 block mb-1">
              Admin notes <span className="text-red-500">*</span>
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
              placeholder="Why is this order being retried?…"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
            />
          </div>
        </div>
        <div className="flex justify-end gap-2 p-5 border-t border-gray-100">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={() => retryMut.mutate()}
            disabled={!notes.trim() || retryMut.isPending}
            className="flex items-center gap-2 px-4 py-2 text-sm bg-amber-600 text-white rounded-xl hover:bg-amber-700 disabled:opacity-50"
          >
            {retryMut.isPending ? (
              <RefreshCw size={13} className="animate-spin" />
            ) : (
              <RotateCcw size={13} />
            )}
            Retry Bidding
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Soft-Cancel Modal ─────────────────────────────────────────────────────────
// POST /admin/orders/:orderId/soft-cancel
// Body: { cancellation_fee?: number, admin_notes?: string }
function SoftCancelModal({
  order,
  onClose,
}: {
  order: any;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [notes, setCancelNotes] = useState("");
  const [cancelFee, setCancelFee] = useState("");

  const cancelMut = useMutation({
    mutationFn: async () => {
      await api.post(`/admin/orders/${order.id}/soft-cancel`, {
        ...(notes ? { admin_notes: notes } : {}),
        ...(cancelFee ? { cancellation_fee: Number(cancelFee) } : {}),
      });
    },
    onSuccess: () => {
      toast.success("Order soft-cancelled & refund queued");
      qc.invalidateQueries({ queryKey: ["support-orders"] });
      onClose();
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? "Cancellation failed"),
  });

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <div>
            <h2 className="text-base font-semibold text-gray-900">
              Soft-Cancel Order
            </h2>
            <p className="text-xs text-gray-400">
              Order #{order.order_number ?? order.id}
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={18} />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <div className="flex items-start gap-3 bg-red-50 border border-red-200 rounded-xl p-3">
            <AlertTriangle size={15} className="text-red-500 mt-0.5 shrink-0" />
            <p className="text-xs text-red-700">
              Cancels the order with <strong>NO_COURIERS_AVAILABLE</strong>{" "}
              reason and queues a full refund (minus any cancellation fee).
            </p>
          </div>

          <div>
            <label className="text-xs text-gray-500 block mb-1">
              Cancellation fee{" "}
              <span className="text-gray-400">
                (optional, in cents — 0 = full refund)
              </span>
            </label>
            <input
              type="number"
              min={0}
              value={cancelFee}
              onChange={(e) => setCancelFee(e.target.value)}
              placeholder="e.g. 1000 = 10.00 EGP"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div>
            <label className="text-xs text-gray-500 block mb-1">
              Admin notes <span className="text-gray-400">(optional)</span>
            </label>
            <textarea
              value={notes}
              onChange={(e) => setCancelNotes(e.target.value)}
              rows={3}
              placeholder="e.g. Customer contacted, agreed to cancel…"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
            />
          </div>
        </div>
        <div className="flex justify-end gap-2 p-5 border-t border-gray-100">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
          >
            Keep Order
          </button>
          <button
            onClick={() => cancelMut.mutate()}
            disabled={cancelMut.isPending}
            className="flex items-center gap-2 px-4 py-2 text-sm bg-red-600 text-white rounded-xl hover:bg-red-700 disabled:opacity-50"
          >
            {cancelMut.isPending ? (
              <RefreshCw size={13} className="animate-spin" />
            ) : (
              <Ban size={13} />
            )}
            Soft-Cancel
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Actions dropdown ──────────────────────────────────────────────────────────
function ActionMenu({
  order,
  onAssign,
  onRetry,
  onCancel,
}: {
  order: any;
  onAssign: () => void;
  onRetry: () => void;
  onCancel: () => void;
}) {
  const [open, setOpen] = useState(false);

  // All actions (assign, retry, soft-cancel) only work in recoverable states
  const isRecoverable = RECOVERABLE_STATUSES.includes(order.status);

  // No actions available
  if (!isRecoverable) {
    return <span className="text-xs text-gray-300">—</span>;
  }

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-1 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs font-medium text-gray-600 hover:bg-gray-50 transition"
      >
        Actions <ChevronDown size={11} />
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute right-0 top-8 z-20 bg-white border border-gray-200 rounded-xl shadow-lg w-48 py-1 text-sm overflow-hidden">
            <button
              onClick={() => {
                setOpen(false);
                onAssign();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 hover:bg-gray-50 text-gray-700 text-left"
            >
              <Truck size={13} className="text-indigo-500 shrink-0" />
              <span>Assign Courier</span>
            </button>
            <button
              onClick={() => {
                setOpen(false);
                onRetry();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 hover:bg-gray-50 text-gray-700 text-left"
            >
              <RotateCcw size={13} className="text-amber-500 shrink-0" />
              <span>Retry Bidding</span>
            </button>
            <div className="my-1 border-t border-gray-100" />
            <button
              onClick={() => {
                setOpen(false);
                onCancel();
              }}
              className="w-full flex items-center gap-2.5 px-3 py-2 hover:bg-red-50 text-red-600 text-left"
            >
              <Ban size={13} className="shrink-0" />
              <span>Soft-Cancel</span>
            </button>
          </div>
        </>
      )}
    </div>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────
export default function SupportOrdersPage() {
  const [page, setPage]               = useState(1);
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch]           = useState(""); // debounced
  const [status, setStatus]           = useState("");
  const [dateFrom, setDateFrom]       = useState("");
  const [dateTo, setDateTo]           = useState("");

  const [assignOrder, setAssignOrder]         = useState<any>(null);
  const [retryOrder, setRetryOrder]           = useState<any>(null);
  const [cancelOrder, setCancelOrder]         = useState<any>(null);
  const [expandedOrderId, setExpandedOrderId] = useState<number | null>(null);

  const limit = 25;

  // Debounce: fire query 400 ms after user stops typing
  useEffect(() => {
    const t = setTimeout(() => { setSearch(searchInput); setPage(1); }, 400);
    return () => clearTimeout(t);
  }, [searchInput]);

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["support-orders", page, search, status, dateFrom, dateTo],
    queryFn: async () => {
      const params: Record<string, any> = {
        limit,
        skip: (page - 1) * limit,
        includes: "customer,courier.user,issues",
        ...(search   && { keyword:search }),
        ...(status   && { status }),
        ...(dateFrom && { "created_at[gte]": new Date(dateFrom).toISOString() }),
        ...(dateTo   && { "created_at[lte]": new Date(`${dateTo}T23:59:59`).toISOString() }),
      };
      const res = await api.get("/admin/orders", { params });
      return res.data;
    },
    staleTime: 30_000,
  });

  const orders: any[] = data?.orders ?? [];
  const total: number = data?.totalOrders ?? orders.length;
  const totalPages = Math.ceil(total / limit);

  return (
    <div className="p-6 space-y-5">
      {assignOrder && (
        <AssignModal order={assignOrder} onClose={() => setAssignOrder(null)} />
      )}
      {retryOrder && (
        <RetryModal order={retryOrder} onClose={() => setRetryOrder(null)} />
      )}
      {cancelOrder && (
        <SoftCancelModal
          order={cancelOrder}
          onClose={() => setCancelOrder(null)}
        />
      )}

      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <ClipboardList size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">All Orders</h1>
            <p className="text-xs text-gray-500">
              {total.toLocaleString()} orders — assign · retry · soft-cancel
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
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            onKeyDown={(e) => {
              // allow instant search on Enter
              if (e.key === "Enter") { setSearch(searchInput); setPage(1); }
            }}
            placeholder="Order #, customer…"
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
        <div className="flex items-center gap-2">
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => {
              setDateFrom(e.target.value);
              setPage(1);
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
            }}
            className="border border-gray-200 rounded-lg text-sm px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-500"
          />
          {(dateFrom || dateTo) && (
            <button
              onClick={() => {
                setDateFrom("");
                setDateTo("");
              }}
              className="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg"
            >
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-x-auto">
        {isLoading ? (
          <div className="flex items-center justify-center py-16">
            <RefreshCw size={24} className="animate-spin text-indigo-400" />
          </div>
        ) : orders.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <ClipboardList size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">No orders found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                {[
                  "#",
                  "Customer",
                  "Courier",
                  "Courier Fee",
                  "Status",
                  "Date",
                  "Issues",
                  "Actions",
                ].map((h) => (
                  <th
                    key={h}
                    className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.map((o: any) => {
                const hasIssues = o.issues && o.issues.length > 0;
                const isExpanded = expandedOrderId === o.id;
                return (
                  <Fragment key={o.id}>
                    <tr className="hover:bg-gray-50 transition">
                      <td className="px-4 py-3 font-mono text-xs text-gray-500 whitespace-nowrap">
                        #{o.order_number ?? o.id}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <Link
                            href={`/support/chat?userId=${o.customer?.id}`}
                            className="p-1 text-indigo-600 hover:bg-indigo-50 rounded transition"
                            title={`Chat with ${o.customer?.full_name}`}
                          >
                            <MessageSquare size={13} />
                          </Link>
                          <div>
                            <p className="font-medium text-gray-900 text-xs">
                              {o.customer?.full_name ?? "—"}
                            </p>
                            {o.customer?.phone && (
                              <a
                                href={`tel:${o.customer.phone}`}
                                className="flex items-center gap-1 text-[11px] text-gray-400 hover:text-green-600"
                              >
                                <Phone size={9} />
                                {o.customer.phone}
                              </a>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-600">
                        {o.courier?.user ? (
                          <Link
                            href={`/support/users?role=Courier&search=${encodeURIComponent(o.courier.user.full_name)}`}
                            className="hover:text-indigo-600 hover:underline transition"
                          >
                            {o.courier.user.full_name}
                          </Link>
                        ) : (
                          <span className="text-gray-400 italic">
                            Unassigned
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-xs font-medium">
                        {fmt(o.courier_fee)}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={cn(
                            "px-2 py-0.5 rounded-full text-xs font-medium whitespace-nowrap",
                            STATUS_STYLES[o.status] ??
                              "bg-gray-100 text-gray-700",
                          )}
                        >
                          {o.status?.replace(/_/g, " ")}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {fmtDate(o.created_at)}
                      </td>
                      <td className="px-4 py-3">
                        {hasIssues ? (
                          <button
                            onClick={() =>
                              setExpandedOrderId(isExpanded ? null : o.id)
                            }
                            className="flex items-center gap-1 px-2 py-1 text-xs bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition"
                          >
                            <AlertCircle size={12} />
                            {o.issues.length}
                            {isExpanded ? (
                              <ChevronUp size={12} />
                            ) : (
                              <ChevronDown size={12} />
                            )}
                          </button>
                        ) : (
                          <span className="text-xs text-gray-300">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <ActionMenu
                          order={o}
                          onAssign={() => setAssignOrder(o)}
                          onRetry={() => setRetryOrder(o)}
                          onCancel={() => setCancelOrder(o)}
                        />
                      </td>
                    </tr>
                    {isExpanded && hasIssues && (
                      <tr className="bg-red-50 border-t-2 border-red-200">
                        <td colSpan={8} className="px-4 py-4">
                          <div className="space-y-2">
                            <p className="text-xs font-semibold text-red-900 mb-3">
                              Order Issues
                            </p>
                            {o.issues.map((issue: any, idx: number) => (
                              <div
                                key={idx}
                                className="flex items-start gap-3 bg-white rounded-lg p-3 border border-red-100"
                              >
                                <AlertCircle
                                  size={14}
                                  className="text-red-600 shrink-0 mt-0.5"
                                />
                                <div className="flex-1 min-w-0">
                                  <p className="text-xs font-medium text-gray-900">
                                    {issue.title ?? issue.type ?? "Issue"}
                                  </p>
                                  {issue.description && (
                                    <p className="text-xs text-gray-600 mt-1">
                                      {issue.description}
                                    </p>
                                  )}
                                  <div className="flex items-center gap-2 mt-2">
                                    {issue.status && (
                                      <span
                                        className={cn(
                                          "text-[10px] px-1.5 py-0.5 rounded font-medium",
                                          issue.status === "RESOLVED"
                                            ? "bg-green-100 text-green-700"
                                            : issue.status === "DISMISSED"
                                              ? "bg-gray-100 text-gray-600"
                                              : "bg-amber-100 text-amber-700",
                                        )}
                                      >
                                        {issue.status}
                                      </span>
                                    )}
                                    {issue.created_at && (
                                      <span className="text-[10px] text-gray-500">
                                        {fmtDate(issue.created_at)}
                                      </span>
                                    )}
                                  </div>
                                </div>
                                {issue.chat_id && (
                                  <Link
                                    href={`/support/chat?issueId=${issue.id}`}
                                    className="p-1 text-indigo-600 hover:bg-indigo-50 rounded transition shrink-0"
                                    title="View related chat"
                                  >
                                    <MessageSquare size={13} />
                                  </Link>
                                )}
                              </div>
                            ))}
                          </div>
                        </td>
                      </tr>
                    )}
                  </Fragment>
                );
              })}
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
