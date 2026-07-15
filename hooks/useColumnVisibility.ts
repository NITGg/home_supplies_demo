"use client";
import { useState, useEffect } from "react";

/**
 * Manages which columns are visible for a given table.
 * Persists the user's choice to localStorage so it survives page refreshes.
 *
 * @param storageKey  - unique key per table, e.g. "cols:cancellation-reasons"
 * @param defaultKeys - the full list of column keys that should be visible by default
 *
 * Usage:
 *   const { visible, setVisible } = useColumnVisibility(
 *     "cols:cancellation-reasons",
 *     ["id", "reason_en", "reason_ar", "role_id", "created_at", "updated_at", "actions"]
 *   );
 *   const shownColumns = columns.filter(c => visible.includes(c.key));
 */
/**
 * @param storageKey   - unique key per table, e.g. "cols:orders"
 * @param defaultKeys  - columns visible by default on first visit
 * @param allKeys      - every possible column key (superset of defaultKeys).
 *                       If omitted, defaults to defaultKeys (backward-compatible).
 */
export function useColumnVisibility(
  storageKey: string,
  defaultKeys: string[],
  allKeys?: string[],
) {
  const universe = allKeys ?? defaultKeys;
  const [visible, setVisibleState] = useState<string[]>(defaultKeys);
  const [hydrated, setHydrated] = useState(false);

  // Load from localStorage after mount (avoids SSR mismatch)
  useEffect(() => {
    try {
      const raw = localStorage.getItem(storageKey);
      if (raw) {
        const parsed: unknown = JSON.parse(raw);
        if (Array.isArray(parsed) && parsed.length > 0) {
          // Keep keys that still exist in the universe (handles schema changes)
          const valid = (parsed as string[]).filter(k => universe.includes(k));
          // Append any newly-added default keys not yet in localStorage
          const newlyAdded = defaultKeys.filter(k => !valid.includes(k));
          const merged = [...valid, ...newlyAdded];
          if (merged.length > 0) setVisibleState(merged);
        }
      }
    } catch { /* ignore */ }
    setHydrated(true);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storageKey]);

  function setVisible(keys: string[]) {
    // Preserve universe order so columns don't jump around
    const ordered = universe.filter(k => keys.includes(k));
    setVisibleState(ordered);
    try { localStorage.setItem(storageKey, JSON.stringify(ordered)); } catch { /* ignore */ }
  }

  return { visible, setVisible, hydrated };
}
