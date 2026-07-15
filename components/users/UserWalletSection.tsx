"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchWallets,
  fetchTransactions,
  fetchPenalties,
  fetchUnpaidCommissions,
  fetchEscrows,
  fetchPaymentMethods,
  freezeWallet,
  unfreezeWallet,
  adjustBalance,
  applyPenalty,
  waivePenalty,
  type Wallet,
  type WalletTransaction,
  type WalletPenalty,
  type UnpaidCommission,
  type WalletEscrow,
  type PaymentMethod,
} from "@/lib/wallet";
import {
  Wallet as WalletIcon,
  Snowflake,
  Sun,
  Plus,
  Minus,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Percent,
  Lock,
  CreditCard,
  Receipt,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { TablePagination } from "@/components/ui/TablePagination";
import toast from "react-hot-toast";

const LIMIT = 10;

function fmt(n: number | string) {
  return `${(Number(n) / 100).toFixed(2)} EGP`;
}
function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

const TX_STATUS_COLOR: Record<string, string> = {
  COMPLETED: "bg-green-100 text-green-700",
  PENDING: "bg-yellow-100 text-yellow-700",
  FAILED: "bg-red-100 text-red-700",
  CANCELLED: "bg-gray-100 text-gray-600",
  REFUNDED: "bg-blue-100 text-blue-700",
};
const TX_STATUSES = ["COMPLETED", "PENDING", "FAILED", "CANCELLED", "REFUNDED"];

/** Card shell for a paginated list section: title, optional filter row, body, pagination. */
function SectionCard({
  title,
  icon,
  filters,
  total,
  totalPages,
  page,
  onPage,
  children,
}: {
  title: string;
  icon: React.ReactNode;
  filters?: React.ReactNode;
  total: number;
  totalPages: number;
  page: number;
  onPage: (p: number) => void;
  children: React.ReactNode;
}) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <div className="flex items-center justify-between flex-wrap gap-3 mb-4">
        <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
          {icon} {title}
          {total > 0 && (
            <span className="text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 font-medium">
              {total}
            </span>
          )}
        </h2>
        {filters && (
          <div className="flex items-end gap-3 flex-wrap">{filters}</div>
        )}
      </div>
      {children}
      <TablePagination
        page={page}
        totalPages={totalPages}
        total={total}
        limit={LIMIT}
        onPageChange={onPage}
      />
    </div>
  );
}

/** Small labelled boolean (All / Yes / No) select used by several filters. */
function BoolFilter({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="space-y-1">
      <span className="block text-xs text-gray-500 whitespace-nowrap">
        {label}
      </span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 text-gray-700 bg-white"
      >
        <option value="">All</option>
        <option value="true">Yes</option>
        <option value="false">No</option>
      </select>
    </div>
  );
}

