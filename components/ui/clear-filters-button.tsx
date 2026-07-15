import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface ClearFiltersButtonProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  filters: any;
  onClear: () => void;
  className?: string;
  size?: "default" | "sm" | "lg" | "icon";
  variant?: "default" | "outline" | "ghost" | "secondary";
}

export function ClearFiltersButton({
  filters,
  onClear,
  className,
  size = "default",
  variant = "outline",
}: ClearFiltersButtonProps) {
  const hasActiveFilters = Object.values(filters).some(
    (value) => value !== "" && value !== undefined && value !== null,
  );

  return (
    <Button
      variant={variant}
      size={size}
      onClick={onClear}
      disabled={!hasActiveFilters}
      className={cn("whitespace-nowrap", className)}
    >
      <X className="h-4 w-4 mr-1" />
      Clear Filters
    </Button>
  );
}
