"use client";

import { useState, useEffect, useMemo, ReactNode } from "react";
// import { useTranslation } from "react-i18next";
import axiosInstance from "@/lib/axios";
import { centsToEgp } from "@/utils/money";
import { AxiosError } from "axios";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import { DataTable, SortConfig } from "@/components/ui/data-table";
import { buildSortString } from "@/lib/table-utils";
import { SharedPagination } from "@/components/ui/shared-pagination";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  ChevronDown,
  ChevronRight,
  AlertCircle,
  RefreshCw,
} from "lucide-react";

export interface ColumnDef {
  key: string;
  label: string;
  render?: (value: unknown, row: Record<string, unknown>) => ReactNode;
}

interface DetailsSectionProps {
  title: string;
  endpoint: string;
  columns: ColumnDef[];
  /** If true, the section expects a paginated response with { data, pagination } */
  paginated?: boolean;
  /** Current page (URL-driven) */
  page?: number;
  /** Called when the user changes the page */
  onPageChange?: (page: number) => void;
  /** Additional query parameters for filtering */
  queryParams?: Record<string, string>;
  /** External refresh trigger */
  refreshTrigger?: number;
  /** Children rendered after the table (e.g., action modals) */
  children?: ReactNode;
  /** If the section should render an action column, provide a render function */
  actionColumn?: (row: Record<string, unknown>) => ReactNode;
  /** Whether the section starts expanded (default: true) */
  defaultOpen?: boolean;
  /** Array of filter options configuration */
  filterFields?: {
    name: string;
    label: string;
    type: "text" | "select" | "date" | "number";
    options?: { label: string; value: string }[];
    isDateRange?: boolean;
  }[];
  enableColumnVisibility?: boolean;
}

