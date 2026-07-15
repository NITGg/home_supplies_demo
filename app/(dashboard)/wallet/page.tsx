"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchWallets,
  fetchTransactions,
  fetchPenalties,
  fetchEscrows,
  fetchPaymentMethods,
  fetchUnpaidCommissions,
  fetchPlatformWallet,
  incPlatformWalletBalance,
  decPlatformWalletBalance,
  createPlatformWalletRecord,
  changePlatformWalletUserId,
  settlingBalance,
  freezeWallet,
  unfreezeWallet,
  adjustBalance,
  applyPenalty,
  waivePenalty,
  type Wallet,
  type WalletTransaction,
  type WalletPenalty,
  type WalletEscrow,
  type PaymentMethod,
  type UnpaidCommission,
  type PlatformWallet,
} from "@/lib/wallet";
import { useT } from "@/contexts/LanguageContext";
import {
  Wallet as WalletIcon,
  RefreshCw,
  X,
  CheckCircle,
  XCircle,
  Building2,
  CreditCard,
  TrendingUp,
  TrendingDown,
} from "lucide-react";
import toast from "react-hot-toast";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { cn } from "@/lib/utils";

type Tab =
  | "wallets"
  | "transactions"
  | "penalties"
  | "escrows"
  | "payment_methods"
  | "platform_wallet"
  | "unpaid_commissions";

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}
function fmtAmt(n: number) {
  return `${(n / 100).toFixed(2)} EGP`;
}

const WALLET_COLS = ["owner", "type", "balance", "status", "actions"] as const;
const TRANSACTION_COLS = [
  "wallet_id",
  "tx_type",
  "amount",
  "tx_status",
  "description",
  "date",
] as const;
const PENALTY_COLS = [
  "user",
  "amount",
  "reason",
  "is_paid",
  "is_waived",
  "date",
  "actions",
] as const;
const ESCROW_COLS = [
  "id",
  "order_id",
  "wallet_id",
  "held_amount",
  "date",
] as const;
const PM_COLS = [
  "user",
  "method_type",
  "provider",
  "display_name",
  "is_default",
  "date",
] as const;
const COMMISSION_COLS = [
  "user",
  "order_id",
  "amount",
  "is_paid",
  "date",
] as const;

