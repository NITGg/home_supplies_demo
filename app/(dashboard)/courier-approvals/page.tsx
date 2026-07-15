"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchCourierApprovals, approveCourier, rejectCourier, type CourierApproval } from "@/lib/courier-approvals";
import { sendCourierApprovalNotification } from "@/lib/notifications";
import { useT } from "@/contexts/LanguageContext";
import { Truck, RefreshCw, CheckCircle, XCircle, X, FileImage, ExternalLink, MapPin } from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

const ALL_COLUMN_KEYS = ["id", "courier", "phone", "vehicle_type", "vehicle_plate", "is_approved", "created_at", "updated_at", "actions"] as const;

// ── Document image tile with lightbox ─────────────────────────────────────────
function DocTile({ label, url }: { label: string; url?: string | null }) {
  const [open, setOpen] = useState(false);
  if (!url) return (
    <div className="flex flex-col items-center justify-center border border-dashed border-gray-200 rounded-lg p-3 bg-gray-50 min-h-[90px]">
      <FileImage size={18} className="text-gray-300 mb-1" />
      <p className="text-[11px] text-gray-400 text-center">{label}</p>
    </div>
  );
  return (
    <>
      <div className="cursor-pointer group rounded-lg overflow-hidden border border-gray-200 hover:border-indigo-300 transition" onClick={() => setOpen(true)}>
        <img src={url} alt={label} className="w-full h-[90px] object-cover group-hover:opacity-80 transition" />
        <p className="text-[11px] text-gray-500 text-center py-1 px-1 truncate bg-white">{label}</p>
      </div>
      {open && (
        <div className="fixed inset-0 z-[200] bg-black/85 flex items-center justify-center p-4" onClick={() => setOpen(false)}>
          <div className="relative max-w-2xl w-full" onClick={e => e.stopPropagation()}>
            <p className="text-white text-sm font-medium mb-3 text-center">{label}</p>
            <img src={url} alt={label} className="w-full max-h-[75vh] object-contain rounded-xl shadow-2xl" />
            <div className="flex justify-center gap-3 mt-4">
              <a href={url} target="_blank" rel="noreferrer" className="flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 text-white rounded-xl text-sm transition" onClick={e => e.stopPropagation()}>
                <ExternalLink size={13} /> Open original
              </a>
              <button onClick={() => setOpen(false)} className="flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 text-white rounded-xl text-sm transition">
                <X size={13} /> Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

// ── Courier documents modal ───────────────────────────────────────────────────
function CourierDocsModal({ courier, onClose, onApprove, onReject }: {
  courier: CourierApproval;
  onClose: () => void;
  onApprove: () => void;
  onReject: () => void;
}) {
  const docs: { label: string; url?: string | null }[] = [
    { label: "National ID — Front", url: courier.national_id_photo_front },
    { label: "National ID — Back",  url: courier.national_id_photo_back  },
    { label: "Vehicle License — Front", url: courier.vehicle_license_front },
    { label: "Vehicle License — Back",  url: courier.vehicle_license_back  },
    { label: "Courier License — Front", url: courier.courier_license_front },
    { label: "Courier License — Back",  url: courier.courier_license_back  },
    { label: "Criminal Record",         url: courier.courier_criminal_record },
    { label: "Personal Photo",          url: courier.user?.personal_photo },
  ];
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 shrink-0">
          <div>
            <h2 className="text-lg font-bold text-gray-900">{courier.user?.full_name ?? `Courier #${courier.id}`}</h2>
            <p className="text-xs text-gray-400 mt-0.5">{courier.user?.phone} · {courier.vehicle_type ?? "—"} · {courier.vehicle_plate ?? "No plate"}</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>

        <div className="overflow-y-auto flex-1 p-6 space-y-4">
          {/* Location */}
          {(courier.lat || courier.lng) && (
            <div className="flex items-center gap-3 p-3 bg-blue-50 rounded-xl text-sm text-blue-700">
              <MapPin size={14} />
              <span className="font-mono">{Number(courier.lat).toFixed(6)}, {Number(courier.lng).toFixed(6)}</span>
              <a href={`https://www.google.com/maps?q=${courier.lat},${courier.lng}`} target="_blank" rel="noreferrer"
                className="ml-auto flex items-center gap-1 hover:underline text-xs">
                <ExternalLink size={12} /> Map
              </a>
            </div>
          )}

          {/* National ID */}
          {courier.national_id_number && (
            <p className="text-sm text-gray-600">
              <span className="font-semibold text-gray-700">National ID: </span>{courier.national_id_number}
            </p>
          )}

          {/* Rejection reason */}
          {courier.reject_reason && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
              <span className="font-semibold">Rejection reason: </span>{courier.reject_reason}
            </div>
          )}

          {/* Documents grid */}
          <div className="grid grid-cols-3 sm:grid-cols-4 gap-3">
            {docs.map(d => <DocTile key={d.label} label={d.label} url={d.url} />)}
          </div>
        </div>

        {!courier.is_approved && (
          <div className="flex justify-end gap-3 px-6 py-4 border-t border-gray-100 shrink-0">
            <button onClick={onReject} className="px-5 py-2 text-sm bg-red-600 text-white rounded-xl hover:bg-red-700">Reject</button>
            <button onClick={onApprove} className="px-5 py-2 text-sm bg-green-600 text-white rounded-xl hover:bg-green-700">Approve</button>
          </div>
        )}
      </div>
    </div>
  );
}

export default function CourierApprovalsPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "pending" | "approved">("all");
  const [rejectModal, setRejectModal] = useState<CourierApproval | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [docsModal, setDocsModal] = useState<CourierApproval | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:courier-approvals", [...ALL_COLUMN_KEYS]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["courier-approvals", params],
    queryFn: () => fetchCourierApprovals(params),
  });

  const allCouriers = data?.couriers ?? [];
  const couriers = allCouriers.filter(c => {
    if (createdFrom && new Date(c.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(c.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(c.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(c.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    if (statusFilter === "pending"  && c.is_approved)  return false;
    if (statusFilter === "approved" && !c.is_approved) return false;
    return true;
  });

  const total = data?.pagination?.total ?? 0;
  const totalPages = data?.pagination?.total_pages ?? 1;
  const approvedCount = couriers.filter(c => c.is_approved).length;
  const pendingCount = couriers.filter(c => !c.is_approved).length;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? couriers.length : total;

  const approveMut = useMutation({
    mutationFn: ({ courierId }: { courierId: number; userId: number }) => approveCourier(courierId),
    onSuccess: (_, { userId }) => {
      toast.success(t("courierApprovals.approveSuccess"));
      qc.invalidateQueries({ queryKey: ["courier-approvals"] });
      // Send bilingual push notification to the courier's device (fire-and-forget)
      sendCourierApprovalNotification(userId).catch(() => {});
    },
    onError: () => toast.error("Failed to approve"),
  });

  const rejectMut = useMutation({
    mutationFn: ({ id, reason }: { id: number; reason: string }) => rejectCourier(id, reason),
    onSuccess: () => { toast.success(t("courierApprovals.rejectSuccess")); qc.invalidateQueries({ queryKey: ["courier-approvals"] }); setRejectModal(null); setRejectReason(""); },
    onError: () => toast.error("Failed to reject"),
  });

  const allColumns: Column<CourierApproval>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: c => c.id,
      render: c => <span className="text-xs font-mono text-gray-400">#{c.id}</span>,
    },
    {
      key: "courier",
      label: "Courier",
      sortable: true,
      getValue: c => c.user?.full_name ?? `#${c.user_id}`,
      render: c => (
        <div>
          <p className="font-medium text-gray-900">{c.user?.full_name ?? `#${c.user_id}`}</p>
          {c.user?.email && <p className="text-xs text-gray-400">{c.user.email}</p>}
        </div>
      ),
    },
    {
      key: "phone",
      label: "Phone",
      render: c => <span className="text-gray-600">{c.user?.phone ?? "—"}</span>,
    },
    {
      key: "vehicle_type",
      label: t("courierApprovals.vehicleType"),
      sortable: true,
      getValue: c => c.vehicle_type ?? "",
      render: c => <span className="text-gray-600">{c.vehicle_type ?? "—"}</span>,
    },
    {
      key: "vehicle_plate",
      label: t("courierApprovals.vehiclePlate"),
      render: c => <span className="text-gray-600 font-mono text-xs">{c.vehicle_plate ?? "—"}</span>,
    },
    {
      key: "is_approved",
      label: t("common.status"),
      sortable: true,
      getValue: c => c.is_approved ? 1 : 0,
      render: c => c.is_approved
        ? <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700"><CheckCircle size={11} /> {t("courierApprovals.approved")}</span>
        : <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-yellow-100 text-yellow-700"><XCircle size={11} /> {t("courierApprovals.pending")}</span>,
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
      getValue: c => new Date(c.updated_at),
      render: c => (
        <span className="text-xs text-gray-500">
          {new Date(c.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: c => (
        <div className="flex items-center justify-end gap-2">
          <button onClick={() => setDocsModal(c)}
            className="px-3 py-1.5 text-xs bg-indigo-50 text-indigo-700 border border-indigo-200 rounded-lg hover:bg-indigo-100 flex items-center gap-1">
            <FileImage size={12} /> Docs
          </button>
          {!c.is_approved && (
            <>
              <button onClick={() => approveMut.mutate({ courierId: c.id, userId: c.user_id })} disabled={approveMut.isPending}
                className="px-3 py-1.5 text-xs bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50">
                {t("courierApprovals.approve")}
              </button>
              <button onClick={() => { setRejectModal(c); setRejectReason(""); }}
                className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg hover:bg-red-700">
                {t("courierApprovals.reject")}
              </button>
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
            <Truck size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("courierApprovals.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("courierApprovals.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <div className="flex gap-4">
        {[
          { label: t("courierApprovals.total"), value: total, c: "indigo" },
          { label: t("courierApprovals.approved"), value: approvedCount, c: "green" },
          { label: t("courierApprovals.pending"), value: pendingCount, c: "yellow" },
        ].map(({ label, value, c }) => (
          <div key={label} className={`border rounded-2xl px-5 py-4 text-center ${c === "indigo" ? "bg-indigo-50 border-indigo-100" : c === "green" ? "bg-green-50 border-green-100" : "bg-yellow-50 border-yellow-100"}`}>
            <p className={`text-3xl font-bold ${c === "indigo" ? "text-indigo-700" : c === "green" ? "text-green-700" : "text-yellow-700"}`}>{value}</p>
            <p className={`text-xs mt-1 ${c === "indigo" ? "text-indigo-400" : c === "green" ? "text-green-400" : "text-yellow-500"}`}>{label}</p>
          </div>
        ))}
      </div>

      {/* Status filter */}
      <div className="flex items-center gap-1 p-1 bg-gray-100 rounded-xl w-fit">
        {(["all", "pending", "approved"] as const).map(f => (
          <button key={f} onClick={() => { setStatusFilter(f); setPage(1); }}
            className={`px-4 py-1.5 text-sm rounded-lg font-medium transition capitalize ${
              statusFilter === f ? "bg-white shadow text-gray-900" : "text-gray-500 hover:text-gray-700"
            }`}>
            {f === "all" ? "All Couriers" : f === "pending" ? "Pending Only" : "Approved Only"}
          </button>
        ))}
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="courier"
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("courierApprovals.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
          </div>
        }
      >
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

      <DataTable<CourierApproval>
        columns={columns}
        rows={couriers}
        keyExtractor={c => c.id}
        isLoading={isLoading}
        emptyText={t("courierApprovals.noResults")}
        emptyIcon={<Truck size={36} className="text-gray-300" />}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={displayTotal}
        limit={20}
        onPageChange={setPage}
      />

      {docsModal && (
        <CourierDocsModal
          courier={docsModal}
          onClose={() => setDocsModal(null)}
          onApprove={() => { approveMut.mutate({ courierId: docsModal.id, userId: docsModal.user_id }); setDocsModal(null); }}
          onReject={() => { setRejectModal(docsModal); setRejectReason(""); setDocsModal(null); }}
        />
      )}

      {rejectModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
            <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
              <h2 className="text-lg font-bold text-gray-900">{t("courierApprovals.reject")}</h2>
              <button onClick={() => setRejectModal(null)} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
            </div>
            <div className="px-6 py-5 space-y-4">
              <p className="text-sm text-gray-600">Rejecting: <strong>{rejectModal.user?.full_name}</strong></p>
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">{t("courierApprovals.rejectReason")}</label>
                <textarea required value={rejectReason} onChange={e => setRejectReason(e.target.value)} rows={3}
                  className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
              </div>
              <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
                <button onClick={() => setRejectModal(null)} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">{t("common.cancel")}</button>
                <button onClick={() => rejectReason.trim() && rejectMut.mutate({ id: rejectModal.id, reason: rejectReason })}
                  disabled={rejectMut.isPending || !rejectReason.trim()}
                  className="px-6 py-2.5 bg-red-600 text-white rounded-xl text-sm font-medium hover:bg-red-700 disabled:opacity-60">
                  {rejectMut.isPending ? t("common.saving") : t("courierApprovals.reject")}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