export function DetailsSection({
  title,
  endpoint,
  columns,
  paginated = true,
  page = 1,
  onPageChange,
  queryParams = {},
  refreshTrigger = 0,
  children,
  actionColumn,
  defaultOpen = true,
  filterFields = [],
  enableColumnVisibility = false,
}: DetailsSectionProps) {
  // const { t } = useTranslation();
  const t = (key: string, fallback: string) => fallback;

  const [isOpen, setIsOpen] = useState(defaultOpen);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [rows, setRows] = useState<any[]>([]);
  const [paginationData, setPaginationData] = useState({
    total: 0,
    total_pages: 1,
    has_next: false,
    has_prev: false,
  });
  const [limit, setLimit] = useState(10);
  const [sortConfig, setSortConfig] = useState<SortConfig>({
    field: "id",
    direction: "asc",
  });
  const [localFilters, setLocalFilters] = useState<Record<string, string>>({});
  const [visibleColumns, setVisibleColumns] = useState<Record<string, boolean>>(
    () => {
      const initial: Record<string, boolean> = {};
      columns.forEach((col) => {
        initial[col.key] = true;
      });
      return initial;
    },
  );

  const handleFilterChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>,
  ) => {
    const { name, value } = e.target;
    setLocalFilters((prev) => ({ ...prev, [name]: value }));
  };

  useEffect(() => {
    if (onPageChange && page > 1) onPageChange(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [localFilters]);

  useEffect(() => {
    if (!isOpen) return;

    let isMounted = true;
    const fetchData = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const params: Record<string, string | number> = {
          ...queryParams,
        };
        // Build a lookup of field types from filterFields config
        const fieldTypeMap: Record<string, string> = {};
        filterFields.forEach((f) => {
          fieldTypeMap[f.name] = f.type;
          if (f.isDateRange) {
            fieldTypeMap[`${f.name}From`] = "date";
            fieldTypeMap[`${f.name}To`] = "date";
          }
        });

        Object.entries(localFilters).forEach(([key, value]) => {
          if (value !== "" && value !== undefined) {
            // Money fields: UI is EGP, backend expects cents
            if (
              [
                "amountFrom",
                "amountTo",
                "held_amountFrom",
                "held_amountTo",
                "balanceFrom",
                "balanceTo",
              ].includes(key)
            ) {
              const numericValue = Number(value);
              if (!isNaN(numericValue)) {
                params[key] = Math.round(numericValue * 100);
              }
              // Skip if not a valid number
            } else if (fieldTypeMap[key] === "number") {
              // Number-type fields (like waived_by, order_id): only send if valid number
              const numericValue = Number(value);
              if (!isNaN(numericValue) && value.trim() !== "") {
                params[key] = numericValue;
              }
              // Skip non-numeric values entirely to avoid backend 401
            } else {
              params[key] = value as string;
            }
          }
        });

        if (paginated) {
          params.page = page;
          params.limit = limit;
          params.sort = buildSortString(sortConfig);
        }

        // Log the API request for debugging — verify correct params (user_id vs wallet_id)
        console.log(`[DetailsSection:${title}] GET ${endpoint}`, params);
        const response = await axiosInstance.get(endpoint, { params });
        if (!isMounted) return;

        console.log(
          `[DetailsSection:${title}] Response status=${response.status}, data keys:`,
          Object.keys(response.data || {}),
        );
        const resData = response.data?.data;
        if (paginated) {
          // Paginated response: { [resourceKey]: [...], pagination: {...} }
          // The array key varies by endpoint (e.g., "wallets", "penalties", "transactions")
          let items: unknown[];
          if (Array.isArray(resData)) {
            items = resData;
          } else if (resData && typeof resData === "object") {
            // Find the first array value in the response object
            const arrayValue = Object.values(resData).find((v) =>
              Array.isArray(v),
            );
            items = (arrayValue as unknown[]) || [];
          } else {
            items = [];
          }
          setRows(items);

          // Pagination may be at response.data.data.pagination or response.data.pagination
          const pagination =
            resData?.pagination || response.data?.pagination || {};
          setPaginationData({
            total: pagination.total || 0,
            total_pages: pagination.total_pages || pagination.totalPages || 1,
            has_next: pagination.has_next ?? pagination.hasNext ?? false,
            has_prev: pagination.has_prev ?? pagination.hasPrev ?? false,
          });
        } else {
          // Single-row response
          const item = Array.isArray(resData)
            ? resData
            : [resData].filter(Boolean);
          setRows(item);
        }
      } catch (err: unknown) {
        if (!isMounted) return;
        const axiosErr = err as AxiosError<{ message: string }>;
        console.error(
          `[DetailsSection:${title}] Error fetching:`,
          axiosErr?.response?.status,
          axiosErr?.response?.data,
        );
        const errorMsg =
          axiosErr?.response?.data?.message ||
          t("failedToLoadData", "Failed to load data");
        setError(errorMsg);
      } finally {
        if (isMounted) setIsLoading(false);
      }
    };

    fetchData();
    return () => {
      isMounted = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    endpoint,
    page,
    limit,
    sortConfig,
    isOpen,
    refreshTrigger,
    JSON.stringify(queryParams),
    JSON.stringify(localFilters),
  ]);

  const allColumns = actionColumn
    ? [...columns, { key: "__actions__", label: t("actions", "Actions") }]
    : columns;

  const handleVisToggle = (key: string, val: boolean) => {
    setVisibleColumns((prev) => ({ ...prev, [key]: val }));
  };

  useEffect(() => {
    const moneyKeys = new Set([
      "amountFrom",
      "amountTo",
      "held_amountFrom",
      "held_amountTo",
      "balanceFrom",
      "balanceTo",
    ]);

    let hasUpdate = false;
    const nextFilters = { ...localFilters };

    Object.entries(queryParams).forEach(([key, value]) => {
      if (!moneyKeys.has(key)) return;
      if (nextFilters[key] !== undefined && nextFilters[key] !== "") return;

      const egp = centsToEgp(value);
      if (egp !== undefined) {
        nextFilters[key] = String(egp);
        hasUpdate = true;
      }
    });

    if (hasUpdate) setLocalFilters(nextFilters);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [JSON.stringify(queryParams)]);

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen} className="space-y-4">
      <div className="bg-card border rounded-lg shadow-sm overflow-hidden">
        <CollapsibleTrigger asChild>
          <button className="w-full px-6 py-4 border-b bg-muted/30 flex items-center justify-between hover:bg-muted/50 transition-colors">
            <h2 className="font-semibold text-lg">{title}</h2>
            <div className="flex items-center gap-2">
              {isLoading && isOpen && (
                <RefreshCw className="h-4 w-4 animate-spin text-muted-foreground" />
              )}
              {isOpen ? (
                <ChevronDown className="h-5 w-5 text-muted-foreground" />
              ) : (
                <ChevronRight className="h-5 w-5 text-muted-foreground" />
              )}
            </div>
          </button>
        </CollapsibleTrigger>

        <CollapsibleContent>
          {(filterFields.length > 0 || enableColumnVisibility) && (
            <div className="p-4 border-b bg-muted/20 flex flex-col sm:flex-row gap-4 items-start sm:items-center">
              {(filterFields.length > 0 || enableColumnVisibility) && (
                <div className="flex flex-wrap gap-3 flex-1 items-center">
                  {filterFields.map((field) => {
                    if (field.isDateRange) {
                      return (
                        <div
                          key={field.name}
                          className="flex flex-col gap-1 w-full sm:w-auto"
                        >
                          <span className="text-[10px] uppercase font-semibold text-muted-foreground ml-1">
                            {field.label}
                          </span>
                          <div className="flex gap-2 items-center">
                            <Input
                              type="date"
                              name={`${field.name}From`}
                              value={localFilters[`${field.name}From`] || ""}
                              onChange={handleFilterChange}
                              className="h-8 text-sm"
                              title={t("from", "From")}
                              placeholder={t("from", "From")}
                            />
                            <span className="text-muted-foreground text-xs">
                              -
                            </span>
                            <Input
                              type="date"
                              name={`${field.name}To`}
                              value={localFilters[`${field.name}To`] || ""}
                              onChange={handleFilterChange}
                              className="h-8 text-sm"
                              title={t("to", "To")}
                              placeholder={t("to", "To")}
                            />
                          </div>
                        </div>
                      );
                    }

                    if (field.type === "select") {
                      return (
                        <select
                          key={field.name}
                          name={field.name}
                          value={localFilters[field.name] || ""}
                          onChange={handleFilterChange}
                          className="h-8 rounded-md border border-input bg-background px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                        >
                          <option value="">
                            {t("all", "All")} {field.label}
                          </option>
                          {field.options?.map((opt) => (
                            <option key={opt.value} value={opt.value}>
                              {opt.label}
                            </option>
                          ))}
                        </select>
                      );
                    }

                    return (
                      <Input
                        key={field.name}
                        type={field.type === "number" ? "number" : "text"}
                        placeholder={field.label}
                        name={field.name}
                        value={localFilters[field.name] || ""}
                        onChange={handleFilterChange}
                        className="h-8 w-[150px] text-sm"
                      />
                    );
                  })}

                  {enableColumnVisibility && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button
                          variant="outline"
                          size="sm"
                          className="flex-shrink-0"
                        >
                          {t("columns", "Columns")}{" "}
                          <ChevronDown className="ml-2 h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent
                        align="end"
                        className="w-[200px] max-h-[300px] overflow-y-auto"
                      >
                        {columns
                          .filter((c) => c.key !== "__actions__")
                          .map((col) => (
                            <DropdownMenuCheckboxItem
                              key={col.key}
                              className="capitalize"
                              checked={visibleColumns[col.key]}
                              onCheckedChange={(val) =>
                                handleVisToggle(col.key, val === true)
                              }
                            >
                              {col.label}
                            </DropdownMenuCheckboxItem>
                          ))}
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </div>
              )}
            </div>
          )}
          <div className="p-0">
            {error ? (
              <div className="p-6 flex items-center gap-3 text-destructive bg-destructive/10">
                <AlertCircle className="h-5 w-5 flex-shrink-0" />
                <span className="text-sm">{error}</span>
                <Button
                  variant="outline"
                  size="sm"
                  className="ml-auto"
                  onClick={() => setError(null)}
                >
                  {t("retry", "Retry")}
                </Button>
              </div>
            ) : (
              <DataTable<{ id: string | number; [key: string]: unknown }>
                data={rows}
                columns={columns
                  .filter((col) => visibleColumns[col.key] !== false)
                  .map((col) => ({
                    id: col.key,
                    header: col.label,
                    accessorKey: col.key,
                    cell: (row) =>
                      col.render
                        ? col.render(row[col.key], row)
                        : (row[col.key]?.toString() ?? "N/A"),
                  }))}
                isLoading={isLoading}
                limit={limit}
                sortConfig={sortConfig}
                onSort={(newSortConfig) => {
                  if (newSortConfig) setSortConfig(newSortConfig);
                }}
                emptyMessage={t("noRecordsFound", "No records found")}
                actionsColumn={
                  actionColumn
                    ? {
                        header: t("actions", "Actions"),
                        cell: (row) => actionColumn(row),
                      }
                    : undefined
                }
              />
            )}

            {paginated && paginationData.total_pages > 1 && onPageChange && (
              <div className="px-6 pb-4">
                <SharedPagination
                  page={page}
                  totalPages={paginationData.total_pages}
                  hasNext={paginationData.has_next}
                  hasPrev={paginationData.has_prev}
                  onPageChange={onPageChange}
                  totalRecords={paginationData.total}
                  pageRecordsCount={rows.length}
                  limit={limit}
                  onLimitChange={(newLimit) => {
                    setLimit(newLimit);
                    onPageChange(1);
                  }}
                />
              </div>
            )}
          </div>
          {children}
        </CollapsibleContent>
      </div>
    </Collapsible>
  );
}
