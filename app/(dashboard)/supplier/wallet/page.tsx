"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import api, { supplierApi } from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import { Wallet, RefreshCw, ArrowUpRight, ArrowDownLeft, Loader2, FileText, ChevronLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

function fmt(n: number) { return `${(n / 100).toFixed(2)} EGP`; }

export default function SupplierWalletPage() {
  const { t, lang, isRTL } = useT();
  const [page, setPage] = useState(1);
  const limit = 10;

  const { data: walletData, isLoading: walletLoading, refetch: refetchWallet, isFetching: walletFetching } = useQuery({
    queryKey: ["supplier-wallet"],
    queryFn: async () => {
      const res = await supplierApi.get("/wallet/wallet-data");
      return res.data?.data?.wallet ?? res.data?.data ?? res.data;
    },
    staleTime: 60_000,
  });

  const walletId = walletData?.id;

  const { data: txData, isLoading: txLoading, refetch: refetchTx, isFetching: txFetching } = useQuery({
    queryKey: ["supplier-related-transactions", walletId, page],
    queryFn: async () => {
      const res = await api.get("/admin/wallet/transactions", {
        params: {
          page,
          limit,
          skip: (page - 1) * limit,
          fields: "id,amount,type,status,description,created_at,order_id",
          sort: "-created_at",
          wallet_id: walletId,
        }
      });
      return res.data?.data ?? res.data;
    },
    enabled: !!walletId,
    staleTime: 60_000,
  });

  const { data: finesData, refetch: refetchFines } = useQuery({
    queryKey: ["supplier-fines"],
    queryFn: async () => {
      const res = await supplierApi.get("/wallet/total-fines");
      return res.data?.data ?? res.data;
    },
    staleTime: 60_000,
  });

  const isLoading = walletLoading || (txLoading && !!walletId);
  const isFetching = walletFetching || txFetching;
  
  const transactions = txData?.transactions ?? [];
  const totalItems = txData?.pagination?.total ?? txData?.totalItems ?? txData?.total ?? txData?.count ?? transactions.length;
  let totalPages = txData?.pagination?.total_pages ?? txData?.totalPages ?? Math.ceil(totalItems / limit);

  // If backend doesn't return total metadata but we got a full page, assume there might be a next page
  if (!txData?.pagination && !txData?.totalPages && !txData?.totalItems && !txData?.total && transactions.length === limit) {
    totalPages = Math.max(totalPages, page + 1);
  }

  function refetch() { refetchWallet(); refetchTx(); refetchFines(); }

  return (
    <div className="p-6 space-y-6 max-w-5xl mx-auto" dir={isRTL ? "rtl" : "ltr"}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Wallet size={20} className="text-indigo-600" />
          <h1 className="text-xl font-bold text-gray-900">{t("sp.wallet.title")}</h1>
        </div>
        <button onClick={refetch} disabled={isFetching}
          className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
        </button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center min-h-[200px]">
          <Loader2 className="animate-spin text-indigo-600" size={28} />
        </div>
      ) : (
        <>
          {/* Balance card */}
          <div className="bg-gradient-to-br from-indigo-600 to-indigo-800 shadow-lg shadow-indigo-200 rounded-3xl p-8 text-white relative overflow-hidden">
            <div className="absolute top-0 right-0 p-8 opacity-10 pointer-events-none">
              <Wallet size={120} />
            </div>
            <div className="relative z-10">
              <p className="text-sm font-medium text-indigo-200 mb-2">{t("sp.wallet.balance")}</p>
              <p className="text-5xl font-extrabold tracking-tight">{walletData?.balance != null ? fmt(walletData.balance) : "—"}</p>
              <div className="mt-6 flex items-center gap-3">
                <span className={cn("text-xs px-3 py-1 rounded-full font-bold uppercase tracking-wide shadow-sm",
                  walletData?.status === "ACTIVE" ? "bg-emerald-400/20 text-emerald-100 border border-emerald-400/30" : "bg-red-400/20 text-red-100 border border-red-400/30")}>
                  {walletData?.status ?? "—"}
                </span>
                {finesData?.totalFines != null && finesData.totalFines > 0 && (
                  <span className="text-xs px-3 py-1 rounded-full bg-red-400/20 text-red-100 font-bold border border-red-400/30 shadow-sm">
                    {t("sp.wallet.fines")}: {fmt(finesData.totalFines)}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Transactions */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden mt-6">
            <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between">
              <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
                <FileText size={18} className="text-indigo-600" />
                {lang === "AR" ? "المعاملات المرتبطة" : "Related Transactions"}
              </h2>
            </div>
            
            {transactions.length > 0 ? (
              <>
                <div className="divide-y divide-gray-50">
                  {transactions.map((tx: any) => {
                    const isCredit = tx.type === "ESCROW_RELEASE" || tx.type === "CREDIT" || tx.type === "REFUND";
                    return (
                      <div key={tx.id} className="px-6 py-4 flex items-center justify-between hover:bg-gray-50/50 transition">
                        <div className="flex items-center gap-4">
                          <div className={cn("w-10 h-10 rounded-xl flex items-center justify-center shadow-sm",
                            isCredit ? "bg-emerald-50 text-emerald-600 border border-emerald-100" : "bg-red-50 text-red-600 border border-red-100")}>
                            {isCredit ? <ArrowDownLeft size={18} /> : <ArrowUpRight size={18} />}
                          </div>
                          <div className="space-y-0.5">
                            <p className="text-sm font-bold text-gray-900 leading-tight">
                              {tx.type ? tx.type.replace(/_/g, " ") : "—"}
                            </p>
                            <p className="text-xs text-gray-500 font-medium max-w-[300px] sm:max-w-md truncate" title={tx.description}>
                              {tx.description ?? "—"}
                            </p>
                            <div className="flex items-center gap-3 mt-1">
                              <span className="text-[10px] text-gray-400 font-medium">
                                {tx.created_at ? new Date(tx.created_at).toLocaleString() : "—"}
                              </span>
                              {tx.order_id && (
                                <span className="text-[10px] bg-indigo-50 text-indigo-600 px-1.5 py-0.5 rounded font-bold">
                                  {lang === "AR" ? "طلب #" : "Order #"}{tx.order_id}
                                </span>
                              )}
                              {tx.status && (
                                <span className={cn("text-[10px] px-1.5 py-0.5 rounded font-bold", 
                                  tx.status === "COMPLETED" ? "bg-emerald-50 text-emerald-600" : "bg-gray-100 text-gray-600")}>
                                  {tx.status}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>
                        <span className={cn("font-extrabold text-base whitespace-nowrap",
                          isCredit ? "text-emerald-600" : "text-red-600")}>
                          {isCredit ? "+" : "−"}{fmt(tx.amount ?? 0)}
                        </span>
                      </div>
                    );
                  })}
                </div>
                {/* Pagination */}
                {totalPages > 0 && (
                  <div className="px-6 py-4 border-t border-gray-50 flex items-center justify-between bg-gray-50/30">
                    <p className="text-xs text-gray-500 font-medium">
                      {lang === "AR" ? "صفحة" : "Page"} {page} {lang === "AR" ? "من" : "of"} {totalPages}
                    </p>
                    <div className="flex gap-2">
                      <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                        className="p-1.5 border border-gray-200 bg-white rounded-lg disabled:opacity-40 hover:bg-gray-50 shadow-sm transition">
                        {isRTL ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
                      </button>
                      <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages}
                        className="p-1.5 border border-gray-200 bg-white rounded-lg disabled:opacity-40 hover:bg-gray-50 shadow-sm transition">
                        {isRTL ? <ChevronLeft size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </div>
                  </div>
                )}
              </>
            ) : (
              <div className="p-12 text-center">
                <Wallet size={48} className="mx-auto mb-4 text-gray-200" />
                <p className="text-sm font-medium text-gray-500">{lang === "AR" ? "لا توجد معاملات حالياً" : "No related transactions found"}</p>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
