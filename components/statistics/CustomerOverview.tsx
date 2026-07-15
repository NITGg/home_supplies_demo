"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { StatCard, SectionHeader } from "./components";
import { statisticsService } from "@/services/statisticsService";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface CustomerStats {
  totalCustomers: number;
  totalOrders: number;
  pendingOrders: number;
  inProgressOrders: number;
  deliveredOrders: number;
  cancelledOrders: number;
  searchingFailedOrders: number;
  expiredOrders: number;
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

export function CustomerOverview() {
  const router = useRouter();
  const [customerStats, setCustomerStats] = useState<CustomerStats | null>(null);
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

    const fetchCustomerStats = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const [
          totalCustomers,
          totalOrders,
          pendingOrders,
          inProgressOrders,
          deliveredOrders,
          cancelledOrders,
          searchingFailedOrders,
          expiredOrders,
        ] = await Promise.all([
          statisticsService.fetchCustomerTotalUsers(),
          statisticsService.fetchCustomerTotalOrders(),
          statisticsService.fetchCustomerOrdersByStatus("PENDING"),
          statisticsService.fetchCustomerOrdersByStatus("IN_PROGRESS"),
          statisticsService.fetchCustomerOrdersByStatus("DELIVERED"),
          statisticsService.fetchCustomerOrdersByStatus("CANCELLED"),
          statisticsService.fetchCustomerOrdersByStatus("SEARCHING_FAILED"),
          statisticsService.fetchCustomerOrdersByStatus("EXPIRED"),
        ]);

        if (isMounted) {
          setCustomerStats({
            totalCustomers,
            totalOrders,
            pendingOrders,
            inProgressOrders,
            deliveredOrders,
            cancelledOrders,
            searchingFailedOrders,
            expiredOrders,
          });
        }
      } catch (err) {
        if (isMounted) {
          setError(
            err instanceof Error ? err.message : "Failed to fetch customer stats",
          );
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    };

    fetchCustomerStats();

    return () => {
      isMounted = false;
    };
  }, []);

  if (isLoading) {
    return (
      <div className="space-y-4">
        <SectionHeader
          title="Customer Overview"
          description="Customer participation and order activity metrics."
        />
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 7 }).map((_, i) => (
            <Skeleton key={i} className="h-32 w-full" />
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-4">
        <SectionHeader
          title="Customer Overview"
          description="Customer participation and order activity metrics."
        />
        <div className="rounded bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <SectionHeader
        title="Customer Overview"
        description="Customer participation and order activity metrics."
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="All Customers"
          value={customerStats?.totalCustomers.toLocaleString() || "0"}
          description="Total number of unique customers with orders."
          hint="From API: GET /users?role_id=3"
          onClick={() => navigateToUsers({ role_id: "3" })}
        />

        <StatCard
          title="Total Orders"
          value={customerStats?.totalOrders.toLocaleString() || "0"}
          description="Total number of orders created by all customers across the platform."
          hint="From API: GET /admin/orders?limit=0&skip=0&customer[role_id]=3"
          onClick={() => navigateToOrders({ created_by_role_id: "3" })}
        />

        <StatCard
          title="Pending Orders"
          value={customerStats?.pendingOrders.toLocaleString() || "0"}
          description="Orders awaiting assignment or initial processing."
          hint="From API: GET /users?role_id=3&orders[some][status]=PENDING"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "3", status: "PENDING" })
          }
        />

        <StatCard
          title="In Progress Orders"
          value={customerStats?.inProgressOrders.toLocaleString() || "0"}
          description="Orders currently being processed or in transit."
          hint="From API: GET /users?role_id=3&orders[some][status]=IN_PROGRESS"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "3", status: "IN_PROGRESS" })
          }
        />

        <StatCard
          title="Delivered Orders"
          value={customerStats?.deliveredOrders.toLocaleString() || "0"}
          description="Orders successfully completed and delivered to customers."
          hint="From API: GET /users?role_id=3&orders[some][status]=DELIVERED"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "3", status: "DELIVERED" })
          }
        />

        <StatCard
          title="Cancelled Orders"
          value={customerStats?.cancelledOrders.toLocaleString() || "0"}
          description="Orders that were cancelled before completion."
          hint="From API: GET /users?role_id=3&orders[some][status]=CANCELLED"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "3", status: "CANCELLED" })
          }
        />

        <StatCard
          title="Searching Failed Orders"
          value={customerStats?.searchingFailedOrders.toLocaleString() || "0"}
          description="Orders where courier search has failed."
          hint="From API: GET /users?role_id=3&orders[some][status]=SEARCHING_FAILED"
          onClick={() =>
            navigateToOrders({
              created_by_role_id: "3",
              status: "SEARCHING_FAILED",
            })
          }
        />

        <StatCard
          title="Expired Orders"
          value={customerStats?.expiredOrders.toLocaleString() || "0"}
          description="Orders that have expired."
          hint="From API: GET /users?role_id=3&orders[some][status]=EXPIRED"
          onClick={() =>
            navigateToOrders({ created_by_role_id: "3", status: "EXPIRED" })
          }
        />
      </div>

      {customerStats && customerStats.totalOrders > 0 && (
        <div className="mt-6">
          <ProgressBarCard
            title="Order Status Distribution"
            rows={[
              {
                label: "Pending",
                value: customerStats.pendingOrders,
                total: customerStats.totalOrders,
                colorClass: "bg-yellow-500",
              },
              {
                label: "In Progress",
                value: customerStats.inProgressOrders,
                total: customerStats.totalOrders,
                colorClass: "bg-blue-500",
              },
              {
                label: "Delivered",
                value: customerStats.deliveredOrders,
                total: customerStats.totalOrders,
                colorClass: "bg-green-500",
              },
              {
                label: "Cancelled",
                value: customerStats.cancelledOrders,
                total: customerStats.totalOrders,
                colorClass: "bg-red-500",
              },
              {
                label: "Searching Failed",
                value: customerStats.searchingFailedOrders,
                total: customerStats.totalOrders,
                colorClass: "bg-orange-500",
              },
              {
                label: "Expired",
                value: customerStats.expiredOrders,
                total: customerStats.totalOrders,
                colorClass: "bg-gray-500",
              },
            ]}
          />
        </div>
      )}
    </div>
  );
}