export default function WalletPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("wallets");
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [adjustModal, setAdjustModal] = useState<Wallet | null>(null);
  const [freezeModal, setFreezeModal] = useState<Wallet | null>(null);
  const [penaltyModal, setPenaltyModal] = useState<{
    userId: number;
    name: string;
  } | null>(null);
  const [pwModal, setPwModal] = useState<
    "inc" | "dec" | "create" | "change_user" | null
  >(null);
  const [settleModal, setSettleModal] = useState(false);

  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");

  const { visible: visibleWallets, setVisible: setVisibleWallets } =
    useColumnVisibility("cols:wallet-wallets", [...WALLET_COLS]);
  const { visible: visibleTx, setVisible: setVisibleTx } = useColumnVisibility(
    "cols:wallet-transactions",
    [...TRANSACTION_COLS],
  );
  const { visible: visiblePenalties, setVisible: setVisiblePenalties } =
    useColumnVisibility("cols:wallet-penalties", [...PENALTY_COLS]);
  const { visible: visibleEscrows, setVisible: setVisibleEscrows } =
    useColumnVisibility("cols:wallet-escrows", [...ESCROW_COLS]);
  const { visible: visiblePm, setVisible: setVisiblePm } = useColumnVisibility(
    "cols:wallet-pm",
    [...PM_COLS],
  );
  const { visible: visibleCommissions, setVisible: setVisibleCommissions } =
    useColumnVisibility("cols:wallet-commissions", [...COMMISSION_COLS]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const walletsQ = useQuery({
    queryKey: ["wallets", params],
    queryFn: () => fetchWallets(params),
    enabled: tab === "wallets",
  });
  const transQ = useQuery({
    queryKey: ["transactions", params],
    queryFn: () => fetchTransactions(params),
    enabled: tab === "transactions",
  });
  const penaltiesQ = useQuery({
    queryKey: ["penalties", params],
    queryFn: () => fetchPenalties(params),
    enabled: tab === "penalties",
  });
  const escrowsQ = useQuery({
    queryKey: ["escrows", params],
    queryFn: () => fetchEscrows(params),
    enabled: tab === "escrows",
  });
  const pmQ = useQuery({
    queryKey: ["paymentMethods", params],
    queryFn: () => fetchPaymentMethods(params),
    enabled: tab === "payment_methods",
  });
  const commissionsQ = useQuery({
    queryKey: ["commissions", params],
    queryFn: () => fetchUnpaidCommissions(params),
    enabled: tab === "unpaid_commissions",
  });
  const platformWalletQ = useQuery({
    queryKey: ["platformWallet"],
    queryFn: fetchPlatformWallet,
    enabled: tab === "platform_wallet",
  });

  const activeQ =
    tab === "wallets"
      ? walletsQ
      : tab === "transactions"
        ? transQ
        : tab === "penalties"
          ? penaltiesQ
          : tab === "escrows"
            ? escrowsQ
            : tab === "payment_methods"
              ? pmQ
              : tab === "unpaid_commissions"
                ? commissionsQ
                : platformWalletQ;

  const allWallets = walletsQ.data?.wallets ?? [];
  const allTransactions = transQ.data?.transactions ?? [];
  const allPenalties = penaltiesQ.data?.penalties ?? [];
  const allEscrows = escrowsQ.data?.escrows ?? [];
  const allPm = pmQ.data?.paymentMethods ?? [];
  const allCommissions = commissionsQ.data?.unpaidCommissions ?? [];

  const wallets = allWallets.filter((r) => {
    if (
      createdFrom &&
      r.created_at &&
      new Date(r.created_at) < new Date(createdFrom)
    )
      return false;
    if (
      createdTo &&
      r.created_at &&
      new Date(r.created_at) > new Date(createdTo + "T23:59:59")
    )
      return false;
    if (
      updatedFrom &&
      r.updated_at &&
      new Date(r.updated_at) < new Date(updatedFrom)
    )
      return false;
    if (
      updatedTo &&
      r.updated_at &&
      new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")
    )
      return false;
    return true;
  });
  const transactions = allTransactions.filter((r) => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    return true;
  });
  const penalties = allPenalties.filter((r) => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    return true;
  });
  const escrows = allEscrows.filter((r) => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    return true;
  });
  const paymentMethods = allPm.filter((r) => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    return true;
  });
  const commissions = allCommissions.filter((r) => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    return true;
  });

  const totalWallets = walletsQ.data?.pagination?.total ?? 0;
  const totalTransactions = transQ.data?.pagination?.total ?? 0;
  const totalPenalties = penaltiesQ.data?.pagination?.total ?? 0;
  const totalEscrows = escrowsQ.data?.pagination?.total ?? 0;
  const totalPm = pmQ.data?.pagination?.total ?? 0;
  const totalCommissions = commissionsQ.data?.pagination?.total ?? 0;

  const totalPages =
    tab === "wallets"
      ? (walletsQ.data?.pagination?.total_pages ?? 1)
      : tab === "transactions"
        ? (transQ.data?.pagination?.total_pages ?? 1)
        : tab === "penalties"
          ? (penaltiesQ.data?.pagination?.total_pages ?? 1)
          : tab === "escrows"
            ? (escrowsQ.data?.pagination?.total_pages ?? 1)
            : tab === "payment_methods"
              ? (pmQ.data?.pagination?.total_pages ?? 1)
              : tab === "unpaid_commissions"
                ? (commissionsQ.data?.pagination?.total_pages ?? 1)
                : 1;

  const dateFilterActive = createdFrom || createdTo || updatedFrom || updatedTo;
  const currentCount =
    tab === "wallets"
      ? wallets.length
      : tab === "transactions"
        ? transactions.length
        : tab === "penalties"
          ? penalties.length
          : tab === "escrows"
            ? escrows.length
            : tab === "payment_methods"
              ? paymentMethods.length
              : commissions.length;
  const serverTotal =
    tab === "wallets"
      ? totalWallets
      : tab === "transactions"
        ? totalTransactions
        : tab === "penalties"
          ? totalPenalties
          : tab === "escrows"
            ? totalEscrows
            : tab === "payment_methods"
              ? totalPm
              : totalCommissions;
  const displayTotal = dateFilterActive ? currentCount : serverTotal;

  const unfreezeMut = useMutation({
    mutationFn: (id: number) => unfreezeWallet(id),
    onSuccess: () => {
      toast.success("Wallet unfrozen");
      qc.invalidateQueries({ queryKey: ["wallets"] });
    },
    onError: () => toast.error("Failed"),
  });
  const waiveMut = useMutation({
    mutationFn: (id: number) => waivePenalty(id),
    onSuccess: () => {
      toast.success("Penalty waived");
      qc.invalidateQueries({ queryKey: ["penalties"] });
    },
    onError: () => toast.error("Failed"),
  });

  function switchTab(newTab: Tab) {
    setTab(newTab);
    setPage(1);
    setSearch("");
    setCreatedFrom("");
    setCreatedTo("");
    setUpdatedFrom("");
    setUpdatedTo("");
  }

  const activeVisible =
    tab === "wallets"
      ? visibleWallets
      : tab === "transactions"
        ? visibleTx
        : tab === "penalties"
          ? visiblePenalties
          : tab === "escrows"
            ? visibleEscrows
            : tab === "payment_methods"
              ? visiblePm
              : visibleCommissions;
  const activeSetVisible =
    tab === "wallets"
      ? setVisibleWallets
      : tab === "transactions"
        ? setVisibleTx
        : tab === "penalties"
          ? setVisiblePenalties
          : tab === "escrows"
            ? setVisibleEscrows
            : tab === "payment_methods"
              ? setVisiblePm
              : setVisibleCommissions;

  const walletColOptions: ColumnOption[] = [
    { key: "owner", label: t("wallet.owner") },
    { key: "type", label: t("wallet.type") },
    { key: "balance", label: t("wallet.balance") },
    { key: "status", label: t("wallet.status") },
    { key: "actions", label: t("common.actions"), alwaysVisible: true },
  ];
  const txColOptions: ColumnOption[] = [
    { key: "wallet_id", label: "Wallet" },
    { key: "tx_type", label: t("wallet.type") },
    { key: "amount", label: t("wallet.amount") },
    { key: "tx_status", label: t("wallet.status") },
    { key: "description", label: t("wallet.description") },
    { key: "date", label: "Date" },
  ];
  const penaltyColOptions: ColumnOption[] = [
    { key: "user", label: "User" },
    { key: "amount", label: t("wallet.amount") },
    { key: "reason", label: t("wallet.reason") },
    { key: "is_paid", label: t("wallet.isPaid") },
    { key: "is_waived", label: t("wallet.isWaived") },
    { key: "date", label: "Date" },
    { key: "actions", label: t("common.actions"), alwaysVisible: true },
  ];
  const escrowColOptions: ColumnOption[] = [
    { key: "id", label: "ID" },
    { key: "order_id", label: "Order" },
    { key: "wallet_id", label: "Wallet" },
    { key: "held_amount", label: "Held Amount" },
    { key: "date", label: "Date" },
  ];
  const pmColOptions: ColumnOption[] = [
    { key: "user", label: "User" },
    { key: "method_type", label: "Type" },
    { key: "provider", label: "Provider" },
    { key: "display_name", label: "Display Name" },
    { key: "is_default", label: "Default" },
    { key: "date", label: "Date" },
  ];
  const commissionColOptions: ColumnOption[] = [
    { key: "user", label: "User" },
    { key: "order_id", label: "Order" },
    { key: "amount", label: "Amount" },
    { key: "is_paid", label: "Paid" },
    { key: "date", label: "Date" },
  ];

  const activeColOptions =
    tab === "wallets"
      ? walletColOptions
      : tab === "transactions"
        ? txColOptions
        : tab === "penalties"
          ? penaltyColOptions
          : tab === "escrows"
            ? escrowColOptions
            : tab === "payment_methods"
              ? pmColOptions
              : commissionColOptions;

  const TABS: { key: Tab; label: string; total?: number }[] = [
    { key: "wallets", label: t("wallet.tabWallets"), total: totalWallets },
    {
      key: "transactions",
      label: t("wallet.tabTransactions"),
      total: totalTransactions,
    },
    {
      key: "penalties",
      label: t("wallet.tabPenalties"),
      total: totalPenalties,
    },
    { key: "escrows", label: "Escrows", total: totalEscrows },
    { key: "payment_methods", label: "Payment Methods", total: totalPm },
    {
      key: "unpaid_commissions",
      label: "Unpaid Commissions",
      total: totalCommissions,
    },
    { key: "platform_wallet", label: "Platform Wallet" },
  ];

  const showTable = tab !== "platform_wallet";

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <WalletIcon size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("wallet.title")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">{t("wallet.subtitle")}</p>
        </div>
        <button
          onClick={() => (activeQ as any).refetch()}
          disabled={(activeQ as any).isFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50"
        >
          <RefreshCw
            size={15}
            className={(activeQ as any).isFetching ? "animate-spin" : ""}
          />{" "}
          {t("common.refresh")}
        </button>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 overflow-x-auto">
        {TABS.map(({ key, label, total }) => (
          <button
            key={key}
            onClick={() => switchTab(key)}
            className={cn(
              "px-4 py-2.5 text-sm font-medium border-b-2 transition flex items-center gap-2 whitespace-nowrap shrink-0",
              tab === key
                ? "border-indigo-600 text-indigo-600"
                : "border-transparent text-gray-500 hover:text-gray-700",
            )}
          >
            {label}
            {total !== undefined && (
              <span
                className={cn(
                  "text-xs px-1.5 py-0.5 rounded-full",
                  tab === key
                    ? "bg-indigo-100 text-indigo-700"
                    : "bg-gray-100 text-gray-500",
                )}
              >
                {total}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Platform Wallet special view */}
      {tab === "platform_wallet" && (
        <PlatformWalletSection
          wallet={platformWalletQ.data ?? null}
          isLoading={platformWalletQ.isLoading}
          onAction={setPwModal}
          onRefresh={() =>
            qc.invalidateQueries({ queryKey: ["platformWallet"] })
          }
          onSettleOpen={() => setSettleModal(true)}
          t={t}
        />
      )}

      {/* Table tabs */}
      {showTable && (
        <>
          <TableToolbar
            total={displayTotal}
            totalLabel={label(tab)}
            search={search}
            onSearch={(v) => {
              setSearch(v);
              setPage(1);
            }}
            searchPlaceholder={t("wallet.searchPlaceholder")}
            action={
              <ColumnToggle
                columns={activeColOptions}
                visible={activeVisible}
                onChange={activeSetVisible}
              />
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
            {tab === "wallets" && (
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
            )}
          </TableToolbar>

          {(activeQ as any).isLoading && (
            <div className="text-center py-20 text-gray-400">
              {t("common.loading")}
            </div>
          )}

          {/* Wallets */}
          {tab === "wallets" &&
            !walletsQ.isLoading &&
            (wallets.length === 0 ? (
              <EmptyState text={t("wallet.noResults")} />
            ) : (
              <TableWrap>
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    {visibleWallets.includes("owner") && (
                      <TH>{t("wallet.owner")}</TH>
                    )}
                    {visibleWallets.includes("type") && (
                      <TH>{t("wallet.type")}</TH>
                    )}
                    {visibleWallets.includes("balance") && (
                      <TH>{t("wallet.balance")}</TH>
                    )}
                    {visibleWallets.includes("status") && (
                      <TH>{t("wallet.status")}</TH>
                    )}
                    {visibleWallets.includes("actions") && (
                      <TH right>{t("common.actions")}</TH>
                    )}
                  </tr>
                </thead>
                <tbody>
                  {wallets.map((w) => (
                    <tr
                      key={w.id}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                    >
                      {visibleWallets.includes("owner") && (
                        <TD>
                          {w.user ? (
                            <UserCell
                              name={w.user.full_name}
                              sub={w.user.phone}
                            />
                          ) : (
                            `#${w.id}`
                          )}
                        </TD>
                      )}
                      {visibleWallets.includes("type") && (
                        <TD>
                          <span className="text-xs text-gray-900">
                            {w.owner_type ?? "—"}
                          </span>
                        </TD>
                      )}
                      {visibleWallets.includes("balance") && (
                        <TD>
                          <span className="font-semibold">
                            {fmtAmt(w.balance)}
                          </span>
                        </TD>
                      )}
                      {visibleWallets.includes("status") && (
                        <TD>
                          <StatusBadge
                            active={w.status !== "FROZEN"}
                            activeLabel={t("wallet.active")}
                            inactiveLabel={t("wallet.frozen")}
                          />
                        </TD>
                      )}
                      {visibleWallets.includes("actions") && (
                        <TD right>
                          <div className="flex items-center justify-end gap-2">
                            {w.status === "FROZEN" ? (
                              <Btn
                                onClick={() => unfreezeMut.mutate(w.id)}
                                color="green"
                                disabled={unfreezeMut.isPending}
                              >
                                {t("wallet.unfreeze")}
                              </Btn>
                            ) : (
                              <Btn
                                onClick={() => setFreezeModal(w)}
                                color="amber"
                              >
                                {t("wallet.freeze")}
                              </Btn>
                            )}
                            <Btn
                              onClick={() => setAdjustModal(w)}
                              color="indigo"
                            >
                              {t("wallet.adjust")}
                            </Btn>
                            {w.user && (
                              <Btn
                                onClick={() =>
                                  setPenaltyModal({
                                    userId: w.user!.id,
                                    name: w.user!.full_name,
                                  })
                                }
                                color="red"
                              >
                                {t("wallet.applyPenalty")}
                              </Btn>
                            )}
                          </div>
                        </TD>
                      )}
                    </tr>
                  ))}
                </tbody>
              </TableWrap>
            ))}

          {/* Transactions */}
          {tab === "transactions" &&
            !transQ.isLoading &&
            (transactions.length === 0 ? (
              <EmptyState text={t("wallet.noResults")} />
            ) : (
              <TableWrap>
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    {visibleTx.includes("wallet_id") && <TH>Wallet</TH>}
                    {visibleTx.includes("tx_type") && (
                      <TH>{t("wallet.type")}</TH>
                    )}
                    {visibleTx.includes("amount") && (
                      <TH>{t("wallet.amount")}</TH>
                    )}
                    {visibleTx.includes("tx_status") && (
                      <TH>{t("wallet.status")}</TH>
                    )}
                    {visibleTx.includes("description") && (
                      <TH>{t("wallet.description")}</TH>
                    )}
                    {visibleTx.includes("date") && <TH>Date</TH>}
                  </tr>
                </thead>
                <tbody>
                  {transactions.map((tx) => (
                    <tr
                      key={tx.id}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                    >
                      {visibleTx.includes("wallet_id") && (
                        <TD>
                          <span className="text-gray-900">#{tx.wallet_id}</span>
                        </TD>
                      )}
                      {visibleTx.includes("tx_type") && (
                        <TD>
                          <span className="text-xs px-2.5 py-1 rounded-full bg-indigo-100 text-indigo-700 font-medium">
                            {tx.type}
                          </span>
                        </TD>
                      )}
                      {visibleTx.includes("amount") && (
                        <TD>
                          <span className="font-semibold">
                            {fmtAmt(tx.amount)}
                          </span>
                        </TD>
                      )}
                      {visibleTx.includes("tx_status") && (
                        <TD>
                          <span
                            className={cn(
                              "text-xs px-2.5 py-1 rounded-full font-medium",
                              tx.status === "COMPLETED"
                                ? "bg-green-100 text-green-700"
                                : tx.status === "FAILED"
                                  ? "bg-red-100 text-red-700"
                                  : "bg-yellow-100 text-yellow-700",
                            )}
                          >
                            {tx.status}
                          </span>
                        </TD>
                      )}
                      {visibleTx.includes("description") && (
                        <TD>
                          <span className="text-xs text-gray-700 truncate max-w-xs block">
                            {tx.description ?? "—"}
                          </span>
                        </TD>
                      )}
                      {visibleTx.includes("date") && (
                        <TD>
                          <span className="text-xs text-gray-700">
                            {fmtDate(tx.created_at)}
                          </span>
                        </TD>
                      )}
                    </tr>
                  ))}
                </tbody>
              </TableWrap>
            ))}

          {/* Penalties */}
          {tab === "penalties" &&
            !penaltiesQ.isLoading &&
            (penalties.length === 0 ? (
              <EmptyState text={t("wallet.noResults")} />
            ) : (
              <TableWrap>
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    {visiblePenalties.includes("user") && <TH>User</TH>}
                    {visiblePenalties.includes("amount") && (
                      <TH>{t("wallet.amount")}</TH>
                    )}
                    {visiblePenalties.includes("reason") && (
                      <TH>{t("wallet.reason")}</TH>
                    )}
                    {visiblePenalties.includes("is_paid") && (
                      <TH>{t("wallet.isPaid")}</TH>
                    )}
                    {visiblePenalties.includes("is_waived") && (
                      <TH>{t("wallet.isWaived")}</TH>
                    )}
                    {visiblePenalties.includes("date") && <TH>Date</TH>}
                    {visiblePenalties.includes("actions") && (
                      <TH right>{t("common.actions")}</TH>
                    )}
                  </tr>
                </thead>
                <tbody>
                  {penalties.map((p) => (
                    <tr
                      key={p.id}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                    >
                      {visiblePenalties.includes("user") && (
                        <TD>
                          {p.user ? (
                            <UserCell
                              name={p.user.full_name}
                              sub={p.user.phone}
                            />
                          ) : (
                            `#${p.user_id}`
                          )}
                        </TD>
                      )}
                      {visiblePenalties.includes("amount") && (
                        <TD>
                          <span className="font-semibold text-red-600">
                            {fmtAmt(p.amount)}
                          </span>
                        </TD>
                      )}
                      {visiblePenalties.includes("reason") && (
                        <TD>
                          <span className="text-xs text-gray-900 truncate max-w-xs block">
                            {p.reason}
                          </span>
                        </TD>
                      )}
                      {visiblePenalties.includes("is_paid") && (
                        <TD>
                          <YesNo val={p.is_paid} />
                        </TD>
                      )}
                      {visiblePenalties.includes("is_waived") && (
                        <TD>
                          <YesNo val={p.is_waived} />
                        </TD>
                      )}
                      {visiblePenalties.includes("date") && (
                        <TD>
                          <span className="text-xs text-gray-700">
                            {fmtDate(p.created_at)}
                          </span>
                        </TD>
                      )}
                      {visiblePenalties.includes("actions") && (
                        <TD right>
                          {!p.is_waived && (
                            <Btn
                              onClick={() => waiveMut.mutate(p.id)}
                              color="blue"
                              disabled={waiveMut.isPending}
                            >
                              {t("wallet.waive")}
                            </Btn>
                          )}
                        </TD>
                      )}
                    </tr>
                  ))}
                </tbody>
              </TableWrap>
            ))}

          {/* Escrows */}
          {tab === "escrows" &&
            !escrowsQ.isLoading &&
            (escrows.length === 0 ? (
              <EmptyState text="No escrows found." />
            ) : (
              <TableWrap>
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    {visibleEscrows.includes("id") && <TH>ID</TH>}
                    {visibleEscrows.includes("order_id") && <TH>Order</TH>}
                    {visibleEscrows.includes("wallet_id") && <TH>Wallet</TH>}
                    {visibleEscrows.includes("held_amount") && (
                      <TH>Held Amount</TH>
                    )}
                    {visibleEscrows.includes("date") && <TH>Date</TH>}
                  </tr>
                </thead>
                <tbody>
                  {escrows.map((e) => (
                    <tr
                      key={e.id}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                    >
                      {visibleEscrows.includes("id") && (
                        <TD>
                          <span className="text-gray-900">#{e.id}</span>
                        </TD>
                      )}
                      {visibleEscrows.includes("order_id") && (
                        <TD>
                          <span className="text-gray-900">
                            {e.order_id ? `#${e.order_id}` : "—"}
                          </span>
                        </TD>
                      )}
                      {visibleEscrows.includes("wallet_id") && (
                        <TD>
                          <span className="text-gray-900">#{e.wallet_id}</span>
                        </TD>
                      )}
                      {visibleEscrows.includes("held_amount") && (
                        <TD>
                          <span className="font-semibold text-amber-600">
                            {fmtAmt(e.held_amount)}
                          </span>
                        </TD>
                      )}
                      {visibleEscrows.includes("date") && (
                        <TD>
                          <span className="text-xs text-gray-700">
                            {fmtDate(e.created_at)}
                          </span>
                        </TD>
                      )}
                    </tr>
                  ))}
                </tbody>
              </TableWrap>
            ))}

          {/* Payment Methods */}
          {tab === "payment_methods" &&
            !pmQ.isLoading &&
            (paymentMethods.length === 0 ? (
              <EmptyState text="No payment methods found." />
            ) : (
              <TableWrap>
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    {visiblePm.includes("user") && <TH>User</TH>}
                    {visiblePm.includes("method_type") && <TH>Type</TH>}
                    {visiblePm.includes("provider") && <TH>Provider</TH>}
                    {visiblePm.includes("display_name") && (
                      <TH>Display Name</TH>
                    )}
                    {visiblePm.includes("is_default") && <TH>Default</TH>}
                    {visiblePm.includes("date") && <TH>Date</TH>}
                  </tr>
                </thead>
                <tbody>
                  {paymentMethods.map((pm) => (
                    <tr
                      key={pm.id}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                    >
                      {visiblePm.includes("user") && (
                        <TD>
                          {pm.user ? (
                            <UserCell
                              name={pm.user.full_name}
                              sub={pm.user.phone}
                            />
                          ) : (
                            `#${pm.user_id}`
                          )}
                        </TD>
                      )}
                      {visiblePm.includes("method_type") && (
                        <TD>
                          <span className="text-xs px-2 py-0.5 rounded-full bg-purple-100 text-purple-700">
                            {pm.method_type}
                          </span>
                        </TD>
                      )}
                      {visiblePm.includes("provider") && (
                        <TD>
                          <span className="text-xs text-gray-900">
                            {pm.provider ?? "—"}
                          </span>
                        </TD>
                      )}
                      {visiblePm.includes("display_name") && (
                        <TD>
                          <span className="text-sm text-gray-900">
                            {pm.display_name ?? "—"}
                          </span>
                        </TD>
                      )}
                      {visiblePm.includes("is_default") && (
                        <TD>
                          <YesNo val={pm.is_default} />
                        </TD>
                      )}
                      {visiblePm.includes("date") && (
                        <TD>
                          <span className="text-xs text-gray-700">
                            {fmtDate(pm.created_at)}
                          </span>
                        </TD>
                      )}
                    </tr>
                  ))}
                </tbody>
              </TableWrap>
            ))}

          {/* Unpaid Commissions */}
          {tab === "unpaid_commissions" &&
            !commissionsQ.isLoading &&
            (commissions.length === 0 ? (
              <EmptyState text="No unpaid commissions found." />
            ) : (
              <TableWrap>
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50">
                    {visibleCommissions.includes("user") && <TH>User</TH>}
                    {visibleCommissions.includes("order_id") && <TH>Order</TH>}
                    {visibleCommissions.includes("amount") && <TH>Amount</TH>}
                    {visibleCommissions.includes("is_paid") && <TH>Paid</TH>}
                    {visibleCommissions.includes("date") && <TH>Date</TH>}
                  </tr>
                </thead>
                <tbody>
                  {commissions.map((c) => (
                    <tr
                      key={c.id}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors"
                    >
                      {visibleCommissions.includes("user") && (
                        <TD>
                          {c.user ? (
                            <UserCell
                              name={c.user.full_name}
                              sub={c.user.phone}
                            />
                          ) : (
                            `#${c.user_id}`
                          )}
                        </TD>
                      )}
                      {visibleCommissions.includes("order_id") && (
                        <TD>
                          <span className="text-gray-900">
                            {c.order_id ? `#${c.order_id}` : "—"}
                          </span>
                        </TD>
                      )}
                      {visibleCommissions.includes("amount") && (
                        <TD>
                          <span className="font-semibold text-orange-600">
                            {fmtAmt(c.amount)}
                          </span>
                        </TD>
                      )}
                      {visibleCommissions.includes("is_paid") && (
                        <TD>
                          <YesNo val={c.is_paid} />
                        </TD>
                      )}
                      {visibleCommissions.includes("date") && (
                        <TD>
                          <span className="text-xs text-gray-700">
                            {fmtDate(c.created_at)}
                          </span>
                        </TD>
                      )}
                    </tr>
                  ))}
                </tbody>
              </TableWrap>
            ))}

          <TablePagination
            page={page}
            totalPages={totalPages}
            total={displayTotal}
            limit={20}
            onPageChange={setPage}
          />
        </>
      )}

      {adjustModal && (
        <AdjustModal
          wallet={adjustModal}
          onClose={() => setAdjustModal(null)}
          onSaved={() => {
            setAdjustModal(null);
            qc.invalidateQueries({ queryKey: ["wallets"] });
          }}
          t={t}
        />
      )}
      {freezeModal && (
        <FreezeModal
          wallet={freezeModal}
          onClose={() => setFreezeModal(null)}
          onSaved={() => {
            setFreezeModal(null);
            qc.invalidateQueries({ queryKey: ["wallets"] });
          }}
          t={t}
        />
      )}
      {penaltyModal && (
        <PenaltyModal
          userId={penaltyModal.userId}
          userName={penaltyModal.name}
          onClose={() => setPenaltyModal(null)}
          onSaved={() => {
            setPenaltyModal(null);
            qc.invalidateQueries({ queryKey: ["penalties"] });
          }}
          t={t}
        />
      )}
      {pwModal && (
        <PlatformWalletModal
          mode={pwModal}
          onClose={() => setPwModal(null)}
          onSaved={() => {
            setPwModal(null);
            qc.invalidateQueries({ queryKey: ["platformWallet"] });
          }}
          t={t}
        />
      )}
      {settleModal && (
        <SettleBalanceModal
          onClose={() => setSettleModal(false)}
          onSaved={() => {
            setSettleModal(false);
            qc.invalidateQueries({ queryKey: ["platformWallet"] });
          }}
          t={t}
        />
      )}
    </div>
  );
}

function label(tab: Tab): string {
  return tab === "wallets"
    ? "wallets"
    : tab === "transactions"
      ? "transactions"
      : tab === "penalties"
        ? "penalties"
        : tab === "escrows"
          ? "escrows"
          : tab === "payment_methods"
            ? "payment methods"
            : "commissions";
}

// ─── Small primitives ─────────────────────────────────────────────────────────

function EmptyState({ text }: { text: string }) {
  return (
    <div className="text-center py-20 border-2 border-dashed border-gray-200 rounded-2xl">
      <WalletIcon size={36} className="text-gray-300 mx-auto mb-3" />
      <p className="text-gray-400">{text}</p>
    </div>
  );
}

function TableWrap({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
      <table className="w-full text-sm">{children}</table>
    </div>
  );
}

function TH({
  children,
  right,
}: {
  children: React.ReactNode;
  right?: boolean;
}) {
  return (
    <th
      className={cn(
        "px-5 py-3.5 text-xs font-semibold text-gray-500 uppercase",
        right ? "text-right" : "text-left",
      )}
    >
      {children}
    </th>
  );
}

function TD({
  children,
  right,
}: {
  children: React.ReactNode;
  right?: boolean;
}) {
  return (
    <td className={cn("px-5 py-3.5", right ? "text-right" : "")}>{children}</td>
  );
}

function UserCell({ name, sub }: { name: string; sub?: string }) {
  return (
    <div>
      <p className="font-medium text-gray-900">{name}</p>
      {sub && <p className="text-xs text-gray-400">{sub}</p>}
    </div>
  );
}

function StatusBadge({
  active,
  activeLabel,
  inactiveLabel,
}: {
  active: boolean;
  activeLabel: string;
  inactiveLabel: string;
}) {
  return active ? (
    <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700">
      <CheckCircle size={11} /> {activeLabel}
    </span>
  ) : (
    <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-red-100 text-red-700">
      <XCircle size={11} /> {inactiveLabel}
    </span>
  );
}

function YesNo({ val }: { val: boolean }) {
  return val ? (
    <span className="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700">
      <CheckCircle size={10} /> Yes
    </span>
  ) : (
    <span className="text-xs text-gray-400">No</span>
  );
}

function Btn({
  children,
  onClick,
  color = "indigo",
  disabled,
}: {
  children: React.ReactNode;
  onClick: () => void;
  color?: string;
  disabled?: boolean;
}) {
  const cls: Record<string, string> = {
    green: "bg-green-600 hover:bg-green-700 text-white",
    amber: "bg-amber-500 hover:bg-amber-600 text-white",
    red: "bg-red-600 hover:bg-red-700 text-white",
    blue: "bg-blue-600 hover:bg-blue-700 text-white",
    indigo: "border border-indigo-300 text-indigo-600 hover:bg-indigo-50",
  };
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={cn(
        "px-3 py-1.5 text-xs rounded-lg disabled:opacity-50 transition",
        cls[color] ?? cls.indigo,
      )}
    >
      {children}
    </button>
  );
}

// ─── Platform Wallet Section ──────────────────────────────────────────────────

function PlatformWalletSection({
  wallet,
  isLoading,
  onAction,
  onRefresh,
  onSettleOpen,
  t,
}: {
  wallet: PlatformWallet | null;
  isLoading: boolean;
  onAction: (m: "inc" | "dec" | "create" | "change_user") => void;
  onRefresh: () => void;
  onSettleOpen: () => void;
  t: (k: string) => string;
}) {
  if (isLoading)
    return (
      <div className="text-center py-20 text-gray-400">
        {t("common.loading")}
      </div>
    );

  if (!wallet) {
    return (
      <div className="bg-white rounded-2xl border border-gray-200 p-8 text-center space-y-4">
        <Building2 size={40} className="text-gray-300 mx-auto" />
        <p className="text-gray-500">No platform wallet record found.</p>
        <button
          onClick={() => onAction("create")}
          className="px-5 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700"
        >
          Create Platform Wallet Record
        </button>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-2xl border border-gray-200 p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
          <Building2 size={20} className="text-indigo-600" /> Platform Wallet
        </h2>
        <button
          onClick={onRefresh}
          className="p-2 border border-gray-300 rounded-xl hover:bg-gray-50 text-gray-500"
        >
          <RefreshCw size={15} />
        </button>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-6 gap-4">
        <InfoCard label="Wallet ID" value={`#${wallet.id}`} />
        <InfoCard label="Balance" value={fmtAmt(wallet.balance)} highlight />
        <InfoCard
          label="Platform Money"
          value={fmtAmt(wallet.platform_money ?? 0)}
          highlight
        />
        <InfoCard
          label="Platform Earnings"
          value={fmtAmt(wallet.platform_earnings ?? 0)}
          highlight
        />
        <InfoCard label="Status" value={wallet.status ?? "—"} />
        <InfoCard
          label="User ID"
          value={wallet.user_id ? `#${wallet.user_id}` : "—"}
        />
      </div>
      <div className="flex flex-wrap gap-3">
        <button
          onClick={() => onAction("inc")}
          className="flex items-center gap-2 px-4 py-2.5 bg-green-600 text-white rounded-xl text-sm font-medium hover:bg-green-700"
        >
          <TrendingUp size={16} /> Increase Balance
        </button>
        <button
          onClick={() => onAction("dec")}
          className="flex items-center gap-2 px-4 py-2.5 bg-red-600 text-white rounded-xl text-sm font-medium hover:bg-red-700"
        >
          <TrendingDown size={16} /> Decrease Balance
        </button>
        <button
          onClick={() => onAction("change_user")}
          className="flex items-center gap-2 px-4 py-2.5 border border-gray-300 text-gray-700 rounded-xl text-sm font-medium hover:bg-gray-50"
        >
          <CreditCard size={16} /> Change User
        </button>
        <button
          onClick={onSettleOpen}
          className="flex items-center gap-2 px-4 py-2.5 bg-purple-600 text-white rounded-xl text-sm font-medium hover:bg-purple-700"
        >
          <RefreshCw size={16} /> Settle Platform Balance
        </button>
      </div>
    </div>
  );
}

function InfoCard({
  label,
  value,
  highlight,
}: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div className="bg-gray-50 rounded-xl p-4">
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      <p
        className={cn(
          "text-lg font-bold",
          highlight ? "text-indigo-600" : "text-gray-900",
        )}
      >
        {value}
      </p>
    </div>
  );
}

// ─── Platform Wallet Modal ────────────────────────────────────────────────────

function PlatformWalletModal({
  mode,
  onClose,
  onSaved,
  t,
}: {
  mode: "inc" | "dec" | "create" | "change_user";
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [amount, setAmount] = useState("");
  const [description, setDescription] = useState("");
  const [userId, setUserId] = useState("");

  const mut = useMutation({
    mutationFn: async () => {
      if (mode === "inc")
        return incPlatformWalletBalance({
          amount: Number(amount) * 100,
          description,
        });
      if (mode === "dec")
        return decPlatformWalletBalance({
          amount: Number(amount) * 100,
          description,
        });
      if (mode === "create") return createPlatformWalletRecord(Number(userId));
      return changePlatformWalletUserId(Number(userId));
    },
    onSuccess: () => {
      toast.success("Done");
      onSaved();
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  const titles: Record<typeof mode, string> = {
    inc: "Increase Platform Balance",
    dec: "Decrease Platform Balance",
    create: "Create Platform Wallet Record",
    change_user: "Change Platform Wallet User",
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{titles[mode]}</h2>
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
            mut.mutate();
          }}
          className="px-6 py-5 space-y-4"
        >
          {(mode === "inc" || mode === "dec") && (
            <>
              <Field label="Amount">
                <input
                  required
                  type="number"
                  step="0.001"
                  min="0"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="input"
                />
              </Field>
              <Field label="Description">
                <input
                  required
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="input"
                />
              </Field>
            </>
          )}
          {(mode === "create" || mode === "change_user") && (
            <Field label="User ID">
              <input
                required
                type="number"
                min="1"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                className="input"
              />
            </Field>
          )}
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
              disabled={mut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
            >
              {mut.isPending ? t("common.saving") : t("common.confirm")}
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
      <label className="text-xs font-semibold text-gray-600 uppercase">
        {label}
      </label>
      {children}
    </div>
  );
}

// ─── Existing modals ──────────────────────────────────────────────────────────

function AdjustModal({
  wallet,
  onClose,
  onSaved,
  t,
}: {
  wallet: Wallet;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState({
    type: "MANUAL_INCREASE" as "MANUAL_INCREASE" | "MANUAL_DECREASE",
    amount: "",
    description: "",
  });
  const mut = useMutation({
    mutationFn: () =>
      adjustBalance({
        wallet_id: wallet.id,
        type: form.type,
        amount: Number(form.amount),
        description: form.description,
      }),
    onSuccess: () => {
      toast.success("Balance adjusted");
      onSaved();
    },
    onError: () => toast.error("Failed to adjust"),
  });
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {t("wallet.adjust")}
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
            mut.mutate();
          }}
          className="px-6 py-5 space-y-4"
        >
          <p className="text-sm text-gray-600">
            Wallet: <strong>{wallet.user?.full_name ?? `#${wallet.id}`}</strong>{" "}
            — Balance: {fmtAmt(wallet.balance)}
          </p>
          <Field label={t("wallet.adjustType")}>
            <select
              value={form.type}
              onChange={(e) =>
                setForm((p) => ({
                  ...p,
                  type: e.target.value as typeof form.type,
                }))
              }
              className="input"
            >
              <option value="MANUAL_INCREASE">{t("wallet.increase")}</option>
              <option value="MANUAL_DECREASE">{t("wallet.decrease")}</option>
            </select>
          </Field>
          <Field label={t("wallet.amount")}>
            <input
              required
              type="number"
              step="0.001"
              min="0"
              value={form.amount}
              onChange={(e) =>
                setForm((p) => ({ ...p, amount: e.target.value }))
              }
              className="input"
            />
          </Field>
          <Field label={t("wallet.description")}>
            <input
              required
              value={form.description}
              onChange={(e) =>
                setForm((p) => ({ ...p, description: e.target.value }))
              }
              className="input"
            />
          </Field>
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
              disabled={mut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
            >
              {mut.isPending ? t("common.saving") : t("common.confirm")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function FreezeModal({
  wallet,
  onClose,
  onSaved,
  t,
}: {
  wallet: Wallet;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [reason, setReason] = useState("");
  const mut = useMutation({
    mutationFn: () => freezeWallet(wallet.id, reason),
    onSuccess: () => {
      toast.success("Wallet frozen");
      onSaved();
    },
    onError: () => toast.error("Failed to freeze"),
  });
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {t("wallet.freeze")}
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
            mut.mutate();
          }}
          className="px-6 py-5 space-y-4"
        >
          <p className="text-sm text-gray-600">
            Freezing wallet of:{" "}
            <strong>{wallet.user?.full_name ?? `#${wallet.id}`}</strong>
          </p>
          <Field label={t("wallet.freezeReason")}>
            <textarea
              required
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={3}
              className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none"
            />
          </Field>
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
              disabled={mut.isPending || !reason.trim()}
              className="px-6 py-2.5 bg-amber-500 text-white rounded-xl text-sm font-medium hover:bg-amber-600 disabled:opacity-60"
            >
              {mut.isPending ? t("common.saving") : t("wallet.freeze")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function PenaltyModal({
  userId,
  userName,
  onClose,
  onSaved,
  t,
}: {
  userId: number;
  userName: string;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState({ amount: "", reason: "" });
  const mut = useMutation({
    mutationFn: () =>
      applyPenalty(userId, {
        amount: Number(form.amount),
        reason: form.reason,
      }),
    onSuccess: () => {
      toast.success("Penalty applied");
      onSaved();
    },
    onError: () => toast.error("Failed to apply penalty"),
  });
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {t("wallet.applyPenalty")}
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
            mut.mutate();
          }}
          className="px-6 py-5 space-y-4"
        >
          <p className="text-sm text-gray-600">
            Applying penalty to: <strong>{userName}</strong>
          </p>
          <Field label={t("wallet.penaltyAmount")}>
            <input
              required
              type="number"
              step="0.001"
              min="0"
              value={form.amount}
              onChange={(e) =>
                setForm((p) => ({ ...p, amount: e.target.value }))
              }
              className="input"
            />
          </Field>
          <Field label={t("wallet.penaltyReason")}>
            <textarea
              required
              value={form.reason}
              onChange={(e) =>
                setForm((p) => ({ ...p, reason: e.target.value }))
              }
              rows={3}
              className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none"
            />
          </Field>
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
              disabled={mut.isPending || !form.amount || !form.reason.trim()}
              className="px-6 py-2.5 bg-red-600 text-white rounded-xl text-sm font-medium hover:bg-red-700 disabled:opacity-60"
            >
              {mut.isPending ? t("common.saving") : t("wallet.applyPenalty")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// ─── Settle Balance Modal ─────────────────────────────────────────────────────

function SettleBalanceModal({
  onClose,
  onSaved,
  t,
}: {
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [periodFrom, setPeriodFrom] = useState("");
  const [periodTo, setPeriodTo] = useState("");

  const mut = useMutation({
    mutationFn: () => {
      const body: any = { target_owner_type: "PLATFORM" };
      if (periodFrom) body.period_from = periodFrom;
      if (periodTo) body.period_to = periodTo;
      return settlingBalance(body);
    },
    onSuccess: (data: any) => {
      const message = data?.message;
      if (message) {
        toast.success(message);
      } else {
        toast.success("Platform balance settled");
      }
      onSaved();
    },
    onError: (e: any) => {
      const message = e?.response?.data?.message;
      toast.error(message ?? "Failed to settle balance");
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            Settle Platform Balance
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
            mut.mutate();
          }}
          className="px-6 py-5 space-y-4"
        >
          <p className="text-sm text-gray-600">
            Settle the platform balance. Period fields are optional.
          </p>
          <Field label="Period From (Optional)">
            <input
              type="date"
              value={periodFrom}
              onChange={(e) => setPeriodFrom(e.target.value)}
              className="input"
            />
          </Field>
          <Field label="Period To (Optional)">
            <input
              type="date"
              value={periodTo}
              onChange={(e) => setPeriodTo(e.target.value)}
              className="input"
            />
          </Field>
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
              disabled={mut.isPending}
              className="px-6 py-2.5 bg-purple-600 text-white rounded-xl text-sm font-medium hover:bg-purple-700 disabled:opacity-60"
            >
              {mut.isPending ? t("common.saving") : "Settle Balance"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
