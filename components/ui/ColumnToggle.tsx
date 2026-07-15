"use client";
import { useState, useRef, useEffect } from "react";
import { Columns3, Check, Eye, EyeOff } from "lucide-react";

export interface ColumnOption {
  key: string;
  label: string;
  /** Column that can never be hidden (e.g. "actions") */
  alwaysVisible?: boolean;
}

interface Props {
  columns: ColumnOption[];
  visible: string[];
  onChange: (keys: string[]) => void;
  /** Label on the toggle button. Defaults to "Columns" */
  label?: string;
}

/**
 * Dropdown that lets the user show / hide individual table columns.
 * Drop it as a child of <TableToolbar> or anywhere in the toolbar area.
 *
 * Usage:
 *   <ColumnToggle
 *     columns={[
 *       { key: "id",         label: "ID" },
 *       { key: "name",       label: "Name" },
 *       { key: "created_at", label: "Created At" },
 *       { key: "actions",    label: "Actions", alwaysVisible: true },
 *     ]}
 *     visible={visible}
 *     onChange={setVisible}
 *   />
 */
export function ColumnToggle({ columns, visible, onChange, label = "Columns" }: Props) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close panel when clicking outside
  useEffect(() => {
    function onMouseDown(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onMouseDown);
    return () => document.removeEventListener("mousedown", onMouseDown);
  }, []);

  function toggle(key: string) {
    const col = columns.find(c => c.key === key);
    if (col?.alwaysVisible) return;

    if (visible.includes(key)) {
      // Don't hide if it's the only remaining non-locked column
      const hideable = visible.filter(k => !columns.find(c => c.key === k)?.alwaysVisible);
      if (hideable.length <= 1) return;
      onChange(visible.filter(k => k !== key));
    } else {
      // Re-insert at the position it had in the original columns list
      const ordered = columns.map(c => c.key).filter(k => visible.includes(k) || k === key);
      onChange(ordered);
    }
  }

  function showAll() {
    onChange(columns.map(c => c.key));
  }

  const hiddenCount = columns.filter(c => !c.alwaysVisible && !visible.includes(c.key)).length;

  return (
    <div ref={ref} className="relative">
      {/* Toggle button */}
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="flex items-center gap-2 px-3 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition"
      >
        <Columns3 size={15} className="text-gray-400" />
        {label}
        {hiddenCount > 0 && (
          <span className="inline-flex items-center justify-center w-4 h-4 rounded-full bg-indigo-600 text-white text-[10px] font-bold">
            {hiddenCount}
          </span>
        )}
      </button>

      {/* Dropdown panel — always LTR internally so layout is consistent */}
      {open && (
        <div
          dir="ltr"
          className="absolute left-0 top-full mt-2 z-[9999] bg-white rounded-2xl shadow-xl border border-gray-100 py-2 min-w-[210px]"
        >
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-1.5 mb-1 border-b border-gray-50">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Columns</p>
            {hiddenCount > 0 && (
              <button
                type="button"
                onClick={showAll}
                className="text-xs text-indigo-600 hover:underline"
              >
                Show all
              </button>
            )}
          </div>

          {/* Column rows */}
          {columns.map(col => {
            const isVisible = visible.includes(col.key);
            const isLocked = !!col.alwaysVisible;
            return (
              <button
                key={col.key}
                type="button"
                onClick={() => toggle(col.key)}
                disabled={isLocked}
                className={`flex items-center gap-3 w-full px-4 py-2 text-sm text-left transition
                  ${isLocked ? "opacity-40 cursor-default" : "hover:bg-gray-50 cursor-pointer"}`}
              >
                {/* Checkbox */}
                <span
                  className={`flex-shrink-0 w-4 h-4 rounded border flex items-center justify-center transition
                    ${isVisible ? "bg-indigo-600 border-indigo-600" : "border-gray-300 bg-white"}`}
                >
                  {isVisible && <Check size={10} className="text-white" strokeWidth={3} />}
                </span>

                {/* Label */}
                <span className={isVisible ? "text-gray-800" : "text-gray-400"}>{col.label}</span>

                {/* Eye indicator */}
                <span className="ml-auto text-gray-300">
                  {!isLocked && (isVisible
                    ? <Eye size={13} className="text-indigo-400" />
                    : <EyeOff size={13} />)}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
