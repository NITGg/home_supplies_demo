// ── color helpers ─────────────────────────────────────────────────────────────

import {
  INITIAL_FILTERS,
  LogEntry,
  LogFilters,
  LogService,
  NumFilter,
  UseLogsOptions,
} from "@/types/logs.types";

export function getStatusColor(status: number): string {
  if (status >= 500) return "text-red-600 bg-red-50";
  if (status >= 400) return "text-orange-600 bg-orange-50";
  if (status >= 200) return "text-green-600 bg-green-50";
  return "text-gray-600 bg-gray-50";
}

const METHOD_COLORS: Record<string, string> = {
  GET: "text-blue-600 bg-blue-50",
  POST: "text-green-600 bg-green-50",
  PUT: "text-yellow-600 bg-yellow-50",
  PATCH: "text-yellow-600 bg-yellow-50",
  DELETE: "text-red-600 bg-red-50",
};

export function getMethodColor(method: string): string {
  return METHOD_COLORS[method] ?? "text-gray-600 bg-gray-50";
}

// ── user display ──────────────────────────────────────────────────────────────

export function formatLogUser(log: LogEntry): string {
  if (log.user) return `${log.user.full_name} (#${log.user.id})`;
  if (log.user_id) return `#${log.user_id}`;
  return "—";
}

// ── datetime helpers ──────────────────────────────────────────────────────────

export function buildDateTimeParam(
  date: string,
  time: string,
  endOfDay = false,
): string {
  if (!date) return "";
  if (time) return `${date}T${time}:00`;
  return endOfDay ? `${date}T23:59:59` : `${date}T00:00:00`;
}

// ── chips ─────────────────────────────────────────────────────────────────────

export interface FilterChip {
  label: string;
  key: keyof LogFilters;
}

export function buildLogChips(
  filters: LogFilters,
  getUserName: (id: NumFilter) => string | undefined,
): FilterChip[] {
  const chips: FilterChip[] = [];

  if (filters.method)
    chips.push({ label: `method: ${filters.method}`, key: "method" });

  if (filters.statusMin !== "")
    chips.push({ label: `status ≥ ${filters.statusMin}`, key: "statusMin" });

  if (filters.statusMax !== "")
    chips.push({ label: `status ≤ ${filters.statusMax}`, key: "statusMax" });

  if (filters.durationMin !== "")
    chips.push({
      label: `duration ≥ ${filters.durationMin}ms`,
      key: "durationMin",
    });

  if (filters.durationMax !== "")
    chips.push({
      label: `duration ≤ ${filters.durationMax}ms`,
      key: "durationMax",
    });

  if (filters.userId !== "") {
    const name = getUserName(filters.userId);
    const display = name ?? `#${filters.userId}`;
    chips.push({ label: `user: ${display}`, key: "userId" });
  }

  if (filters.createdFrom) {
    const timeLabel = filters.createdFromTime
      ? ` ${filters.createdFromTime}`
      : "";
    chips.push({
      label: `from: ${filters.createdFrom}${timeLabel}`,
      key: "createdFrom",
    });
  }

  if (filters.createdTo) {
    const timeLabel = filters.createdToTime ? ` ${filters.createdToTime}` : "";
    chips.push({
      label: `to: ${filters.createdTo}${timeLabel}`,
      key: "createdTo",
    });
  }

  if (filters.service) {
    chips.push({
      label: `service: ${filters.service}`,
      key: "service",
    });
  }

  if (filters.sortField && filters.sortField !== INITIAL_FILTERS.sortField) {
    const dirLabel = filters.sortDir === "desc" ? "↓" : "↑";
    // You might want a mapping to make field names pretty (e.g., status_code -> Status)
    const fieldLabel = filters.sortField.replace("_", " ");

    chips.push({
      label: `sort: ${fieldLabel} ${dirLabel}`,
      key: "sortField", // Clicking 'X' will trigger reset of sortField
    });
  }

  return chips;
}

function buildDate(date?: string, time?: string, end = false) {
  if (!date) return undefined;

  const defaultTime = end ? "23:59:59" : "00:00:00";

  return time ? `${date}T${time}:00` : `${date}T${defaultTime}`;
}

export function buildLogParams(
  props: UseLogsOptions,
): Record<string, string | number> {
  const params: Record<string, string | number> = {
    page: props.page,
    limit: props.limit,
  };

  const directMappings = [
    ["search", "keyword"],
    ["method", "method"],
    ["service", "service"],
  ] as const;

  for (const [propKey, paramKey] of directMappings) {
    const value = props[propKey];

    if (value) {
      params[paramKey] = value;
    }
  }

  const rangeMappings = [
    ["statusMin", "status_code[gte]"],
    ["statusMax", "status_code[lte]"],
    ["durationMin", "duration[gte]"],
    ["durationMax", "duration[lte]"],
    ["userId", "user_id"],
  ] as const;

  for (const [propKey, paramKey] of rangeMappings) {
    const value = props[propKey];

    if (value !== "" && value !== undefined) {
      params[paramKey] = value;
    }
  }

  const createdFrom = buildDate(props.createdFrom, props.createdFromTime);

  if (createdFrom) {
    params["created_at[gte]"] = createdFrom;
  }

  const createdTo = buildDate(props.createdTo, props.createdToTime, true);

  if (createdTo) {
    params["created_at[lte]"] = createdTo;
  }
  if (props.sortField) {
    params.sort =
      props.sortDir === "desc" ? `-${props.sortField}` : props.sortField;
  }

  return params;
}

const SERVICE_COLORS: Record<LogService, string> = {
  ADMIN_CUSTOMER: "text-indigo-700 bg-indigo-50",
  COURIER: "text-orange-700 bg-orange-50",
  SUPPLIER: "text-emerald-700 bg-emerald-50",
};

export function getServiceColor(service: LogService): string {
  return SERVICE_COLORS[service];
}
