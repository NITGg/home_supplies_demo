"use client";

import { useState, useEffect } from "react";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

// Commented out the real translation package
// import { useTranslation } from "react-i18next";

/**
 * A simple mock translation function that returns the fallback
 * or the key if no fallback is provided.
 */
const t = (key: string, fallbackOrOptions?: string | any, options?: any) => {
  if (typeof fallbackOrOptions === "string") return fallbackOrOptions;

  // Handle interpolation for things like "{{start}}-{{end}} of {{total}}"
  if (key === "recordsRange" && options) {
    return `${options.start}-${options.end} of ${options.total}`;
  }

  return key;
};

interface SharedPaginationProps {
  page: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
  onPageChange: (page: number) => void;
  totalRecords?: number;
  pageRecordsCount?: number;
  limit: number;
  onLimitChange: (limit: number) => void;
  limitOptions?: number[];
}

export function SharedPagination({
  page,
  totalPages,
  hasNext,
  hasPrev,
  onPageChange,
  totalRecords,
  limit,
  onLimitChange,
  limitOptions = [10, 20, 50, 100],
}: SharedPaginationProps) {
  // const { t } = useTranslation(); // Disabled hook
  const [inputPage, setInputPage] = useState(page.toString());

  // Keep input synced if page changes externally
  useEffect(() => {
    setInputPage(page.toString());
  }, [page]);

  const handleJumpToPage = (e: React.FormEvent) => {
    e.preventDefault();
    const targetPage = parseInt(inputPage, 10);
    if (!isNaN(targetPage) && targetPage >= 1 && targetPage <= totalPages) {
      onPageChange(targetPage);
    } else {
      setInputPage(page.toString());
    }
  };

  return (
    <Pagination className="mt-4 flex flex-col items-center justify-between gap-4 sm:flex-row">
      <PaginationContent className="order-1 sm:order-2">
        <PaginationItem>
          <PaginationPrevious
            href="#"
            onClick={(e) => {
              e.preventDefault();
              if (hasPrev) onPageChange(page - 1);
            }}
            className={
              !hasPrev ? "pointer-events-none opacity-50" : "cursor-pointer"
            }
          >
            {t("previous", "Previous")}
          </PaginationPrevious>
        </PaginationItem>

        <PaginationItem>
          <div className="flex flex-col gap-1 text-sm text-muted-foreground order-2 sm:order-1">
            <div className="flex items-center gap-2">
              <form
                onSubmit={handleJumpToPage}
                className="flex items-center gap-1"
              >
                <Input
                  type="number"
                  min={1}
                  max={totalPages}
                  className="h-8 w-16 p-1 text-center"
                  value={inputPage}
                  onChange={(e) => setInputPage(e.target.value)}
                  onBlur={handleJumpToPage}
                />
                <span className="mx-1 text-xs">
                  {t("of", "of")} {totalPages}
                </span>
              </form>
            </div>
          </div>
        </PaginationItem>

        <PaginationItem>
          <PaginationNext
            href="#"
            onClick={(e) => {
              e.preventDefault();
              if (hasNext) onPageChange(page + 1);
            }}
            className={
              !hasNext ? "pointer-events-none opacity-50" : "cursor-pointer"
            }
          >
            {t("next", "Next")}
          </PaginationNext>
        </PaginationItem>

        <PaginationItem>
          <div className="flex flex-col items-center gap-1 text-[11px] text-muted-foreground sm:flex-row sm:gap-2">
            <div className="flex items-center gap-1">
              <Select
                value={String(limit)}
                onValueChange={(value) => {
                  const nextLimit = Number(value);
                  if (!Number.isNaN(nextLimit) && nextLimit > 0) {
                    onLimitChange(nextLimit);
                    onPageChange(1);
                  }
                }}
              >
                <SelectTrigger className="h-7 w-[70px] px-2 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {limitOptions.map((option) => (
                    <SelectItem key={option} value={String(option)}>
                      {option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {typeof totalRecords === "number" && totalRecords > 0 && (
              <div className="whitespace-nowrap">
                {t("recordsRange", "{{start}}-{{end}} of {{total}}", {
                  start: (page - 1) * limit + 1,
                  end: Math.min(page * limit, totalRecords),
                  total: totalRecords,
                })}
              </div>
            )}
          </div>
        </PaginationItem>
      </PaginationContent>
    </Pagination>
  );
}
