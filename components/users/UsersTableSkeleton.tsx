"use client";

import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

/**
 * Mock translation function for consistency across components
 */
const t = (key: string, fallback?: string) => fallback || key;

export function UsersTableSkeleton() {
  // Defined as a constant to avoid re-calculation on re-renders
  const columns = [
    { label: t("id", "ID"), width: "w-12" },
    { label: t("name", "Name"), width: "w-full max-w-[150px]" },
    { label: t("email", "Email"), width: "w-full max-w-[200px]" },
    { label: t("role", "Role"), width: "w-20" },
    { label: t("status", "Status"), width: "w-16" },
    { label: t("actions", "Actions"), width: "w-12 ml-auto" },
  ];

  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow className="bg-muted/50">
            {columns.map((col) => (
              <TableHead key={col.label} className={col.label === t("actions", "Actions") ? "text-right" : ""}>
                {col.label}
              </TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {Array.from({ length: 5 }).map((_, rowIndex) => (
            <TableRow key={`row-${rowIndex}`}>
              {columns.map((col, colIndex) => (
                <TableCell 
                  key={`cell-${rowIndex}-${colIndex}`}
                  className={col.label === t("actions", "Actions") ? "text-right" : ""}
                >
                  <Skeleton className={`h-4 ${col.width}`} />
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}