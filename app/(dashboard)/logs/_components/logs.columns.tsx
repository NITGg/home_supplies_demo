import type { Column } from "@/components/ui/DataTable";
import type { LogEntry, LogSortField } from "@/types/logs.types";
import {
  getStatusColor,
  getMethodColor,
  formatLogUser,
  getServiceColor,
} from "@/lib/logs.helpers";
import Link from "next/link";
import { Eye } from "lucide-react";

// maps DataTable column key → backend sort field
export const LOG_SORT_FIELD_MAP: Partial<Record<string, LogSortField>> = {
  created_at: "created_at",
  method: "method",
  path: "path",
  status: "status_code",
  duration: "duration",
  user_id: "user_id",
  ip: "ip",
  service: "service",
};

export function buildLogColumns(): Column<LogEntry>[] {
  return [
    {
      key: "created_at",
      label: "Time",
      sortable: true,
      getValue: (l) => l.created_at,
      render: (l) => {
        const d = new Date(l.created_at);
        const date = d.toLocaleDateString(undefined, {
          month: "short",
          day: "numeric",
          year: "numeric",
        });
        const time = d.toLocaleTimeString(undefined, {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        });
        return (
          <span className="text-xs text-gray-500 tabular-nums whitespace-nowrap">
            <span className="text-gray-400">{date}</span> {time}
          </span>
        );
      },
    },
    {
      key: "service",
      label: "Service",
      sortable: true,
      getValue: (l) => l.service,
      render: (l) => (
        <span
          className={`inline-block text-xs font-semibold px-2 py-0.5 rounded ${getServiceColor(l.service)}`}
        >
          {l.service}
        </span>
      ),
    },
    {
      key: "method",
      label: "Method",
      sortable: true,
      getValue: (l) => l.method,
      render: (l) => (
        <span
          className={`inline-block font-mono text-xs font-bold px-2 py-0.5 rounded ${getMethodColor(l.method)}`}
        >
          {l.method}
        </span>
      ),
    },
    {
      key: "path",
      label: "Path",
      sortable: true,
      getValue: (l) => l.path,
      render: (l) => (
        <span className="text-sm font-mono text-gray-700">{l.path}</span>
      ),
    },
    {
      key: "status",
      label: "Status",
      sortable: true,
      getValue: (l) => l.status_code,
      render: (l) => (
        <span
          className={`inline-block text-xs font-bold px-2 py-0.5 rounded ${getStatusColor(l.status_code)}`}
        >
          {l.status_code}
        </span>
      ),
    },
    {
      key: "duration",
      label: "Duration",
      sortable: true,
      getValue: (l) => l.duration,
      render: (l) => {
        const isSlow = l.duration > 1000;
        const cls = isSlow ? "text-red-500 font-semibold" : "text-gray-500";
        return (
          <span className={`text-xs tabular-nums ${cls}`}>{l.duration}ms</span>
        );
      },
    },
    {
      key: "user_id",
      sortable: true,
      label: "User",
      render: (l) => (
        <span className="text-xs text-gray-400">{formatLogUser(l)}</span>
      ),
    },
    {
      key: "ip",
      sortable: true,
      label: "IP",
      render: (l) => (
        <span className="text-xs font-mono text-gray-400">{l.ip ?? "—"}</span>
      ),
    },
    {
  key: "actions",
  label: "Actions",
  render: (l) => (
    <Link
      href={`/logs/${l.id}`}
      className="p-2 hover:bg-gray-100 rounded-lg inline-block text-indigo-600 transition"
    >
      <Eye size={16} />
    </Link>
  ),
},
  ];
}