// ─── Unpaid Commission ────────────────────────────────────────────────────────
function CommissionsSection({ userId }: { userId: number }) {
  const [page, setPage] = useState(1);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [isPaid, setIsPaid] = useState("");

  const params: Record<string, string | number> = {
    user_id: userId,
    page,
    limit: LIMIT,
  };
  if (from) params.created_atFrom = from;
  if (to) params.created_atTo = to;
  if (isPaid) params.is_paid = isPaid;

  const { data, isLoading } = useQuery({
    queryKey: ["user-commissions", userId, page, from, to, isPaid],
    queryFn: () => fetchUnpaidCommissions(params),
    enabled: !!userId,
  });
  const rows: UnpaidCommission[] = data?.unpaidCommissions ?? [];
  const reset = () => setPage(1);

  return (
    <SectionCard
      title="Unpaid Commission"
      icon={<Percent size={18} className="text-orange-600" />}
      total={data?.pagination?.total ?? 0}
      totalPages={data?.pagination?.total_pages ?? 1}
      page={page}
      onPage={setPage}
      filters={
        <>
          <DateRangeFilter
            label="Created At"
            from={from}
            to={to}
            onFromChange={(v) => {
              setFrom(v);
              reset();
            }}
            onToChange={(v) => {
              setTo(v);
              reset();
            }}
          />
          <BoolFilter
            label="Paid"
            value={isPaid}
            onChange={(v) => {
              setIsPaid(v);
              reset();
            }}
          />
        </>
      }
    >
      {isLoading ? (
        <p className="text-sm text-gray-500">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-gray-500">No unpaid commissions.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  ID
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Order
                </th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Amount
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Paid
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Created
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Paid At
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {rows.map((c) => (
                <tr key={c.id} className="hover:bg-gray-50">
                  <td className="py-2 px-3 text-gray-900">#{c.id}</td>
                  <td className="py-2 px-3 text-gray-700">
                    {c.order_id ? `#${c.order_id}` : "—"}
                  </td>
                  <td className="py-2 px-3 text-right font-semibold text-orange-600">
                    {fmt(c.amount)}
                  </td>
                  <td className="py-2 px-3">
                    {c.is_paid ? (
                      <CheckCircle size={14} className="text-green-500" />
                    ) : (
                      <XCircle size={14} className="text-gray-300" />
                    )}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {fmtDate(c.created_at)}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {c.paid_at ? fmtDate(c.paid_at) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </SectionCard>
  );
}

// ─── Penalties ────────────────────────────────────────────────────────────────
function PenaltiesSection({ userId }: { userId: number }) {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [isPaid, setIsPaid] = useState("");
  const [isWaived, setIsWaived] = useState("");

  const params: Record<string, string | number> = {
    user_id: userId,
    page,
    limit: LIMIT,
  };
  if (from) params.created_atFrom = from;
  if (to) params.created_atTo = to;
  if (isPaid) params.is_paid = isPaid;
  if (isWaived) params.is_waived = isWaived;

  const { data, isLoading } = useQuery({
    queryKey: ["user-penalties", userId, page, from, to, isPaid, isWaived],
    queryFn: () => fetchPenalties(params),
    enabled: !!userId,
  });
  const rows: WalletPenalty[] = data?.penalties ?? [];
  const reset = () => setPage(1);

  const waiveMut = useMutation({
    mutationFn: (id: number) => waivePenalty(id),
    onSuccess: () => {
      toast.success("Penalty waived");
      qc.invalidateQueries({ queryKey: ["user-penalties", userId] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  return (
    <SectionCard
      title="Penalties"
      icon={<AlertTriangle size={18} className="text-red-600" />}
      total={data?.pagination?.total ?? 0}
      totalPages={data?.pagination?.total_pages ?? 1}
      page={page}
      onPage={setPage}
      filters={
        <>
          <DateRangeFilter
            label="Created At"
            from={from}
            to={to}
            onFromChange={(v) => {
              setFrom(v);
              reset();
            }}
            onToChange={(v) => {
              setTo(v);
              reset();
            }}
          />
          <BoolFilter
            label="Paid"
            value={isPaid}
            onChange={(v) => {
              setIsPaid(v);
              reset();
            }}
          />
          <BoolFilter
            label="Waived"
            value={isWaived}
            onChange={(v) => {
              setIsWaived(v);
              reset();
            }}
          />
        </>
      }
    >
      {isLoading ? (
        <p className="text-sm text-gray-500">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-gray-500">No penalties.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  ID
                </th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Amount
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Reason
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Paid
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Waived
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Date
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Action
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {rows.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <td className="py-2 px-3 text-gray-900">#{p.id}</td>
                  <td className="py-2 px-3 text-right font-semibold text-gray-900">
                    {fmt(p.amount)}
                  </td>
                  <td className="py-2 px-3 text-gray-900">{p.reason}</td>
                  <td className="py-2 px-3">
                    {p.is_paid ? (
                      <CheckCircle size={14} className="text-green-500" />
                    ) : (
                      <XCircle size={14} className="text-gray-300" />
                    )}
                  </td>
                  <td className="py-2 px-3">
                    {p.is_waived ? (
                      <CheckCircle size={14} className="text-blue-500" />
                    ) : (
                      <XCircle size={14} className="text-gray-300" />
                    )}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {fmtDate(p.created_at)}
                  </td>
                  <td className="py-2 px-3">
                    {!p.is_waived && !p.is_paid && (
                      <button
                        onClick={() => waiveMut.mutate(p.id)}
                        disabled={waiveMut.isPending}
                        className="px-2 py-1 text-xs bg-blue-50 text-blue-700 border border-blue-200 rounded hover:bg-blue-100"
                      >
                        Waive
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </SectionCard>
  );
}

// ─── Escrows ──────────────────────────────────────────────────────────────────
function EscrowsSection({ walletId }: { walletId: number | undefined }) {
  const [page, setPage] = useState(1);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const params: Record<string, string | number> = {
    wallet_id: walletId!,
    page,
    limit: LIMIT,
  };
  if (from) params.created_atFrom = from;
  if (to) params.created_atTo = to;

  const { data, isLoading } = useQuery({
    queryKey: ["user-escrows", walletId, page, from, to],
    queryFn: () => fetchEscrows(params),
    enabled: !!walletId,
  });
  const rows: WalletEscrow[] = data?.escrows ?? [];
  const reset = () => setPage(1);

  return (
    <SectionCard
      title="Escrows"
      icon={<Lock size={18} className="text-amber-600" />}
      total={data?.pagination?.total ?? 0}
      totalPages={data?.pagination?.total_pages ?? 1}
      page={page}
      onPage={setPage}
      filters={
        walletId ? (
          <DateRangeFilter
            label="Created At"
            from={from}
            to={to}
            onFromChange={(v) => {
              setFrom(v);
              reset();
            }}
            onToChange={(v) => {
              setTo(v);
              reset();
            }}
          />
        ) : undefined
      }
    >
      {!walletId ? (
        <p className="text-sm text-gray-500">
          No wallet — escrows unavailable.
        </p>
      ) : isLoading ? (
        <p className="text-sm text-gray-500">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-gray-500">No escrows.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  ID
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Order
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Wallet
                </th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Held Amount
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Created
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Updated
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {rows.map((e) => (
                <tr key={e.id} className="hover:bg-gray-50">
                  <td className="py-2 px-3 text-gray-900">#{e.id}</td>
                  <td className="py-2 px-3 text-gray-700">
                    {e.order_id ? `#${e.order_id}` : "—"}
                  </td>
                  <td className="py-2 px-3 text-gray-700">#{e.wallet_id}</td>
                  <td className="py-2 px-3 text-right font-semibold text-amber-600">
                    {fmt(e.held_amount)}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {fmtDate(e.created_at)}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {fmtDate(e.updated_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </SectionCard>
  );
}

// ─── Payment Methods ──────────────────────────────────────────────────────────
function PaymentMethodsSection({ userId }: { userId: number }) {
  const [page, setPage] = useState(1);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [isDefault, setIsDefault] = useState("");

  const params: Record<string, string | number> = {
    user_id: userId,
    page,
    limit: LIMIT,
  };
  if (from) params["created_at[gte]"] = from;
  if (to) params["created_at[lte]"] = to;
  if (isDefault) params.is_default = isDefault;

  const { data, isLoading } = useQuery({
    queryKey: ["user-payment-methods", userId, page, from, to, isDefault],
    queryFn: () => fetchPaymentMethods(params),
    enabled: !!userId,
  });
  const rows: PaymentMethod[] = data?.paymentMethods ?? [];
  const reset = () => setPage(1);

  return (
    <SectionCard
      title="Payment Methods"
      icon={<CreditCard size={18} className="text-purple-600" />}
      total={data?.pagination?.total ?? 0}
      totalPages={data?.pagination?.total_pages ?? 1}
      page={page}
      onPage={setPage}
      filters={
        <>
          <DateRangeFilter
            label="Created At"
            from={from}
            to={to}
            onFromChange={(v) => {
              setFrom(v);
              reset();
            }}
            onToChange={(v) => {
              setTo(v);
              reset();
            }}
          />
          <BoolFilter
            label="Default"
            value={isDefault}
            onChange={(v) => {
              setIsDefault(v);
              reset();
            }}
          />
        </>
      }
    >
      {isLoading ? (
        <p className="text-sm text-gray-500">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-gray-500">No payment methods.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  ID
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Type
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Provider
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Display Name
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Default
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Created
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {rows.map((pm) => (
                <tr key={pm.id} className="hover:bg-gray-50">
                  <td className="py-2 px-3 text-gray-900">#{pm.id}</td>
                  <td className="py-2 px-3">
                    <span className="text-xs px-2 py-0.5 rounded-full bg-purple-100 text-purple-700">
                      {pm.method_type}
                    </span>
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {pm.provider ?? "—"}
                  </td>
                  <td className="py-2 px-3 text-gray-900">
                    {pm.display_name ?? "—"}
                  </td>
                  <td className="py-2 px-3">
                    {pm.is_default ? (
                      <CheckCircle size={14} className="text-green-500" />
                    ) : (
                      <XCircle size={14} className="text-gray-300" />
                    )}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {fmtDate(pm.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </SectionCard>
  );
}

// ─── Transactions ─────────────────────────────────────────────────────────────
function TransactionsSection({ walletId }: { walletId: number }) {
  const [page, setPage] = useState(1);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [status, setStatus] = useState("");

  const params: Record<string, string | number> = {
    wallet_id: walletId,
    page,
    limit: LIMIT,
  };
  if (from) params["created_at[gte]"] = from;
  if (to) params["created_at[lte]"] = to;
  if (status) params.status = status;

  const { data, isLoading } = useQuery({
    queryKey: ["user-transactions", walletId, page, from, to, status],
    queryFn: () => fetchTransactions(params),
    enabled: !!walletId,
  });
  const rows: WalletTransaction[] = data?.transactions ?? [];
  const reset = () => setPage(1);

  return (
    <SectionCard
      title="Transactions"
      icon={<Receipt size={18} className="text-indigo-600" />}
      total={data?.pagination?.total ?? 0}
      totalPages={data?.pagination?.total_pages ?? 1}
      page={page}
      onPage={setPage}
      filters={
        <>
          <DateRangeFilter
            label="Created At"
            from={from}
            to={to}
            onFromChange={(v) => {
              setFrom(v);
              reset();
            }}
            onToChange={(v) => {
              setTo(v);
              reset();
            }}
          />
          <div className="space-y-1">
            <span className="block text-xs text-gray-500 whitespace-nowrap">
              Status
            </span>
            <select
              value={status}
              onChange={(e) => {
                setStatus(e.target.value);
                reset();
              }}
              className="border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 text-gray-700 bg-white"
            >
              <option value="">All</option>
              {TX_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
        </>
      }
    >
      {isLoading ? (
        <p className="text-sm text-gray-500">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-gray-500">No transactions.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  ID
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Type
                </th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Amount
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Status
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Description
                </th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-gray-700 uppercase">
                  Date
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {rows.map((tx) => (
                <tr key={tx.id} className="hover:bg-gray-50">
                  <td className="py-2 px-3 text-gray-900">#{tx.id}</td>
                  <td className="py-2 px-3 text-gray-900">
                    {tx.type.replace(/_/g, " ")}
                  </td>
                  <td className="py-2 px-3 text-right font-semibold text-gray-900">
                    {fmt(tx.amount)}
                  </td>
                  <td className="py-2 px-3">
                    <span
                      className={cn(
                        "px-2 py-0.5 rounded-full text-xs font-medium",
                        TX_STATUS_COLOR[tx.status] ??
                          "bg-gray-100 text-gray-600",
                      )}
                    >
                      {tx.status}
                    </span>
                  </td>
                  <td className="py-2 px-3 text-gray-700 max-w-50 truncate">
                    {tx.description ?? "—"}
                  </td>
                  <td className="py-2 px-3 text-gray-700">
                    {fmtDate(tx.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </SectionCard>
  );
}

// ─── Wallet card + composed sections ──────────────────────────────────────────
export default function UserWalletSection({ userId }: { userId: number }) {
  const qc = useQueryClient();
  const [freezeReason, setFreezeReason] = useState("");
  const [showFreeze, setShowFreeze] = useState(false);
  const [showAdjust, setShowAdjust] = useState(false);
  const [adjustType, setAdjustType] = useState<
    "MANUAL_INCREASE" | "MANUAL_DECREASE"
  >("MANUAL_INCREASE");
  const [adjustAmount, setAdjustAmount] = useState("");
  const [adjustDesc, setAdjustDesc] = useState("");
  const [showPenalty, setShowPenalty] = useState(false);
  const [penaltyAmount, setPenaltyAmount] = useState("");
  const [penaltyReason, setPenaltyReason] = useState("");

  const { data: walletsData, isLoading: walletLoading } = useQuery({
    queryKey: ["user-wallet", userId],
    queryFn: () => fetchWallets({ user_id: userId, limit: 1 }),
    enabled: !!userId,
  });
  const wallet: Wallet | undefined = walletsData?.wallets?.[0];

  const freezeMut = useMutation({
    mutationFn: () => freezeWallet(wallet!.id, freezeReason),
    onSuccess: () => {
      toast.success("Wallet frozen");
      qc.invalidateQueries({ queryKey: ["user-wallet", userId] });
      setShowFreeze(false);
      setFreezeReason("");
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });
  const unfreezeMut = useMutation({
    mutationFn: () => unfreezeWallet(wallet!.id),
    onSuccess: () => {
      toast.success("Wallet unfrozen");
      qc.invalidateQueries({ queryKey: ["user-wallet", userId] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });
  const adjustMut = useMutation({
    mutationFn: () =>
      adjustBalance({
        wallet_id: wallet!.id,
        type: adjustType,
        amount: Math.round(parseFloat(adjustAmount) * 100),
        description: adjustDesc,
      }),
    onSuccess: () => {
      toast.success("Balance adjusted");
      qc.invalidateQueries({ queryKey: ["user-wallet", userId] });
      qc.invalidateQueries({ queryKey: ["user-transactions", userId] });
      setShowAdjust(false);
      setAdjustAmount("");
      setAdjustDesc("");
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });
  const penaltyMut = useMutation({
    mutationFn: () =>
      applyPenalty(userId, {
        amount: Math.round(parseFloat(penaltyAmount) * 100),
        reason: penaltyReason,
      }),
    onSuccess: () => {
      toast.success("Penalty applied");
      qc.invalidateQueries({ queryKey: ["user-penalties", userId] });
      setShowPenalty(false);
      setPenaltyAmount("");
      setPenaltyReason("");
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  const frozen = wallet?.status === "FROZEN";

  return (
    <div className="space-y-4">
      {/* ── Wallet Card ── */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <WalletIcon size={18} className="text-indigo-600" /> Wallet
          </h2>
          <div className="flex gap-2">
            {wallet && !frozen && (
              <button
                onClick={() => setShowFreeze(true)}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-blue-50 text-blue-700 border border-blue-200 rounded-lg hover:bg-blue-100"
              >
                <Snowflake size={12} /> Freeze
              </button>
            )}
            {wallet && frozen && (
              <button
                onClick={() => unfreezeMut.mutate()}
                disabled={unfreezeMut.isPending}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-green-50 text-green-700 border border-green-200 rounded-lg hover:bg-green-100"
              >
                <Sun size={12} /> Unfreeze
              </button>
            )}
            {wallet && (
              <>
                <button
                  onClick={() => {
                    setAdjustType("MANUAL_INCREASE");
                    setShowAdjust(true);
                  }}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-green-50 text-green-700 border border-green-200 rounded-lg hover:bg-green-100"
                >
                  <Plus size={12} /> Add
                </button>
                <button
                  onClick={() => {
                    setAdjustType("MANUAL_DECREASE");
                    setShowAdjust(true);
                  }}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-red-50 text-red-700 border border-red-200 rounded-lg hover:bg-red-100"
                >
                  <Minus size={12} /> Deduct
                </button>
              </>
            )}
            <button
              onClick={() => setShowPenalty(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-orange-50 text-orange-700 border border-orange-200 rounded-lg hover:bg-orange-100"
            >
              <AlertTriangle size={12} /> Penalty
            </button>
          </div>
        </div>

        {walletLoading && (
          <p className="text-sm text-gray-500">Loading wallet…</p>
        )}
        {!walletLoading && !wallet && (
          <p className="text-sm text-gray-900">
            No wallet found for this user.
          </p>
        )}
        {wallet && (
          <div className="flex items-center gap-8 flex-wrap">
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide mb-1">
                Balance
              </p>
              <p className="text-3xl font-bold text-gray-900">
                {fmt(wallet.balance)}
              </p>
            </div>
            {wallet.points != null && (
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide mb-1">
                  Points
                </p>
                <p className="text-3xl font-bold text-gray-900">
                  {wallet.points}
                </p>
              </div>
            )}
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide mb-1">
                Status
              </p>
              <span
                className={cn(
                  "px-3 py-1 rounded-full text-sm font-semibold",
                  frozen
                    ? "bg-blue-100 text-blue-700"
                    : "bg-green-100 text-green-700",
                )}
              >
                {frozen ? "Frozen" : "Active"}
              </span>
              {frozen && wallet.freeze_reason && (
                <p className="text-xs text-gray-600 mt-1">
                  Reason: {wallet.freeze_reason}
                </p>
              )}
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide mb-1">
                Wallet ID
              </p>
              <p className="text-sm font-medium text-gray-900">#{wallet.id}</p>
            </div>
          </div>
        )}

        {/* Freeze form */}
        {showFreeze && (
          <div className="mt-4 p-4 bg-blue-50 rounded-lg border border-blue-200 space-y-3">
            <p className="text-sm font-medium text-gray-900">Freeze reason</p>
            <input
              value={freezeReason}
              onChange={(e) => setFreezeReason(e.target.value)}
              placeholder="Enter reason…"
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg text-gray-900 bg-white"
            />
            <div className="flex gap-2">
              <button
                onClick={() => freezeMut.mutate()}
                disabled={!freezeReason || freezeMut.isPending}
                className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg disabled:opacity-50"
              >
                Freeze
              </button>
              <button
                onClick={() => setShowFreeze(false)}
                className="px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-lg"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* Adjust form */}
        {showAdjust && (
          <div className="mt-4 p-4 bg-gray-50 rounded-lg border border-gray-200 space-y-3">
            <p className="text-sm font-medium text-gray-900">
              {adjustType === "MANUAL_INCREASE"
                ? "Add Balance"
                : "Deduct Balance"}
            </p>
            <input
              type="number"
              value={adjustAmount}
              onChange={(e) => setAdjustAmount(e.target.value)}
              placeholder="Amount in EGP (e.g. 5.00)"
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg text-gray-900 bg-white"
            />
            <input
              value={adjustDesc}
              onChange={(e) => setAdjustDesc(e.target.value)}
              placeholder="Description…"
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg text-gray-900 bg-white"
            />
            <div className="flex gap-2">
              <button
                onClick={() => adjustMut.mutate()}
                disabled={!adjustAmount || !adjustDesc || adjustMut.isPending}
                className={cn(
                  "px-4 py-2 text-white text-sm rounded-lg disabled:opacity-50",
                  adjustType === "MANUAL_INCREASE"
                    ? "bg-green-600"
                    : "bg-red-600",
                )}
              >
                Confirm
              </button>
              <button
                onClick={() => setShowAdjust(false)}
                className="px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-lg"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* Penalty form */}
        {showPenalty && (
          <div className="mt-4 p-4 bg-orange-50 rounded-lg border border-orange-200 space-y-3">
            <p className="text-sm font-medium text-gray-900">Apply Penalty</p>
            <input
              type="number"
              value={penaltyAmount}
              onChange={(e) => setPenaltyAmount(e.target.value)}
              placeholder="Amount in EGP"
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg text-gray-900 bg-white"
            />
            <input
              value={penaltyReason}
              onChange={(e) => setPenaltyReason(e.target.value)}
              placeholder="Reason…"
              className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg text-gray-900 bg-white"
            />
            <div className="flex gap-2">
              <button
                onClick={() => penaltyMut.mutate()}
                disabled={
                  !penaltyAmount || !penaltyReason || penaltyMut.isPending
                }
                className="px-4 py-2 bg-orange-600 text-white text-sm rounded-lg disabled:opacity-50"
              >
                Apply
              </button>
              <button
                onClick={() => setShowPenalty(false)}
                className="px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-lg"
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
      <CommissionsSection userId={userId} />
      <PenaltiesSection userId={userId} />
      <EscrowsSection walletId={wallet?.id} />
      <PaymentMethodsSection userId={userId} />
      {wallet?.id ? <TransactionsSection walletId={wallet.id} /> : null}
    </div>
  );
}
