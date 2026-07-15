"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useT } from "@/contexts/LanguageContext";
import {
  fetchProposals,
  respondToProposal,
  proposalTotalCents,
  formatCents,
  type Proposal,
} from "@/lib/personalOrders";
import { formatDistance, formatDuration } from "@/lib/formatters";
import toast from "react-hot-toast";
import {
  X,
  Loader2,
  AlertCircle,
  Phone,
  ChevronDown,
  Star,
  Check,
  Ban,
  ArrowDownUp,
  Navigation,
  Inbox,
  Clock,
} from "lucide-react";

type SortKey = "fee" | "distance";
type SortDir = "asc" | "desc";

const STATUS_BADGE: Record<string, string> = {
  PENDING: "bg-amber-100 text-amber-700",
  ACCEPTED: "bg-green-100 text-green-700",
  REJECTED: "bg-red-100 text-red-600",
};

export default function ProposalsSheet({
  orderId,
  open,
  onClose,
  onAccepted,
}: {
  orderId: number;
  open: boolean;
  onClose: () => void;
  onAccepted: () => void;
}) {
  const { t, isRTL, lang } = useT();
  const [sortKey, setSortKey] = useState<SortKey | null>(null);
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [expanded, setExpanded] = useState<number | null>(null);
  const [confirm, setConfirm] = useState<{ proposal: Proposal; type: "ACCEPTED" | "REJECTED" } | null>(
    null,
  );
  const [acting, setActing] = useState(false);

  const {
    data: proposals = [],
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ["order-proposals", orderId],
    queryFn: () => fetchProposals(orderId, lang),
    enabled: open,
    refetchInterval: open ? 10000 : false, // light polling in place of the socket feed
  });

  const sorted = useMemo(() => {
    const list = [...proposals];
    list.sort((a, b) => {
      // Rejected always at the bottom regardless of the active sort.
      const aRej = a.status === "REJECTED" ? 1 : 0;
      const bRej = b.status === "REJECTED" ? 1 : 0;
      if (aRej !== bRej) return aRej - bRej;
      if (!sortKey) return 0;
      let diff = 0;
      if (sortKey === "fee") diff = proposalTotalCents(a) - proposalTotalCents(b);
      else diff = a.distanceToPickupM - b.distanceToPickupM;
      return sortDir === "asc" ? diff : -diff;
    });
    return list;
  }, [proposals, sortKey, sortDir]);

  if (!open) return null;

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortKey(key);
      setSortDir("asc");
    }
  }

  async function doRespond() {
    if (!confirm) return;
    setActing(true);
    try {
      await respondToProposal(orderId, confirm.proposal.id, confirm.type, lang);
      if (confirm.type === "ACCEPTED") {
        toast.success(t("sp.proposals.accepted"));
        setConfirm(null);
        onAccepted();
        onClose();
      } else {
        toast.success(t("sp.proposals.rejected"));
        setConfirm(null);
        refetch();
      }
    } catch (err: any) {
      toast.error(err?.response?.data?.message ?? t("sp.proposals.actionError"));
    } finally {
      setActing(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40 p-0 sm:p-4"
      dir={isRTL ? "rtl" : "ltr"}
    >
      <div className="bg-gray-50 rounded-t-2xl sm:rounded-2xl shadow-2xl w-full max-w-lg h-[80vh] sm:max-h-[85vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 bg-white rounded-t-2xl">
          <h2 className="text-lg font-bold text-gray-900">{t("sp.proposals.title")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>

        {/* Sort chips */}
        <div className="flex items-center gap-2 px-5 py-3 bg-white border-b border-gray-100">
          <span className="text-xs text-gray-400 flex items-center gap-1">
            <ArrowDownUp className="w-3.5 h-3.5" />
            {t("sp.proposals.sortBy")}
          </span>
          <SortChip
            active={sortKey === "fee"}
            dir={sortDir}
            label={t("sp.proposals.fee")}
            onClick={() => toggleSort("fee")}
          />
          <SortChip
            active={sortKey === "distance"}
            dir={sortDir}
            label={t("sp.proposals.nearMe")}
            onClick={() => toggleSort("distance")}
          />
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center h-full text-gray-400 gap-2">
              <Loader2 className="w-6 h-6 animate-spin" />
              <span className="text-sm">{t("common.loading")}</span>
            </div>
          ) : isError ? (
            <div className="flex flex-col items-center justify-center h-full text-gray-500 gap-3">
              <AlertCircle className="w-8 h-8 text-red-400" />
              <p className="text-sm">{t("sp.proposals.loadError")}</p>
              <button
                onClick={() => refetch()}
                className="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm"
              >
                {t("common.refresh")}
              </button>
            </div>
          ) : sorted.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-gray-400 gap-2 text-center">
              <Inbox className="w-10 h-10 text-gray-300" />
              <p className="text-sm font-medium text-gray-600">{t("sp.proposals.empty")}</p>
              <p className="text-xs">{t("sp.proposals.emptyHint")}</p>
            </div>
          ) : (
            sorted.map((p) => (
              <ProposalCard
                key={p.id}
                proposal={p}
                expanded={expanded === p.id}
                onToggle={() => setExpanded((e) => (e === p.id ? null : p.id))}
                onAccept={() => setConfirm({ proposal: p, type: "ACCEPTED" })}
                onReject={() => setConfirm({ proposal: p, type: "REJECTED" })}
              />
            ))
          )}
        </div>
      </div>

      {/* Accept / Reject confirmation */}
      {confirm && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6">
            <h3 className="text-base font-bold text-gray-900 mb-2">
              {confirm.type === "ACCEPTED"
                ? t("sp.proposals.confirmAcceptTitle")
                : t("sp.proposals.confirmRejectTitle")}
            </h3>
            <p className="text-sm text-gray-600 mb-4">
              {confirm.type === "ACCEPTED" ? (
                <>
                  {t("sp.proposals.confirmAcceptBody")}{" "}
                  <span className="font-semibold text-gray-900">{confirm.proposal.courierName}</span>{" "}
                  —{" "}
                  <span className="font-semibold text-indigo-600">
                    {formatCents(proposalTotalCents(confirm.proposal))}
                  </span>
                </>
              ) : (
                t("sp.proposals.confirmRejectBody")
              )}
            </p>
            <div className="flex gap-2">
              <button
                onClick={doRespond}
                disabled={acting}
                className={`flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-white disabled:opacity-50 ${
                  confirm.type === "ACCEPTED"
                    ? "bg-green-600 hover:bg-green-700"
                    : "bg-red-600 hover:bg-red-700"
                }`}
              >
                {acting ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                {t("common.confirm")}
              </button>
              <button
                onClick={() => setConfirm(null)}
                className="px-4 py-2.5 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-50"
              >
                {t("common.cancel")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function SortChip({
  active,
  dir,
  label,
  onClick,
}: {
  active: boolean;
  dir: SortDir;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-medium border transition ${
        active
          ? "bg-indigo-600 text-white border-indigo-600"
          : "bg-white text-gray-600 border-gray-200 hover:border-gray-300"
      }`}
    >
      {label}
      {active && <span>{dir === "asc" ? "↑" : "↓"}</span>}
    </button>
  );
}

function ProposalCard({
  proposal: p,
  expanded,
  onToggle,
  onAccept,
  onReject,
}: {
  proposal: Proposal;
  expanded: boolean;
  onToggle: () => void;
  onAccept: () => void;
  onReject: () => void;
}) {
  const { t, isRTL } = useT();
  const hasDiscount = p.discountFeeCents > 0;
  const total = proposalTotalCents(p);
  const original = p.courierFeeCents + p.platformFeeCents;
  const isPending = p.status === "PENDING";
  const vehicleName = (isRTL ? p.vehicleNameAr : p.vehicleName) || p.vehicleName || p.vehicleNameAr;

  return (
    <div
      className={`bg-white rounded-2xl border transition ${
        p.status === "REJECTED" ? "border-gray-100 opacity-70" : "border-gray-200"
      }`}
    >
      {/* Header (always visible) */}
      <button onClick={onToggle} className="w-full flex items-center gap-3 p-4 text-start">
        {p.courierPhoto ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={p.courierPhoto}
            alt={p.courierName}
            className="w-11 h-11 rounded-full object-cover shrink-0"
          />
        ) : (
          <div className="w-11 h-11 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center font-semibold shrink-0">
            {p.courierName.charAt(0)}
          </div>
        )}

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-gray-900 truncate">{p.courierName}</span>
            <span
              className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${
                STATUS_BADGE[p.status] ?? "bg-gray-100 text-gray-600"
              }`}
            >
              {p.status}
            </span>
          </div>
          <div className="flex items-center gap-3 mt-0.5 text-[11px] text-gray-400">
            <span className="flex items-center gap-0.5">
              <Navigation className="w-3 h-3" />
              {formatDistance(p.distanceToPickupM)}
            </span>
            <span className="flex items-center gap-0.5">
              <Clock className="w-3 h-3" />
              {formatDuration(p.timeToPickupSec)}
            </span>
          </div>
        </div>

        <div className="text-end shrink-0">
          <p className={`text-sm font-bold ${hasDiscount ? "text-green-600" : "text-gray-900"}`}>
            {formatCents(total)}
          </p>
          {hasDiscount && (
            <p className="text-[10px] text-gray-400 line-through">{formatCents(original)}</p>
          )}
        </div>
        <ChevronDown
          className={`w-4 h-4 text-gray-400 transition-transform ${expanded ? "rotate-180" : ""}`}
        />
      </button>

      {/* Expanded body */}
      {expanded && (
        <div className="px-4 pb-4 space-y-3 border-t border-gray-100 pt-3">
          {/* Phone */}
          {p.courierPhone && (
            <a
              href={`tel:${p.courierPhone}`}
              className="inline-flex items-center gap-1.5 text-sm text-indigo-600 hover:text-indigo-700"
            >
              <Phone className="w-3.5 h-3.5" />
              {p.courierPhone}
            </a>
          )}

          {/* Vehicle + rating */}
          <div className="flex items-center gap-3">
            {p.vehicleIcon && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={p.vehicleIcon} alt={vehicleName} className="w-8 h-8 object-contain" />
            )}
            {vehicleName && <span className="text-sm text-gray-700">{vehicleName}</span>}
            {p.courierVehiclePlate && p.courierVehiclePlate !== "N/A" && (
              <span className="text-xs font-mono px-2 py-0.5 bg-gray-100 rounded border border-gray-200">
                {p.courierVehiclePlate}
              </span>
            )}
            {p.courierRate != null && (
              <span className="ms-auto flex items-center gap-0.5 text-xs text-amber-500">
                <Star className="w-3.5 h-3.5 fill-amber-400" />
                {p.courierRate.toFixed(1)}
              </span>
            )}
          </div>

          {/* Fee breakdown */}
          <div className="space-y-1 text-xs">
            <div className="flex justify-between">
              <span className="text-gray-500">{t("sp.proposals.courierFee")}</span>
              <span className="text-gray-700">{formatCents(p.courierFeeCents)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">{t("sp.proposals.platformFee")}</span>
              <span className="text-gray-700">{formatCents(p.platformFeeCents)}</span>
            </div>
            {hasDiscount && (
              <div className="flex justify-between text-green-600">
                <span>{t("sp.proposals.discount")}</span>
                <span>-{formatCents(p.discountFeeCents)}</span>
              </div>
            )}
            <div className="flex justify-between font-semibold text-gray-900 pt-1 border-t border-gray-100">
              <span>{t("sp.proposals.total")}</span>
              <span>{formatCents(total)}</span>
            </div>
          </div>

          {/* Actions (PENDING only) */}
          {isPending && (
            <div className="flex gap-2 pt-1">
              <button
                onClick={onReject}
                className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl border-2 border-red-200 text-red-600 text-sm font-semibold hover:bg-red-50"
              >
                <Ban className="w-4 h-4" />
                {t("sp.proposals.reject")}
              </button>
              <button
                onClick={onAccept}
                className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-green-600 text-white text-sm font-semibold hover:bg-green-700"
              >
                <Check className="w-4 h-4" />
                {t("sp.proposals.accept")}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
