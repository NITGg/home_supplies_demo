"use client";

import { useRouter } from "next/navigation";
import { StatisticsData } from "./types";
import { StatCard, ProgressBarCard, SectionHeader } from "./components";

interface OrdersOverviewProps {
  stats: StatisticsData;
}

export function OrdersOverview({ stats }: OrdersOverviewProps) {
  const router = useRouter();

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

  return (
    <div className="space-y-4">
      <SectionHeader
        title="Orders Overview"
        description="Complete breakdown of order statuses and lifecycle metrics."
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="All Orders"
          value={stats.totalOrders.toLocaleString()}
          description="The full number of orders in the system."
          hint="Calculated as the total count of all orders returned by the API."
          onClick={() => navigateToOrders()}
        />
        <StatCard
          title="Delivered Orders"
          value={stats.statusCounts.DELIVERED.toLocaleString()}
          description="Orders that have been successfully delivered to recipients."
          hint="Calculated by counting orders with status = DELIVERED."
          onClick={() => navigateToOrders({ status: "DELIVERED" })}
        />
        <StatCard
          title="Cancelled Orders"
          value={stats.statusCounts.CANCELLED.toLocaleString()}
          description="Orders that were cancelled before completion."
          hint="Calculated by counting orders with status = CANCELLED."
          onClick={() => navigateToOrders({ status: "CANCELLED" })}
        />
        <StatCard
          title="Pending Orders"
          value={stats.statusCounts.PENDING.toLocaleString()}
          description="Orders awaiting assignment or initial processing."
          hint="Calculated by counting orders with status = PENDING."
          onClick={() => navigateToOrders({ status: "PENDING" })}
        />
        <StatCard
          title="In Progress Orders"
          value={stats.statusCounts.IN_PROGRESS.toLocaleString()}
          description="Orders currently being processed by couriers."
          hint="Calculated by counting orders with status = IN_PROGRESS."
          onClick={() => navigateToOrders({ status: "IN_PROGRESS" })}
        />
        <StatCard
          title="Searching Failed Orders"
          value={(stats.statusCounts.SEARCHING_FAILED ?? 0).toLocaleString()}
          description="Orders where courier search has failed."
          hint="Calculated by counting orders with status = SEARCHING_FAILED."
          onClick={() => navigateToOrders({ status: "SEARCHING_FAILED" })}
        />
        <StatCard
          title="Expired Orders"
          value={(stats.statusCounts.EXPIRED ?? 0).toLocaleString()}
          description="Orders that have expired."
          hint="Calculated by counting orders with status = EXPIRED."
          onClick={() => navigateToOrders({ status: "EXPIRED" })}
        />
        <StatCard
          title="Orders With Proposals"
          value={stats.ordersWithProposals.toLocaleString()}
          description="Orders that have received at least one proposal from couriers."
          hint="Calculated by counting orders with proposals array length > 0."
          onClick={() => navigateToOrders({ has_proposals: "yes" })}
        />
        <StatCard
          title="Orders Without Proposals"
          value={stats.ordersWithoutProposals.toLocaleString()}
          description="Orders that have not received any proposals from couriers."
          hint="Calculated by counting orders with empty or missing proposals array."
          onClick={() => navigateToOrders({ has_proposals: "no" })}
        />

        <ProgressBarCard
          title="Proposal Status Distribution"
          rows={[
            {
              label: "With Proposals",
              value: stats.ordersWithProposals,
              total: stats.ordersWithProposals + stats.ordersWithoutProposals,
              colorClass: "bg-green-500",
            },
            {
              label: "Without Proposals",
              value: stats.ordersWithoutProposals,
              total: stats.ordersWithProposals + stats.ordersWithoutProposals,
              colorClass: "bg-gray-400",
            },
          ]}
        />

        <ProgressBarCard
          title="Order Status Distribution"
          rows={[
            {
              label: "DELIVERED",
              value: stats.statusCounts.DELIVERED,
              total: stats.totalOrders,
              colorClass: "bg-green-500",
            },
            {
              label: "CANCELLED",
              value: stats.statusCounts.CANCELLED,
              total: stats.totalOrders,
              colorClass: "bg-red-500",
            },
            {
              label: "PENDING",
              value: stats.statusCounts.PENDING,
              total: stats.totalOrders,
              colorClass: "bg-yellow-500",
            },
            {
              label: "IN_PROGRESS",
              value: stats.statusCounts.IN_PROGRESS,
              total: stats.totalOrders,
              colorClass: "bg-blue-500",
            },
            {
              label: "SEARCHING_FAILED",
              value: stats.statusCounts.SEARCHING_FAILED ?? 0,
              total: stats.totalOrders,
              colorClass: "bg-orange-500",
            },
            {
              label: "EXPIRED",
              value: stats.statusCounts.EXPIRED ?? 0,
              total: stats.totalOrders,
              colorClass: "bg-gray-500",
            },
          ]}
        />

        <div className="max-h-80 overflow-y-auto">
          <ProgressBarCard
            title="Cancellation Reasons"
            rows={Object.entries(stats.cancelledReasonCounts || {}).map(
              ([reason, count]) => ({
                label: reason === "null" ? "No Reason" : reason,
                value: count,
                total: Object.values(stats.cancelledReasonCounts || {}).reduce(
                  (a, b) => a + b,
                  0,
                ),
                colorClass: reason === "null" ? "bg-gray-400" : "bg-orange-500",
              }),
            )}
          />
        </div>
      </div>
    </div>
  );
}
