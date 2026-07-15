"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useLogs } from "@/hooks/use-logs";
import { DataTable } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { ScrollText, RefreshCw, Wifi, X } from "lucide-react";
import { fetchAllUserIds } from "@/lib/users";
import { INITIAL_FILTERS, LogFilters } from "@/types/logs.types";
import { buildLogChips } from "@/lib/logs.helpers";
import {
  buildLogColumns,
  LOG_SORT_FIELD_MAP,
} from "./_components/logs.columns";
import { LogsFilterBar } from "./_components/logs.filters";

const ALL_COLUMN_KEYS = [
  "created_at",
  "service",
  "method",
  "path",
  "status",
  "duration",
  "user_id",
  "ip",
  "actions",
] as const;

export default function LogsPage() {
  const [page, setPage] = useState(1);
  const [limit] = useState(50);
  const [search, setSearch] = useState("");
  const [filters, setFilters] = useState<LogFilters>(INITIAL_FILTERS);

  const resetPage = () => setPage(1);

  const setFilter = <K extends keyof LogFilters>(
    key: K,
    value: LogFilters[K],
  ) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    resetPage();
  };

  const handleSortChange = (columnKey: string, dir: "asc" | "desc") => {
    const field = LOG_SORT_FIELD_MAP[columnKey];
    if (!field) return;
    // if same field, just flip dir; otherwise switch field and reset to desc
    setFilters((prev) => ({
      ...prev,
      sortField: field,
      sortDir: dir,
    }));
    resetPage();
  };

  const activeSortColumnKey =
    Object.entries(LOG_SORT_FIELD_MAP).find(
      ([, field]) => field === filters.sortField,
    )?.[0] ?? "";
  const clearAll = () => {
    setFilters(INITIAL_FILTERS);
    resetPage();
  };

  const { visible, setVisible } = useColumnVisibility("cols:logs", [
    ...ALL_COLUMN_KEYS,
  ]);

  const { data: allUserIds = [] } = useQuery({
    queryKey: ["user-ids"],
    queryFn: fetchAllUserIds,
  });

  const { logs, total, totalPages, liveLogs, isLoading, isFetching, refetch } =
    useLogs({ page, limit, search, ...filters });

  const getUserName = (id: typeof filters.userId) =>
    allUserIds.find((u) => u.id === id)?.full_name;

  const chips = buildLogChips(filters, getUserName);

  const allColumns = buildLogColumns();
  const columns = allColumns.filter((c) => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map((c) => ({
    key: c.key,
    label: c.label,
  }));

  return (
    <div className="p-6 space-y-6">
      {/* ── header ── */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <ScrollText size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">System Logs</h1>
            {liveLogs.length > 0 && (
              <span className="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">
                <Wifi size={10} /> {liveLogs.length} live
              </span>
            )}
          </div>
          <p className="text-sm text-gray-500">
            Live request log — new entries appear automatically
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

      {/* ── toolbar ── */}
      <TableToolbar
        total={total}
        totalLabel="log"
        search={search}
        onSearch={(v) => {
          setSearch(v);
          resetPage();
        }}
        searchPlaceholder="Search by path, IP, user..."
        action={
          <ColumnToggle
            columns={columnOptions}
            visible={visible}
            onChange={setVisible}
          />
        }
      >
        <LogsFilterBar
          filters={filters}
          allUserIds={allUserIds}
          setFilter={setFilter}
        />
      </TableToolbar>

      {/* ── active filter chips ── */}
      {chips.length > 0 && (
        <div className="flex flex-wrap items-center gap-2">
          {chips.map((chip) => (
            <button
              key={chip.key}
              onClick={() => setFilter(chip.key, INITIAL_FILTERS[chip.key])}
              className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition"
            >
              {chip.label}
              <X size={10} />
            </button>
          ))}
          <button
            onClick={clearAll}
            className="text-xs text-gray-400 hover:text-gray-600 underline"
          >
            Clear all
          </button>
        </div>
      )}

      <DataTable
        columns={columns}
        rows={logs}
        keyExtractor={(l) =>
          l.id?.toString() ?? `${l.created_at}-${l.path}-${Math.random()}`
        }
        isLoading={isLoading}
        emptyText="No logs yet"
        emptyIcon={<ScrollText size={36} className="text-gray-300" />}
        serverSortKey={activeSortColumnKey}
        serverSortDir={filters.sortDir}
        onSortChange={handleSortChange}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={total}
        limit={limit}
        onPageChange={setPage}
      />
    </div>
  );
}
