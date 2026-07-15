export type SortDirection = "asc" | "desc" | null;

export interface SortConfig {
  field: string;
  direction: SortDirection;
}

// Helper function to build sort string for API
export function buildSortString(sortConfig: SortConfig | null): string {
  if (!sortConfig || !sortConfig.direction) {
    return "id"; // Default sort by id ascending
  }
  return sortConfig.direction === "desc"
    ? `-${sortConfig.field}`
    : sortConfig.field;
}

// Helper function to parse sort string from URL/API
export function parseSortString(sortString: string): SortConfig | null {
  if (!sortString) return null;

  const parts = sortString.split(",").filter(Boolean);
  if (parts.length === 0) return null;

  const firstSort = parts[0];
  const direction: SortDirection = firstSort.startsWith("-") ? "desc" : "asc";
  const field = firstSort.startsWith("-") ? firstSort.slice(1) : firstSort;

  return { field, direction };
}
