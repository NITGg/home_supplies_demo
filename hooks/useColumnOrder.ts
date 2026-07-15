"use client";
import { useState, useEffect } from "react";

/**
 * Persists user-defined column order in localStorage.
 * - Hydrates from storage on first render (SSR-safe)
 * - New keys added to defaultOrder since the last visit are appended at the end
 * - Removed keys are silently dropped
 */
export function useColumnOrder(storageKey: string, defaultOrder: readonly string[]) {
  const [order, setOrder] = useState<string[]>(() => {
    if (typeof window === "undefined") return [...defaultOrder];
    try {
      const stored = localStorage.getItem(storageKey);
      if (stored) {
        const parsed: string[] = JSON.parse(stored);
        // Keep valid stored keys in their saved order
        const valid = parsed.filter((k) => (defaultOrder as readonly string[]).includes(k));
        // Append any new keys not yet stored
        const missing = [...defaultOrder].filter((k) => !valid.includes(k));
        return [...valid, ...missing];
      }
    } catch {}
    return [...defaultOrder];
  });

  useEffect(() => {
    try {
      localStorage.setItem(storageKey, JSON.stringify(order));
    } catch {}
  }, [storageKey, order]);

  return [order, setOrder] as const;
}
