"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { MapPin, ChevronRight } from "lucide-react";

export function StatCard({
  title,
  value,
  hint,
  description,
  onClick,
}: {
  title: string;
  value: string;
  hint: string;
  description: string;
  onClick?: () => void;
}) {
  return (
    <Card className="flex flex-col">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex flex-1 flex-col justify-between">
        <div>
          <div className="text-3xl font-bold">{value}</div>
          <p className="mt-2 text-sm text-foreground/80">{description}</p>
          <p className="mt-1 text-sm text-muted-foreground">{hint}</p>
        </div>
        {onClick && (
          <Button
            onClick={onClick}
            variant="outline"
            size="sm"
            className="mt-4 self-start"
          >
            View Details <ChevronRight className="ml-1 h-4 w-4" />
          </Button>
        )}
      </CardContent>
    </Card>
  );
}

export function StatCardWithUnit({
  title,
  unit,
  value,
  hint,
  description,
}: {
  title: string;
  unit: string;
  value: string;
  hint: string;
  description: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-medium text-muted-foreground">
            {title}
          </CardTitle>
          <span className="text-xs font-semibold text-primary">{unit}</span>
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-bold">{value}</div>
        <p className="mt-2 text-sm text-foreground/80">{description}</p>
        <p className="mt-1 text-sm text-muted-foreground">{hint}</p>
      </CardContent>
    </Card>
  );
}

export function ProgressBarRow({
  label,
  value,
  total,
  colorClass = "bg-primary",
}: {
  label: string;
  value: number;
  total: number;
  colorClass?: string;
}) {
  const percentage = total > 0 ? (value / total) * 100 : 0;

  return (
    <div className="space-y-1">
      <div className="flex items-start justify-between gap-2 text-sm">
        <span
          className="font-medium break-words max-w-[60%] leading-tight"
          title={label}
        >
          {label}
        </span>
        <span className="text-muted-foreground whitespace-nowrap shrink-0">
          {value.toLocaleString()} ({percentage.toFixed(1)}%)
        </span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-muted">
        <div
          className={`h-full rounded-full ${colorClass}`}
          style={{ width: `${Math.min(percentage, 100)}%` }}
        />
      </div>
    </div>
  );
}

export function ProgressBarCard({
  title,
  rows,
}: {
  title: string;
  rows: { label: string; value: number; total: number; colorClass?: string }[];
}) {
  const totalValue = rows.reduce((sum, row) => sum + row.value, 0);

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {rows.map((row, index) => (
          <ProgressBarRow
            key={index}
            label={row.label}
            value={row.value}
            total={row.total}
            colorClass={row.colorClass}
          />
        ))}
        <div className="pt-2 border-t">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium">
              {title.includes("Distribution") ? "Total" : "Combined Total"}
            </span>
            <span className="font-semibold">{totalValue.toLocaleString()}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export function AreaListCard({
  title,
  areas,
  onAreaClick,
  emptyMessage,
  showUnknown = false,
  unknownLabel = "Unknown",
}: {
  title: string;
  areas: {
    name: string;
    count: number;
    areaId?: number;
    governorateId?: number;
    isUnknown?: boolean;
  }[];
  onAreaClick: (
    areaId: number | undefined,
    governorateId: number | undefined,
    areaName: string,
    isUnknown: boolean,
  ) => void;
  emptyMessage: string;
  showUnknown?: boolean;
  unknownLabel?: string;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <MapPin className="h-5 w-5" />
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent className="max-h-[400px] space-y-3 overflow-y-auto">
        {areas.length > 0 ? (
          areas.map((area, index) => (
            <div
              key={index}
              className={`flex items-center justify-between rounded-md border p-3 transition-colors ${
                area.isUnknown
                  ? "border-dashed border-yellow-400 bg-yellow-50/50"
                  : "cursor-pointer hover:bg-muted/50"
              }`}
              onClick={() =>
                !area.isUnknown &&
                onAreaClick(
                  area.areaId,
                  area.governorateId,
                  area.name,
                  area.isUnknown || false,
                )
              }
            >
              <div className="flex items-center gap-2">
                <span className="font-medium">{area.name}</span>
                {showUnknown && area.isUnknown && (
                  <Badge
                    variant="outline"
                    className="text-xs text-yellow-600 border-yellow-400"
                  >
                    {unknownLabel}
                  </Badge>
                )}
              </div>
              <Badge variant={area.count === 0 ? "outline" : "secondary"}>
                {area.count}
              </Badge>
            </div>
          ))
        ) : (
          <p className="text-sm text-muted-foreground">{emptyMessage}</p>
        )}
      </CardContent>
    </Card>
  );
}

export function SectionHeader({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div>
      <h2 className="text-xl font-semibold">{title}</h2>
      <p className="text-sm text-muted-foreground">{description}</p>
    </div>
  );
}

export function GroupLabel({ children }: { children: React.ReactNode }) {
  return (
    <div className="col-span-full mt-4 first:mt-0">
      <h3 className="text-sm font-semibold text-primary uppercase tracking-wide">
        {children}
      </h3>
      <div className="h-px bg-border mt-2" />
    </div>
  );
}
