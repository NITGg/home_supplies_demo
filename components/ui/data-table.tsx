"use client";

import React, { useState, useCallback, useMemo } from "react";
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from "@dnd-kit/core";
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  horizontalListSortingStrategy,
  useSortable,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { GripVertical, ArrowUpDown, ArrowUp, ArrowDown } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

// Fix Sonar: S7763 - Use export...from for re-exporting
export type { SortConfig, SortDirection } from "@/lib/table-utils";
import type { SortConfig } from "@/lib/table-utils";

export interface Column<T = any> {
  readonly id: string;
  readonly header: string;
  readonly accessorKey?: string;
  readonly accessorFn?: (row: T) => unknown;
  readonly cell?: (row: T) => React.ReactNode;
  readonly sortable?: boolean;
  readonly sortKey?: string;
  readonly draggable?: boolean;
  readonly width?: string;
}

// Fix TS2322: Changed Column to Column<any> to allow assignment from Column<T>
interface SortableHeaderProps {
  readonly column: Column<any>;
  readonly sortConfig: SortConfig | null;
  readonly onSort: (columnId: string) => void;
  readonly dragHandleProps?: Record<string, unknown>;
  readonly isDragging?: boolean;
  readonly style?: React.CSSProperties;
}

function SortableHeader({
  column,
  sortConfig,
  onSort,
  dragHandleProps,
  isDragging,
  style,
}: SortableHeaderProps) {
  const { attributes, listeners, setNodeRef, transform, transition } =
    useSortable({ id: column.id, disabled: column.draggable === false });

  const sortableStyle = {
    transform: CSS.Transform.toString(transform),
    transition,
    ...style,
  };

  const sortField = column.sortKey || column.id;
  const isSorted = sortConfig?.field === sortField;
  const canSort = column.sortable !== false;
  const canDrag = column.draggable !== false;

  const handleClick = () => {
    if (canSort) onSort(column.id);
  };

  const renderSortIcon = () => {
    if (!isSorted) {
      return canSort ? (
        <ArrowUpDown className="h-3 w-3 text-muted-foreground opacity-0 group-hover:opacity-50" />
      ) : null;
    }
    return sortConfig?.direction === "asc" ? (
      <ArrowUp className="h-3 w-3 text-primary" />
    ) : (
      <ArrowDown className="h-3 w-3 text-primary" />
    );
  };

  return (
    <TableHead
      ref={setNodeRef}
      style={sortableStyle}
      className={cn(
        "group relative whitespace-nowrap",
        canSort && "cursor-pointer hover:bg-muted/80 select-none",
        isDragging && "opacity-50 z-50 bg-muted",
      )}
    >
      <div className="flex items-center gap-1">
        {canDrag && (
          <button
            {...attributes}
            {...listeners}
            type="button" // Fix Sonar: accessibility
            className="cursor-grab active:cursor-grabbing p-0.5 hover:bg-muted rounded"
            onClick={(e) => e.stopPropagation()}
          >
            <GripVertical className="h-3 w-3 text-muted-foreground" />
          </button>
        )}
        <div className="flex items-center gap-1 flex-1" onClick={handleClick}>
          <span>{column.header}</span>
          {renderSortIcon()}
        </div>
      </div>
    </TableHead>
  );
}

interface DataTableProps<T> {
  readonly data: T[];
  readonly columns: Column<T>[];
  readonly isLoading?: boolean;
  readonly limit?: number;
  readonly sortConfig: SortConfig | null;
  readonly onSort: (sortConfig: SortConfig | null) => void;
  readonly onColumnOrderChange?: (columns: Column<T>[]) => void;
  readonly emptyMessage?: string;
  readonly rowClassName?: string;
  readonly rowClickable?: boolean;
  readonly onRowClick?: (row: T) => void;
  readonly actionsColumn?: {
    header: string;
    cell: (row: T) => React.ReactNode;
  };
  readonly className?: string;
}

