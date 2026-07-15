"use client";

import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useT } from "@/contexts/LanguageContext";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { DataTable } from "@/components/ui/DataTable";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";

import {
  Undo2,
  RefreshCw,
  XCircle,
  CheckCircle2,
  ShieldAlert,
  DollarSign,
  Package,
  ImageIcon,
} from "lucide-react";

import {
  fetchAllRefunds,
  reviewRefundRequest,
  type Refund,
  type FaultType,
} from "@/lib/refunds";

import {
  buildRefundColumns,
  REFUND_SORT_FIELD_MAP,
} from "./_components/refunds.columns";

const ALL_COLUMN_KEYS = [
  "id",
  "order_number",
  "amount",
  "status",
  "reason",
  "created_at",
  "actions",
] as const;

export default function RefundsPage() {
  const queryClient = useQueryClient();
  const { t } = useT();

  const [page, setPage] = useState(1);
  const [limit] = useState(15);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("");

  const [sortField, setSortField] = useState<string>("created_at");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc");

  // Review Modal State
  const [selectedRefund, setSelectedRefund] = useState<Refund | null>(null);
  const [reviewStatus, setReviewStatus] = useState<"APPROVED" | "REJECTED">(
    "APPROVED",
  );
  const [faultType, setFaultType] = useState<FaultType>("SUPPLIER");
  const [penaltyAmount, setPenaltyAmount] = useState<string>("0");
  const [adminNotes, setAdminNotes] = useState<string>("");

  const resetPage = () => setPage(1);

  const { visible, setVisible } = useColumnVisibility("cols:refunds", [
    ...ALL_COLUMN_KEYS,
  ]);

  const queryParams = useMemo(
    () => ({
      page,
      limit,
      search: search || undefined,
      status: statusFilter || undefined,
      sortField,
      sortDir,
    }),
    [page, limit, search, statusFilter, sortField, sortDir],
  );

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: ["refunds", queryParams],
    queryFn: () => fetchAllRefunds(queryParams),
  });

  const refunds = data?.refunds ?? [];
  const total = data?.total ?? 0;
  const totalPages = data?.totalPages ?? 1;

  const reviewMutation = useMutation({
    mutationFn: () =>
      reviewRefundRequest(selectedRefund!.id, {
        status: reviewStatus,
        fault_type: faultType,
        penalty_amount: (Number(penaltyAmount) || 0) * 100,
        admin_notes: adminNotes || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["refunds"] });
      toast.success("Refund evaluation updated successfully");
      closeReviewModal();
    },
    onError: (err: any) => {
      toast.error(
        err.response?.data?.message ||
          "Failed to process review validation payload",
      );
    },
  });

  const handleSortChange = (columnKey: string, dir: "asc" | "desc") => {
    const field = REFUND_SORT_FIELD_MAP[columnKey];
    if (field) {
      setSortField(field);
      setSortDir(dir);
      resetPage();
    }
  };

  const closeReviewModal = () => {
    setSelectedRefund(null);
    setAdminNotes("");
    setPenaltyAmount("0");
    setFaultType("SUPPLIER");
  };

  // Build strictly type safe column rendering parameters mapping using Factory callback helper
  const allColumns = useMemo(
    () =>
      buildRefundColumns({
        onReview: (row) => {
          setSelectedRefund(row);
          setReviewStatus(
            row.status === "REQUESTED" ? "APPROVED" : (row.status as any),
          );
        },
      }),
    [],
  );

  const columns = useMemo(
    () => allColumns.filter((c) => visible.includes(c.key as any)),
    [allColumns, visible],
  );
  const columnOptions: ColumnOption[] = useMemo(
    () =>
      allColumns.map((c) => ({
        key: c.key,
        label: c.label,
      })),
    [allColumns],
  );

  const activeSortColumnKey = useMemo(() => {
    return (
      Object.entries(REFUND_SORT_FIELD_MAP).find(
        ([, f]) => f === sortField,
      )?.[0] || "created_at"
    );
  }, [sortField]);

  // Helper parser for processing stringified evidence images layout safely
  const evidenceImagesList = useMemo(() => {
    if (!selectedRefund?.evidence_images) return [];
    try {
      // Handles JSON array layout strings or comma-separated raw lines
      if (selectedRefund.evidence_images.startsWith("[")) {
        return JSON.parse(selectedRefund.evidence_images) as string[];
      }
      return selectedRefund.evidence_images
        .split(",")
        .map((img) => img.trim())
        .filter(Boolean);
    } catch {
      return [selectedRefund.evidence_images];
    }
  }, [selectedRefund]);

  return (
    <div className="p-6 space-y-6">
      {/* ── Header Layer ── */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Undo2 size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              {t("nav.refunds")}
            </h1>
          </div>
          <p className="text-sm text-gray-500">
            Process, evaluate, and manage multi-vendor platform balance reversal
            requests.
          </p>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition disabled:opacity-50"
        >
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
          Refresh
        </button>
      </div>

      {/* ── Toolbar Layer ── */}
      <TableToolbar
        total={total}
        totalLabel="refund tickets"
        search={search}
        onSearch={(v) => {
          setSearch(v);
          resetPage();
        }}
        searchPlaceholder="Search by Order ID or descriptions..."
        action={
          <div className="flex items-center gap-2">
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                resetPage();
              }}
              className="border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
            >
              <option value="">All Statuses</option>
              <option value="REQUESTED">Requested</option>
              <option value="APPROVED">Approved</option>
              <option value="REJECTED">Rejected</option>
              <option value="CANCELLED">Cancelled</option>
            </select>
            <ColumnToggle
              columns={columnOptions}
              visible={visible}
              onChange={setVisible}
            />
          </div>
        }
      />

      {/* ── Data Core Table Layer ── */}
      <DataTable
        columns={columns}
        rows={refunds}
        keyExtractor={(r: Refund) => r.id.toString()}
        isLoading={isLoading}
        emptyText="No refund requests found"
        emptyIcon={<Undo2 size={36} className="text-gray-300" />}
        serverSortKey={activeSortColumnKey}
        serverSortDir={sortDir}
        onSortChange={handleSortChange}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={total}
        limit={limit}
        onPageChange={setPage}
      />

      {/* ── Review Administration Modal Overlay ── */}
      {selectedRefund && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl border border-gray-100 shadow-xl max-w-xl w-full overflow-hidden flex flex-col max-h-[90vh]">
            <div className="p-5 border-b border-gray-100 flex items-center justify-between">
              <div>
                <h3 className="text-lg font-bold text-gray-900">
                  Review Request Details
                </h3>
                <p className="text-xs text-gray-500 mt-0.5">
                  Ticket Context ID: #{selectedRefund.id}
                </p>
              </div>
              <button
                onClick={closeReviewModal}
                className="text-gray-400 hover:text-gray-600 p-1 rounded-lg"
              >
                <XCircle size={20} />
              </button>
            </div>

            <div className="p-5 space-y-5 overflow-y-auto text-sm flex-1">
              {/* Context Summary Blocks */}
              <div className="grid grid-cols-2 gap-3 bg-gray-50 p-3.5 rounded-xl border border-gray-100">
                <div>
                  <span className="text-xs text-gray-400 block">
                    Order Attachment
                  </span>
                  <span className="font-semibold text-gray-900">
                    #{selectedRefund.order_id}
                  </span>
                </div>
                <div>
                  <span className="text-xs text-gray-400 block">
                    Requested Amount
                  </span>
                  <span className="font-semibold text-gray-900 font-mono">
                    {selectedRefund.amount.toFixed(2)} {selectedRefund.currency}
                  </span>
                </div>
                <div className="col-span-2 pt-2 border-t border-gray-200/60">
                  <span className="text-xs text-gray-400 block">
                    Statement Issue Description
                  </span>
                  <p className="text-xs text-gray-700 mt-1 italic">
                    "{selectedRefund.reason || "No written statements provided"}
                    "
                  </p>
                </div>
              </div>

              {/* ── Refunded Items Section ── */}
              <div className="space-y-2">
                <label className="text-xs font-semibold text-gray-700 uppercase tracking-wider flex items-center gap-1.5">
                  <Package size={14} className="text-gray-400" />
                  Target Refund Line Items ({selectedRefund.items?.length ?? 0})
                </label>
                {selectedRefund.items && selectedRefund.items.length > 0 ? (
                  <div className="border border-gray-100 rounded-xl overflow-hidden divide-y divide-gray-100">
                    {selectedRefund.items.map((item) => (
                      <div
                        key={item.id}
                        className="p-3 flex items-center justify-between bg-white hover:bg-gray-50/50 transition"
                      >
                        <div>
                          <p className="font-medium text-gray-900">
                            {item.product?.name ||
                              `Item ID: #${item.order_item_id}`}
                          </p>
                          {item.product?.name_ar && (
                            <p className="text-xs text-gray-400 dir-rtl text-right mt-0.5">
                              {item.product.name_ar}
                            </p>
                          )}
                        </div>
                        <div className="text-right">
                          <span className="text-xs bg-gray-100 text-gray-600 font-medium px-2 py-0.5 rounded-md mr-3">
                            Qty: {item.quantity}
                          </span>
                          <span className="font-mono text-xs font-semibold text-gray-700">
                            {item.amount.toFixed(2)} {selectedRefund.currency}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-gray-400 italic bg-gray-50/50 p-3 rounded-xl border border-dashed text-center">
                    No explicit breakdown items bound to this ticket setup.
                  </p>
                )}
              </div>

              {/* ── Evidence Media Layer ── */}
              <div className="space-y-2">
                <label className="text-xs font-semibold text-gray-700 uppercase tracking-wider flex items-center gap-1.5">
                  <ImageIcon size={14} className="text-gray-400" />
                  Attachment Evidence Files
                </label>
                {evidenceImagesList.length > 0 ? (
                  <div className="grid grid-cols-3 gap-2.5">
                    {evidenceImagesList.map((url, index) => (
                      <a
                        key={index}
                        href={url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="group relative aspect-square border border-gray-200 rounded-xl overflow-hidden bg-gray-50 hover:border-indigo-300 transition"
                      >
                        <img
                          src={url}
                          alt={`Evidence File ${index + 1}`}
                          className="object-cover w-full h-full transition group-hover:scale-105"
                        />
                        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 flex items-center justify-center transition">
                          <span className="text-[10px] text-white font-medium bg-black/60 px-2 py-0.5 rounded opacity-0 group-hover:opacity-100 transition">
                            View Full
                          </span>
                        </div>
                      </a>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-gray-400 italic bg-gray-50/50 p-3 rounded-xl border border-dashed text-center">
                    No image files submitted for assessment.
                  </p>
                )}
              </div>

              {/* ── Operational Form Inputs ── */}
              {selectedRefund.status === "REQUESTED" ? (
                <div className="space-y-4 pt-2 border-t border-gray-100">
                  <div>
                    <label className="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-2">
                      Resolution Decision
                    </label>
                    <div className="grid grid-cols-2 gap-3">
                      <button
                        type="button"
                        onClick={() => setReviewStatus("APPROVED")}
                        className={cn(
                          "py-2.5 px-4 rounded-xl border text-sm font-medium flex items-center justify-center gap-2 transition",
                          reviewStatus === "APPROVED"
                            ? "bg-green-50 border-green-500 text-green-700 font-bold shadow-sm"
                            : "border-gray-200 text-gray-600 hover:bg-gray-50",
                        )}
                      >
                        <CheckCircle2 size={16} /> Approve
                      </button>
                      <button
                        type="button"
                        onClick={() => setReviewStatus("REJECTED")}
                        className={cn(
                          "py-2.5 px-4 rounded-xl border text-sm font-medium flex items-center justify-center gap-2 transition",
                          reviewStatus === "REJECTED"
                            ? "bg-red-50 border-red-500 text-red-700 font-bold shadow-sm"
                            : "border-gray-200 text-gray-600 hover:bg-gray-50",
                        )}
                      >
                        <XCircle size={16} /> Reject
                      </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1.5 flex items-center gap-1">
                        <ShieldAlert size={12} className="text-gray-400" /> Root
                        Fault Party
                      </label>
                      <select
                        value={faultType}
                        onChange={(e) =>
                          setFaultType(e.target.value as FaultType)
                        }
                        className="w-full border border-gray-300 rounded-xl px-3 py-2.5 text-sm bg-white outline-none focus:ring-2 focus:ring-indigo-500"
                      >
                        {/* <option value="PLATFORM">Platform</option> */}
                        <option value="SUPPLIER">Supplier</option>
                        <option value="COURIER">Courier</option>
                      </select>
                    </div>

                    <div>
                      <label className="text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1.5 flex items-center gap-1">
                        <DollarSign size={12} className="text-gray-400" />{" "}
                        Additional Penalty Fee (EGP)
                      </label>
                      <input
                        type="number"
                        min="0"
                        value={penaltyAmount}
                        onChange={(e) => setPenaltyAmount(e.target.value)}
                        className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                        placeholder="0.00"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1.5">
                      Administrative Evaluation Summary
                    </label>
                    <textarea
                      rows={3}
                      value={adminNotes}
                      onChange={(e) => setAdminNotes(e.target.value)}
                      placeholder="Input standard logical reasoning parameters outlining the adjustment verification path..."
                      className="w-full border border-gray-300 rounded-xl px-3 py-2 text-xs outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
                    />
                  </div>
                </div>
              ) : (
                <div className="bg-gray-50 p-4 rounded-xl border border-dashed border-gray-200 text-xs space-y-2 text-gray-600">
                  <p className="font-medium text-gray-700 uppercase tracking-wider text-[10px]">
                    Processing Outcome Statement
                  </p>
                  <div>
                    Status Flag:{" "}
                    <span className="font-semibold text-gray-900">
                      {selectedRefund.status}
                    </span>
                  </div>
                  <div>
                    Resolution Context Completion metrics are frozen. Further
                    state transformations must traverse systemic database
                    recovery configurations.
                  </div>
                </div>
              )}
            </div>

            {/* Footer Form Controls */}
            <div className="p-4 bg-gray-50 border-t border-gray-100 flex items-center justify-end gap-2.5">
              <button
                type="button"
                onClick={closeReviewModal}
                className="px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-800 transition"
              >
                Close
              </button>
              {selectedRefund.status === "REQUESTED" && (
                <button
                  type="button"
                  disabled={reviewMutation.isPending}
                  onClick={() => reviewMutation.mutate()}
                  className="px-5 py-2 rounded-xl bg-indigo-600 text-white font-medium text-sm hover:bg-indigo-700 transition shadow-md disabled:opacity-50"
                >
                  {reviewMutation.isPending
                    ? "Submitting Audit..."
                    : "Commit Authorization Decision"}
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
