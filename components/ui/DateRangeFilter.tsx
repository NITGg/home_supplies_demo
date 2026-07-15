"use client";
import { CalendarDays, X } from "lucide-react";

interface Props {
  /** Label shown above the two date inputs, e.g. "Created At" */
  label: string;
  from: string;
  to: string;
  onFromChange: (v: string) => void;
  onToChange: (v: string) => void;
  /** Extra Tailwind classes for the wrapper */
  className?: string;
}

/**
 * Reusable date-range picker (from / to).
 * Drop it as a child of <TableToolbar> or anywhere else.
 *
 * Usage:
 *   <DateRangeFilter
 *     label="Created At"
 *     from={createdFrom}  to={createdTo}
 *     onFromChange={v => { setCreatedFrom(v); setPage(1); }}
 *     onToChange={v  => { setCreatedTo(v);   setPage(1); }}
 *   />
 */
export function DateRangeFilter({
  label,
  from,
  to,
  onFromChange,
  onToChange,
  className = "",
}: Props) {
  const hasValue = from || to;

  return (
    <div className={`space-y-2 ${className}`}>
      {/* Label + icon */}
      <div className="flex items-center gap-1 text-xs text-gray-500 whitespace-nowrap">
        <CalendarDays size={13} className="text-gray-400" />
        {label}
      </div>

      {/* Date inputs in grid */}
      <div className="grid grid-cols-2 gap-3">
        {/* From */}
        <div>
          <label className="block text-xs text-gray-600 mb-1">From</label>
          <input
            type="date"
            value={from}
            max={to || undefined}
            onChange={(e) => onFromChange(e.target.value)}
            className="border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 text-gray-700 bg-white w-full"
          />
        </div>

        {/* To */}
        <div>
          <label className="block text-xs text-gray-600 mb-1">To</label>
          <input
            type="date"
            value={to}
            min={from || undefined}
            onChange={(e) => onToChange(e.target.value)}
            className="border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 text-gray-700 bg-white w-full"
          />
        </div>
      </div>

      {/* Clear button — only shown when either date is set */}
      {hasValue && (
        <div className="flex justify-center">
          <button
            type="button"
            onClick={() => {
              onFromChange("");
              onToChange("");
            }}
            className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition"
            title="Clear dates"
          >
            <X size={14} />
          </button>
        </div>
      )}
    </div>
  );
}
