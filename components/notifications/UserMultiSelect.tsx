"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { fetchUsers, type User } from "@/lib/users";
import { Search, X, Check, ChevronDown, Loader2 } from "lucide-react";

interface UserMultiSelectProps {
  value: number[];
  onChange: (ids: number[]) => void;
  placeholder?: string;
}

/**
 * Searchable dropdown to pick one or more users (id – name) for the
 * "Specific Users" notification recipient type. Fetches the user list once
 * (id + name only) and filters locally by id or name.
 */
export default function UserMultiSelect({ value, onChange, placeholder }: UserMultiSelectProps) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const containerRef = useRef<HTMLDivElement>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["notif-users"],
    // Mirror the users page fetch — newest first, large page to cover all users.
    queryFn: () => fetchUsers({ limit: 1000, sort: "-created_at" }),
    staleTime: 5 * 60 * 1000,
  });
  const users: User[] = data?.users ?? [];

  // Close on outside click
  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  const selectedSet = useMemo(() => new Set(value), [value]);
  const userById = useMemo(() => {
    const m = new Map<number, User>();
    users.forEach((u) => m.set(u.id, u));
    return m;
  }, [users]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (u) => String(u.id).includes(q) || u.full_name.toLowerCase().includes(q),
    );
  }, [users, search]);

  function toggle(id: number) {
    if (selectedSet.has(id)) onChange(value.filter((v) => v !== id));
    else onChange([...value, id]);
  }

  return (
    <div ref={containerRef} className="relative">
      {/* Control */}
      <div
        onClick={() => setOpen(true)}
        className="min-h-[42px] w-full border border-gray-300 rounded-xl px-2 py-1.5 flex flex-wrap items-center gap-1.5 cursor-text focus-within:ring-2 focus-within:ring-indigo-500 transition bg-white"
      >
        {value.map((id) => {
          const u = userById.get(id);
          return (
            <span
              key={id}
              className="inline-flex items-center gap-1 bg-indigo-50 text-indigo-700 border border-indigo-100 rounded-lg pl-2 pr-1 py-0.5 text-xs font-medium"
            >
              <span className="text-indigo-400">#{id}</span>
              {u ? u.full_name : ""}
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  toggle(id);
                }}
                className="hover:bg-indigo-100 rounded p-0.5 text-indigo-500"
              >
                <X size={12} />
              </button>
            </span>
          );
        })}
        <div className="flex items-center gap-1 flex-1 min-w-[120px]">
          <Search size={14} className="text-gray-400 shrink-0" />
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setOpen(true);
            }}
            onFocus={() => setOpen(true)}
            placeholder={value.length === 0 ? (placeholder ?? "Search by id or name…") : ""}
            className="flex-1 min-w-0 text-sm outline-none bg-transparent text-gray-900 placeholder:text-gray-400 py-0.5"
          />
        </div>
        <ChevronDown
          size={16}
          className={`text-gray-400 shrink-0 transition ${open ? "rotate-180" : ""}`}
        />
      </div>

      {/* Dropdown */}
      {open && (
        <div className="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-xl shadow-lg max-h-64 overflow-auto">
          {isLoading ? (
            <div className="flex items-center gap-2 px-3 py-4 text-sm text-gray-500">
              <Loader2 size={14} className="animate-spin" /> Loading users…
            </div>
          ) : filtered.length === 0 ? (
            <div className="px-3 py-4 text-sm text-gray-500 text-center">No users found</div>
          ) : (
            filtered.slice(0, 200).map((u) => {
              const isSelected = selectedSet.has(u.id);
              return (
                <button
                  key={u.id}
                  type="button"
                  onClick={() => toggle(u.id)}
                  className={`w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-indigo-50 transition ${
                    isSelected ? "bg-indigo-50/60" : ""
                  }`}
                >
                  <span
                    className={`w-4 h-4 rounded border flex items-center justify-center shrink-0 ${
                      isSelected ? "bg-indigo-600 border-indigo-600 text-white" : "border-gray-300"
                    }`}
                  >
                    {isSelected && <Check size={11} />}
                  </span>
                  <span className="text-gray-400 tabular-nums">#{u.id}</span>
                  <span className="text-gray-800 truncate">{u.full_name}</span>
                </button>
              );
            })
          )}
          {!isLoading && filtered.length > 200 && (
            <div className="px-3 py-2 text-xs text-gray-400 text-center border-t">
              Showing first 200 of {filtered.length}. Keep typing to narrow down.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
