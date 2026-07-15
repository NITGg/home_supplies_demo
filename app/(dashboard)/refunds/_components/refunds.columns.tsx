import type { Column } from "@/components/ui/DataTable";
import type { Refund, RefundStatus } from "@/lib/refunds";
import { cn } from "@/lib/utils";
import {
  Eye,
  Clock,
  CheckCircle2,
  XCircle,
  AlertCircle,
  HelpCircle,
} from "lucide-react";

export const REFUND_SORT_FIELD_MAP: Record<string, string> = {
  id: "id",
  order_number: "order_id",
  amount: "amount",
  status: "status",
  created_at: "created_at",
};

const STATUS_STYLES: Record<RefundStatus, string> = {
  REQUESTED: "bg-amber-100 text-amber-700",
  APPROVED: "bg-green-100 text-green-700",
  COMPLETED: "bg-green-100 text-green-700",
  REJECTED: "bg-red-100 text-red-700",
  CANCELLED: "bg-gray-100 text-gray-600",
  FAILED: "bg-red-100 text-red-700",
  PROCESSING: "bg-blue-100 text-blue-600",
};

const STATUS_ICONS: Record<RefundStatus, React.ElementType> = {
  REQUESTED: Clock,
  APPROVED: CheckCircle2,
  COMPLETED: CheckCircle2,
  REJECTED: XCircle,
  CANCELLED: AlertCircle,
  FAILED: XCircle,
  PROCESSING: CheckCircle2,
};

interface BuildColumnsOptions {
  onReview: (refund: Refund) => void;
}

export function buildRefundColumns({
  onReview,
}: BuildColumnsOptions): Column<Refund>[] {
  return [
    {
      key: "id",
      label: "ID",
      sortable: true,
      render: (r) => (
        <span className="font-mono text-xs text-gray-500">#{r.id}</span>
      ),
    },
    {
      key: "order_number",
      label: "Order #",
      sortable: true,
      render: (r) => (
        <span className="font-semibold text-indigo-600">#{r.order_id}</span>
      ),
    },
    {
      key: "amount",
      label: "Amount",
      sortable: true,
      render: (r) => (
        <span className="font-medium font-mono text-gray-900">
          {r.amount.toFixed(2)} {r.currency}
        </span>
      ),
    },
    {
      key: "status",
      label: "Status",
      sortable: true,
      render: (r) => {
        const Icon = STATUS_ICONS[r.status] || HelpCircle;
        return (
          <span
            className={cn(
              "inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium",
              STATUS_STYLES[r.status],
            )}
          >
            <Icon size={11} />
            {r.status}
          </span>
        );
      },
    },
    {
      key: "reason",
      label: "Reason",
      sortable: false,
      render: (r) => (
        <span
          className="text-xs text-gray-600 max-w-xs block truncate"
          title={r.reason || ""}
        >
          {r.reason || "—"}
        </span>
      ),
    },
    {
      key: "created_at",
      label: "Requested Date",
      sortable: true,
      render: (r) => (
        <span className="text-xs text-gray-500">
          {new Date(r.created_at).toLocaleString("en-GB")}
        </span>
      ),
    },
    {
      key: "actions",
      label: "Actions",
      sortable: false,
      render: (r) => (
        <button
          onClick={() => onReview(r)}
          className="inline-flex items-center gap-1.5 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs font-medium text-gray-700 bg-white hover:bg-gray-50 transition shadow-sm"
        >
          <Eye size={13} />
          {r.status === "REQUESTED" ? "Review" : "View"}
        </button>
      ),
    },
  ];
}
