"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { StatCard, SectionHeader } from "./components";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { statisticsService, type SellerStats } from "@/services/statisticsService";
import { Skeleton } from "@/components/ui/skeleton";

interface AggregatedStats {
  total_orders: number;
  total_pending_orders: number;
  total_in_progress_orders: number;
  total_delivered_orders: number;
  total_cancelled_orders: number;
  total_searching_failed_orders: number;
  total_expired_orders: number;
}

function ProgressBarRow({
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
      <div className="flex items-center justify-between gap-3 text-sm">
        <span className="font-medium">{label}</span>
        <span className="text-muted-foreground">
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

function ProgressBarCard({
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
            <span className="font-medium">Total</span>
            <span className="font-semibold">{totalValue.toLocaleString()}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export function SellerOverview() {
  const router = useRouter();
  const [, setSellerStats] = useState<SellerStats[]>([]);
  const [totalSellers, setTotalSellers] = useState(0);
  const [aggregatedStats, setAggregatedStats] =
    useState<AggregatedStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const navigateToUsers = (params?: Record<string, string>) => {
    const searchParams = new URLSearchParams();
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value) searchParams.set(key, value);
      });
    }
    const queryString = searchParams.toString();
    router.push(`/users${queryString ? `?${queryString}` : ""}`);
  };

  const navigateToOrders = (params?: Record<string, string>) => {
    const searchParams = new URLSearchParams();
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value) searchParams.set(key, value);
      });
    }
    const queryString = searchParams.toString();
    router.push(`/orders${queryString ? `?${queryString}` : ""}`);
  };

  useEffect(() => {
    let isMounted = true;

    const fetchSellersStats = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const statsResponse = await statisticsService.fetchSellersStats();

        if (isMounted) {
          setSellerStats(statsResponse.sellers);
          setTotalSellers(
            statsResponse.pagination?.total || statsResponse.sellers.length,
          );

          const aggregated = statsResponse.sellers.reduce(
            (acc, seller) => {
              acc.total_orders += seller.stats.total_orders;
              acc.total_pending_orders += seller.stats.total_pending_orders;
              acc.total_in_progress_orders +=
                seller.stats.total_in_progress_orders;
              acc.total_delivered_orders += seller.stats.total_delivered_orders;
              acc.total_cancelled_orders += seller.stats.total_cancelled_orders;
              acc.total_searching_failed_orders +=
                seller.stats.total_searching_failed_orders;
              acc.total_expired_orders += seller.stats.total_expired_orders;
              return acc;
            },
            {
              total_orders: 0,
              total_pending_orders: 0,
              total_in_progress_orders: 0,
              total_delivered_orders: 0,
              total_cancelled_orders: 0,
              total_searching_failed_orders: 0,
              total_expired_orders: 0,
            },
          );
          setAggregatedStats(aggregated);
        }
      } catch (err) {
        if (isMounted) {
          setError(
            err instanceof Error ? err.message : "Failed to fetch seller stats",
          );
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    };

    fetchSellersStats();

    return () => {
      isMounted = false;
    };
  }, []);

  if (isLoading) {
    return (
      <div className="space-y-4">
        <SectionHeader
          title="Seller Overview"
          description="Seller participation and order activity metrics."
        />
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 7 }).map((_, i) => (
            <Skeleton key={i} className="h-32 w-full" />
          ))}
        </div>
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-4">
        <SectionHeader
          title="Seller Overview"
          description="Seller participation and order activity metrics."
        />
        <div className="rounded bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      </div>
    );
  }

  const totalOrders = aggregatedStats?.total_orders || 0;

  const progressBarRows = aggregatedStats
    ? [
        {
          label: "Pending",
          value: aggregatedStats.total_pending_orders,
          total: totalOrders,
          colorClass: "bg-yellow-500",
        },
        {
          label: "In Progress",
          value: aggregatedStats.total_in_progress_orders,
          total: totalOrders,
          colorClass: "bg-blue-500",
        },
        {
          label: "Delivered",
          value: aggregatedStats.total_delivered_orders,
          total: totalOrders,
          colorClass: "bg-green-500",
        },
        {
          label: "Cancelled",
          value: aggregatedStats.total_cancelled_orders,
          total: totalOrders,
          colorClass: "bg-red-500",
        },
        {
          label: "Searching Failed",
          value: aggregatedStats?.total_searching_failed_orders ?? 0,
          total: totalOrders,
          colorClass: "bg-orange-500",
        },
        {
          label: "Expired",
          value: aggregatedStats?.total_expired_orders ?? 0,
          total: totalOrders,
          colorClass: "bg-gray-500",
        },
      ]
    : [];

  return (
    <div className="space-y-4">
      <SectionHeader
        title="Seller Overview"
        description="Seller participation and order activity metrics."
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="All Sellers"
          value={totalSellers.toLocaleString()}
          description="Total number of sellers registered in the system."
          hint="From API: GET /admin/manage-seller/list-sellers-stat"
          onClick={() => navigateToUsers({ role_id: "4" })}
        />

        <StatCard
          title="Total Orders"
          value={aggregatedStats?.total_orders.toLocaleString() || "0"}
          description="Total number of orders created by all sellers across the platform."
          hint="Sum of total_orders from all sellers"
          onClick={() => navigateToOrders({ created_by_role_id: "4" })}
        />

        <StatCard
          title="Pending Orders"
          value={aggregatedStats?.total_pending_orders.toLocaleString() || "0"}
          description="Orders awaiting assignment or initial processing."
          hint="Sum of pending orders across all sellers"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "4", status: "PENDING" })
          }
        />

        <StatCard
          title="In Progress Orders"
          value={
            aggregatedStats?.total_in_progress_orders.toLocaleString() || "0"
          }
          description="Orders currently being processed or in transit."
          hint="Sum of in-progress orders across all sellers"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "4", status: "IN_PROGRESS" })
          }
        />

        <StatCard
          title="Delivered Orders"
          value={aggregatedStats?.total_delivered_orders.toLocaleString() || "0"}
          description="Orders successfully completed and delivered to customers."
          hint="Sum of delivered orders across all sellers"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "4", status: "DELIVERED" })
          }
        />

        <StatCard
          title="Cancelled Orders"
          value={aggregatedStats?.total_cancelled_orders.toLocaleString() || "0"}
          description="Orders that were cancelled before completion."
          hint="Sum of cancelled orders across all sellers"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "4", status: "CANCELLED" })
          }
        />

        <StatCard
          title="Searching Failed Orders"
          value={
            aggregatedStats?.total_searching_failed_orders.toLocaleString() ||
            "0"
          }
          description="Orders where courier search has failed."
          hint="Sum of searching failed orders across all sellers"
          onClick={() =>
            navigateToOrders({
              created_by_role_id: "4",
              status: "SEARCHING_FAILED",
            })
          }
        />

        <StatCard
          title="Expired Orders"
          value={aggregatedStats?.total_expired_orders.toLocaleString() || "0"}
          description="Orders that have expired."
          hint="Sum of expired orders across all sellers"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "4", status: "EXPIRED" })
          }
        />
      </div>

      {aggregatedStats && (
        <div className="mt-6">
          <ProgressBarCard
            title="Order Status Distribution"
            rows={progressBarRows}
          />
        </div>
      )}
    </div>
  );
}
