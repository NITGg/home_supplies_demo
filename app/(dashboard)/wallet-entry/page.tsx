"use client";

import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchWalletEntries } from "@/lib/wallet";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { useT } from "@/contexts/LanguageContext";
import { useRouter } from "next/navigation";
import { FileText, RefreshCw, Plus, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

const DEFAULT_COLS = [
  "id",
  "wallet_id",
  "user_name",
  "amount",
  "is_settled",
  "settled_at",
  "settlement_id",
  "penalty_id",
  "order_id",
  "unpaid_commission_id",
  "customer_coupon_id",
  "courier_coupon_id",
  "points_to_money",
  "notes",
  "is_settled",
  "created_at",
  "actions",
] as const;

export default function WalletEntryPage() {
  const { t, lang } = useT();
  const router = useRouter();
  const qc = useQueryClient();

  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(20);
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [walletIdFilter, setWalletIdFilter] = useState("");

  const { visible, setVisible } = useColumnVisibility("cols:wallet-entries", [
    ...DEFAULT_COLS,
  ]);

  const skip = (page - 1) * limit;

  const params: Record<string, string | number> = {
    limit,
    skip,
    sort: "-created_at",
    // COMPLETED: Updated include chain to query wallet.user relation data
    includes:
      "wallet.user,settlement,order,penalty,unpaidCommission,customerCoupon,courierCoupon",
  };

  if (createdFrom) params["created_at[gte]"] = createdFrom;
  if (createdTo) params["created_at[lte]"] = createdTo + "T23:59:59";
  if (walletIdFilter) {
    // If input is numeric, filter by wallet_id; otherwise use keyword search
    if (/^\d+$/.test(walletIdFilter)) {
      params["wallet_id"] = walletIdFilter;
    } else {
      params["keyword"] = walletIdFilter;
      params["items"] = "wallet.user.full_name";
    }
  }

  const query = useQuery({
    queryKey: ["walletEntries", params],
    queryFn: () => fetchWalletEntries(params),
  });

  const entries = query.data?.walletEntries ?? [];
  const total = query.data?.totalWalletEntry ?? 0;
  const totalPages = query.data?.totalPages ?? 1;

  const colOptions: ColumnOption[] = [
    { key: "id", label: "ID" },
    { key: "wallet_id", label: "Wallet ID" },
    // COMPLETED: Added column toggle translation matching project infrastructure
    { key: "user_name", label: lang === "AR" ? "اسم المستخدم" : "User Name" },
    { key: "amount", label: "Amount" },
    { key: "order_id", label: "Order ID" },
    { key: "penalty_id", label: "Penalty ID" },
    { key: "unpaid_commission_id", label: "Unpaid Commission ID" },
    { key: "customer_coupon_id", label: "Customer Coupon ID" },
    { key: "courier_coupon_id", label: "Courier Coupon ID" },
    { key: "points_to_money", label: "Points to Money" },
    { key: "notes", label: "Notes" },
    { key: "is_settled", label: "Settled" },
    { key: "settled_at", label: "Settled At" },
    { key: "settlement_id", label: "Settlement ID" },
    { key: "created_at", label: "Created At" },
    { key: "actions", label: t("common.actions"), alwaysVisible: true },
  ];

  function fmtAmt(n: number) {
    return `${(n / 100).toFixed(2)} EGP`;
  }

  function fmtDate(d: string) {
    return new Date(d).toLocaleDateString(lang === "AR" ? "ar-EG" : "en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <FileText size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {lang === "AR" ? "إدخالات المحفظة" : "Wallet Entries"}
            </h1>
          </div>
          <p className="text-sm text-gray-500">
            {lang === "AR"
              ? "عرض وإدارة إدخالات وتعديلات المحفظة"
              : "View and manage wallet entries and adjustments"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => query.refetch()}
            disabled={query.isFetching}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50 transition"
          >
            <RefreshCw
              size={15}
              className={query.isFetching ? "animate-spin" : ""}
            />
            {t("common.refresh")}
          </button>
          <button
            onClick={() => router.push("/wallet-entry/new")}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700 transition"
          >
            <Plus size={15} />
            {lang === "AR" ? "إضافة جديد" : "Create New"}
          </button>
        </div>
      </div>

      <TableToolbar
        total={total}
        totalLabel={lang === "AR" ? "إدخالات" : "Entries"}
        search={walletIdFilter}
        onSearch={(v) => {
          setWalletIdFilter(v);
          setPage(1);
        }}
        searchPlaceholder={
          lang === "AR"
            ? "تصفية حسب الاسم أو معرف المحفظة..."
            : "Filter by Name or Wallet ID..."
        }
        action={
          <ColumnToggle
            columns={colOptions}
            visible={visible}
            onChange={setVisible}
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
      </TableToolbar>

      {query.isLoading ? (
        <div className="text-center py-20 text-gray-400">
          {t("common.loading")}
        </div>
      ) : entries.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 px-4 bg-white border border-gray-200 border-dashed rounded-2xl text-center">
          <div className="w-16 h-16 bg-gray-50 text-gray-400 rounded-full flex items-center justify-center mb-4">
            <FileText size={24} />
          </div>
          <h3 className="text-gray-900 font-semibold mb-1">
            {lang === "AR" ? "لا توجد نتائج" : "No results found"}
          </h3>
          <p className="text-sm text-gray-500">
            {lang === "AR"
              ? "لم يتم العثور على أية إدخالات"
              : "We couldn't find any wallet entries."}
          </p>
        </div>
      ) : (
        <>
          <div className="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm whitespace-nowrap">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50 text-gray-500 font-medium">
                    {visible.includes("id") && (
                      <th className="px-4 py-3">ID</th>
                    )}
                    {visible.includes("wallet_id") && (
                      <th className="px-4 py-3">Wallet ID</th>
                    )}
                    {/* COMPLETED: Added localized Table Header Element */}
                    {visible.includes("user_name") && (
                      <th className="px-4 py-3">
                        {lang === "AR" ? "اسم المستخدم" : "User Name"}
                      </th>
                    )}
                    {visible.includes("amount") && (
                      <th className="px-4 py-3">Amount</th>
                    )}
                    {visible.includes("order_id") && (
                      <th className="px-4 py-3">Order ID</th>
                    )}
                    {visible.includes("penalty_id") && (
                      <th className="px-4 py-3">Penalty ID</th>
                    )}
                    {visible.includes("unpaid_commission_id") && (
                      <th className="px-4 py-3">Commission ID</th>
                    )}
                    {visible.includes("customer_coupon_id") && (
                      <th className="px-4 py-3">Customer Coupon ID</th>
                    )}
                    {visible.includes("courier_coupon_id") && (
                      <th className="px-4 py-3">Courier Coupon ID</th>
                    )}
                    {visible.includes("points_to_money") && (
                      <th className="px-4 py-3">Points to Money</th>
                    )}
                    {visible.includes("notes") && (
                      <th className="px-4 py-3">Notes</th>
                    )}
                    {visible.includes("is_settled") && (
                      <th className="px-4 py-3">Settled</th>
                    )}
                    {visible.includes("settled_at") && (
                      <th className="px-4 py-3">Settled At</th>
                    )}
                    {visible.includes("settlement_id") && (
                      <th className="px-4 py-3">Settlement ID</th>
                    )}
                    {visible.includes("created_at") && (
                      <th className="px-4 py-3">Created At</th>
                    )}
                    {visible.includes("actions") && (
                      <th className="px-4 py-3 text-right">
                        {t("common.actions")}
                      </th>
                    )}
                  </tr>
                </thead>
                <tbody>
                  {entries.map((entry) => (
                    <tr
                      key={entry.id}
                      onClick={() => router.push(`/wallet-entry/${entry.id}`)}
                      className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors cursor-pointer group"
                    >
                      {visible.includes("id") && (
                        <td className="px-4 py-3 font-medium text-gray-900">
                          #{entry.id}
                        </td>
                      )}
                      {visible.includes("wallet_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.wallet_id}
                        </td>
                      )}
                      {/* 
                        COMPLETED & FIXED: Added User Name body column mapping. 
                        We safety-cast 'entry as any' to read the deep relation property 
                        'wallet?.user?.full_name' dynamically without crashing the type system.
                      */}
                      {visible.includes("user_name") && (
                        <td className="px-4 py-3 text-gray-600">
                          {(entry as any).wallet?.user?.full_name || "—"}
                        </td>
                      )}
                      {visible.includes("amount") && (
                        <td className="px-4 py-3">
                          <span
                            className={cn(
                              "font-semibold",
                              entry.amount < 0
                                ? "text-red-600"
                                : "text-green-600",
                            )}
                          >
                            {fmtAmt(entry.amount)}
                          </span>
                        </td>
                      )}
                      {visible.includes("order_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.order_id || "—"}
                        </td>
                      )}
                      {visible.includes("penalty_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.penalty_id || "—"}
                        </td>
                      )}
                      {visible.includes("unpaid_commission_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.unpaid_commission_id || "—"}
                        </td>
                      )}
                      {visible.includes("customer_coupon_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.customer_coupon_id || "—"}
                        </td>
                      )}
                      {visible.includes("courier_coupon_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.courier_coupon_id || "—"}
                        </td>
                      )}
                      {visible.includes("points_to_money") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.points_to_money || "—"}
                        </td>
                      )}
                      {visible.includes("notes") && (
                        <td className="px-4 py-3">
                          <div
                            className="max-w-[150px] truncate text-gray-500"
                            title={entry.notes || ""}
                          >
                            {entry.notes || "—"}
                          </div>
                        </td>
                      )}
                      {visible.includes("is_settled") && (
                        <td className="px-4 py-3">
                          <span
                            className={cn(
                              "px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
                              entry.is_settled
                                ? "bg-green-100 text-green-700"
                                : "bg-yellow-100 text-yellow-700",
                            )}
                          >
                            {entry.is_settled
                              ? lang === "AR"
                                ? "مسوى"
                                : "Settled"
                              : lang === "AR"
                                ? "معلق"
                                : "Pending"}
                          </span>
                        </td>
                      )}
                      {visible.includes("settled_at") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.settled_at ? fmtDate(entry.settled_at) : "—"}
                        </td>
                      )}
                      {visible.includes("settlement_id") && (
                        <td className="px-4 py-3 text-gray-600">
                          {entry.settlement_id || "—"}
                        </td>
                      )}
                      {visible.includes("created_at") && (
                        <td className="px-4 py-3 text-gray-600">
                          {fmtDate(entry.created_at)}
                        </td>
                      )}
                      {visible.includes("actions") && (
                        <td className="px-4 py-3 text-right">
                          <button className="p-1.5 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors">
                            <ChevronRight size={18} />
                          </button>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <TablePagination
            page={page}
            totalPages={totalPages}
            total={total}
            limit={limit}
            onPageChange={setPage}
          />
        </>
      )}
    </div>
  );
}
