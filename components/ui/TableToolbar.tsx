"use client";
import { useState, useEffect } from "react";
import { Search } from "lucide-react";

interface Props {
  total: number;
  totalLabel?: string;
  search?: string;
  onSearch?: (v: string) => void;
  searchPlaceholder?: string;
  children?: React.ReactNode;
  action?: React.ReactNode;
  debounce?: number;
}

export function TableToolbar({
  total,
  totalLabel = "item",
  search = "",
  onSearch,
  searchPlaceholder = "Search…",
  children,
  action,
  debounce = 350,
}: Props) {
  const [local, setLocal] = useState(search);

  useEffect(() => { setLocal(search); }, [search]);

  useEffect(() => {
    if (!onSearch) return;
    const t = setTimeout(() => { if (local !== search) onSearch(local); }, debounce);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [local, debounce, onSearch]);

  return (
    <div className="flex flex-wrap items-center gap-3">
      {/* Search */}
      {onSearch && (
        <div className="relative flex-1 min-w-[220px]">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
          <input
            value={local}
            onChange={e => setLocal(e.target.value)}
            placeholder={searchPlaceholder}
            className="w-full pl-9 pr-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 outline-none"
          />
        </div>
      )}

      {/* Extra filters */}
      {children}

      {/* Action button (right side) */}
      {action}

      {/* Count */}
      <span className="text-sm text-gray-500 whitespace-nowrap ml-auto">
        {total.toLocaleString()} {totalLabel}{total !== 1 ? "s" : ""}
      </span>
    </div>
  );
}
