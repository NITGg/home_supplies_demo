import { User } from "./user";

export const LOG_SERVICES = ["ADMIN_CUSTOMER", "COURIER", "SUPPLIER"] as const;

export type LogService = (typeof LOG_SERVICES)[number];

export type NumFilter = number | "";

export type LogSortField =
  | "created_at"
  | "method"
  | "path"
  | "status_code"
  | "duration"
  | "user_id"
  | "ip"
  | "service";

export type SortDir = "asc" | "desc";

export interface LogFilters {
  method: string;
  statusMin: NumFilter;
  statusMax: NumFilter;
  durationMin: NumFilter;
  durationMax: NumFilter;
  userId: NumFilter;
  createdFrom: string;
  createdFromTime: string;
  createdTo: string;
  createdToTime: string;
  sortField: LogSortField | "";
  sortDir: SortDir;
  service: LogService | "";
}

export const INITIAL_FILTERS: LogFilters = {
  method: "",
  statusMin: "",
  statusMax: "",
  durationMin: "",
  durationMax: "",
  userId: "",
  createdFrom: "",
  createdFromTime: "",
  createdTo: "",
  createdToTime: "",
  sortField: "",
  sortDir: "desc", // default: newest first
  service: "",
};
export interface LogEntry {
  id: number;
  method: string;
  path: string;
  status_code: number;
  duration: number;
  user_id?: number | null;
  user?: Pick<User, "id" | "full_name" | "email" | "phone"> | null;
  ip?: string | null;
  body?: any;
  query?: any;
  created_at: string;
  service: LogService;
}

export interface UseLogsOptions {
  page: number;
  limit: number;
  search?: string;
  method?: string;
  statusMin?: number | "";
  statusMax?: number | "";
  durationMin?: number | "";
  durationMax?: number | "";
  userId?: number | ""; // ← add
  createdFrom?: string;
  createdTo?: string;
  createdFromTime?: string;
  createdToTime?: string;
  sortField?: LogSortField | "";
  sortDir?: SortDir;
  service: LogService | "";
}

export interface LogsResponse {
  logs: LogEntry[];
  totalLogs: number;
  totalPages: number;
}
