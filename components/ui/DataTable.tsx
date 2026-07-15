"use client";
import { useState, useMemo } from "react";
import { ChevronUp, ChevronDown, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

export interface Column<T> {
  key: string;
  label: string;
  sortable?: boolean;
  getValue?: (row: T) => string | number | Date | null | undefined;
  render: (row: T) => React.ReactNode;
  headerClassName?: string;
  className?: string;
  align?: "left" | "right" | "center";
}

interface Props<T> {
  columns: Column<T>[];
  rows: T[];
  keyExtractor: (row: T) => string | number;
  isLoading?: boolean;
  emptyText?: string;
  emptyIcon?: React.ReactNode;
  serverSortKey?: string;
  serverSortDir?: "asc" | "desc";
  onSortChange?: (key: string, dir: "asc" | "desc") => void;
  onRowClick?: (row: T) => void;
}

function SortIcon({ active, dir }: { active: boolean; dir: "asc" | "desc" }) {
  if (!active)
    return <ChevronsUpDown size={13} className="opacity-30 shrink-0" />;
  return dir === "asc" ? (
    <ChevronUp size={13} className="text-indigo-600 shrink-0" />
  ) : (
    <ChevronDown size={13} className="text-indigo-600 shrink-0" />
  );
}

export function DataTable<T>({
  columns,
  rows,
  keyExtractor,
  isLoading,
  emptyText,
  emptyIcon,
  serverSortKey,
  serverSortDir = "asc",
  onSortChange,
  onRowClick,
}: Props<T>) {
  const [localSortKey, setLocalSortKey] = useState<string | null>(null);
  const [localSortDir, setLocalSortDir] = useState<"asc" | "desc">("asc");

  const isServerSort = !!onSortChange;

  // which key/dir the header icons reflect
  const activeSortKey = isServerSort ? (serverSortKey ?? null) : localSortKey;
  const activeSortDir = isServerSort ? serverSortDir : localSortDir;

  function handleHeaderClick(key: string) {
    if (isServerSort) {
      const nextDir =
        serverSortKey === key && serverSortDir === "asc" ? "desc" : "asc";
      onSortChange(key, nextDir);
    } else {
      if (localSortKey === key) {
        setLocalSortDir((d) => (d === "asc" ? "desc" : "asc"));
      } else {
        setLocalSortKey(key);
        setLocalSortDir("asc");
      }
    }
  }

  const sorted = useMemo(() => {
    // server sort: backend already sorted — render as-is
    if (isServerSort || !localSortKey) return rows;

    const col = columns.find((c) => c.key === localSortKey);
    if (!col?.getValue) return rows;

    return [...rows].sort((a, b) => {
      const av = col.getValue!(a);
      const bv = col.getValue!(b);
      if (av == null && bv == null) return 0;
      if (av == null) return localSortDir === "asc" ? -1 : 1;
      if (bv == null) return localSortDir === "asc" ? 1 : -1;
      if (av instanceof Date && bv instanceof Date) {
        return localSortDir === "asc"
          ? av.getTime() - bv.getTime()
          : bv.getTime() - av.getTime();
      }
      if (typeof av === "number" && typeof bv === "number") {
        return localSortDir === "asc" ? av - bv : bv - av;
      }
      const as = String(av).toLowerCase();
      const bs = String(bv).toLowerCase();
      if (as < bs) return localSortDir === "asc" ? -1 : 1;
      if (as > bs) return localSortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [rows, localSortKey, localSortDir, columns, isServerSort]);

  const colCount = columns.length;

  return (
    <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50">
              {columns.map((col) => (
                <th
                  key={col.key}
                  className={cn(
                    "px-5 py-3.5 font-semibold text-gray-500 text-xs uppercase tracking-wide select-none",
                    col.align === "right" ? "text-right" : "",
                    col.align === "center" ? "text-center" : "text-left",
                    col.sortable &&
                      "cursor-pointer hover:text-indigo-600 transition-colors",
                    col.headerClassName,
                  )}
                  onClick={
                    col.sortable ? () => handleHeaderClick(col.key) : undefined
                  }
                >
                  <span
                    className={cn(
                      "inline-flex items-center gap-1",
                      col.align === "right" && "justify-end",
                      col.align === "center" && "justify-center",
                    )}
                  >
                    {col.label}
                    {col.sortable && (
                      <SortIcon
                        active={activeSortKey === col.key}
                        dir={activeSortDir}
                      />
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              Array.from({ length: 6 }).map((_, i) => (
                <tr key={i} className="border-b border-gray-50 animate-pulse">
                  {Array.from({ length: colCount }).map((__, j) => (
                    <td key={j} className="px-5 py-4">
                      <div className="h-4 bg-gray-200 rounded w-3/4" />
                    </td>
                  ))}
                </tr>
              ))
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={colCount} className="py-16 text-center">
                  <div className="flex flex-col items-center gap-3">
                    {emptyIcon}
                    <p className="text-gray-400 text-sm">
                      {emptyText ?? "No results found"}
                    </p>
                  </div>
                </td>
              </tr>
            ) : (
              sorted.map((row) => (
                <tr
                  key={keyExtractor(row)}
                  className="border-b border-gray-50 hover:bg-gray-50/60 transition-colors cursor-pointer"
                  onClick={(e) => {
                    if ((e.target as HTMLElement).closest("button, a")) return;
                    onRowClick?.(row);
                  }}
                >
                  {columns.map((col) => (
                    <td
                      key={col.key}
                      className={cn(
                        "px-5 py-4",
                        col.align === "right"
                          ? "text-right"
                          : col.align === "center"
                            ? "text-center"
                            : "text-left",
                        col.className,
                      )}
                    >
                      {col.render(row)}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