export function DataTable<T extends { id: string | number }>({
  data,
  columns: initialColumns,
  isLoading = false,
  limit = 10,
  sortConfig,
  onSort,
  onColumnOrderChange,
  emptyMessage = "No data available",
  rowClassName,
  rowClickable = false,
  onRowClick,
  actionsColumn,
  className,
}: DataTableProps<T>) {
  const [columnOrder, setColumnOrder] = useState<Column<T>[]>(initialColumns);

  React.useEffect(() => {
    setColumnOrder(initialColumns);
  }, [initialColumns]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      if (over && active.id !== over.id) {
        setColumnOrder((items) => {
          const oldIndex = items.findIndex((item) => item.id === active.id);
          const newIndex = items.findIndex((item) => item.id === over.id);
          const newOrder = arrayMove(items, oldIndex, newIndex);
          onColumnOrderChange?.(newOrder);
          return newOrder;
        });
      }
    },
    [onColumnOrderChange],
  );

  const handleSort = useCallback(
    (columnId: string) => {
      const column = columnOrder.find((c) => c.id === columnId);
      if (column?.sortable === false) return;

      const sortField = column?.sortKey || columnId;
      let newSortConfig: SortConfig | null;

      if (sortConfig?.field === sortField) {
        if (sortConfig.direction === "asc") {
          newSortConfig = { field: sortField, direction: "desc" };
        } else if (sortConfig.direction === "desc") {
          newSortConfig = null;
        } else {
          newSortConfig = { field: sortField, direction: "asc" };
        }
      } else {
        newSortConfig = { field: sortField, direction: "asc" };
      }

      onSort(newSortConfig);
    },
    [sortConfig, onSort, columnOrder],
  );

  const visibleColumns = useMemo(
    () => columnOrder.filter((c) => c.id !== "actions"),
    [columnOrder],
  );

  const getCellValue = useCallback(
    (row: T, column: Column<T>): React.ReactNode => {
      if (column.cell) return column.cell(row);
      if (column.accessorFn) return column.accessorFn(row) as React.ReactNode;
      if (column.accessorKey) {
        return column.accessorKey
          .split(".")
          .reduce((acc: any, key) => acc?.[key], row);
      }
      return null;
    },
    [],
  );

  // Fix Sonar S3358: Extract nested ternary for better readability
  const renderTableContent = () => {
    if (isLoading) {
      return [...new Array(limit)].map((_, i) => (
        <TableRow key={`skeleton-row-${i}`}>
          {[...new Array(visibleColumns.length + (actionsColumn ? 1 : 0))].map(
            (_, j) => (
              <TableCell key={`skeleton-cell-${i}-${j}`}>
                <Skeleton className="h-4 w-full" />
              </TableCell>
            ),
          )}
        </TableRow>
      ));
    }

    if (data.length === 0) {
      return (
        <TableRow>
          <TableCell
            colSpan={visibleColumns.length + (actionsColumn ? 1 : 0)}
            className="h-24 text-center"
          >
            {emptyMessage}
          </TableCell>
        </TableRow>
      );
    }

    return data.map((row) => (
      <TableRow
        key={row.id}
        className={cn(
          rowClassName,
          rowClickable && "cursor-pointer hover:bg-muted/50",
        )}
        onClick={(e) => {
          if (rowClickable && onRowClick) {
            const target = e.target as HTMLElement;
            if (
              !target.closest("button") &&
              !target.closest("[data-actions]")
            ) {
              onRowClick(row);
            }
          }
        }}
      >
        {visibleColumns.map((column) => (
          <TableCell key={`${row.id}-${column.id}`}>
            {getCellValue(row, column)}
          </TableCell>
        ))}
        {actionsColumn && (
          <TableCell data-actions>{actionsColumn.cell(row)}</TableCell>
        )}
      </TableRow>
    ));
  };

  return (
    <div className={cn("rounded-md border bg-card", className)}>
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={handleDragEnd}
      >
        <Table>
          <TableHeader>
            <TableRow>
              <SortableContext
                items={visibleColumns.map((c) => c.id)}
                strategy={horizontalListSortingStrategy}
              >
                {visibleColumns.map((column) => (
                  <SortableHeader
                    key={column.id}
                    column={column}
                    sortConfig={sortConfig}
                    onSort={handleSort}
                  />
                ))}
              </SortableContext>
              {actionsColumn && <TableHead>{actionsColumn.header}</TableHead>}
            </TableRow>
          </TableHeader>
          <TableBody>{renderTableContent()}</TableBody>
        </Table>
      </DndContext>
    </div>
  );
}

export default DataTable;
