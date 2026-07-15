"use client";

import { useRouter } from "next/navigation";
import { StatisticsData } from "./types";
import { StatCard, ProgressBarCard, SectionHeader } from "./components";

interface CouriersOverviewProps {
  stats: StatisticsData;
}

export function CouriersOverview({ stats }: CouriersOverviewProps) {
  const router = useRouter();

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

  return (
    <div className="space-y-4">
      <SectionHeader
        title="Couriers Overview"
        description="Courier utilization, availability, and approval metrics."
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="All Couriers"
          value={stats.totalCouriers.toLocaleString()}
          description="Total number of unique couriers assigned to orders."
          hint="Calculated by counting unique courier_id values across all orders."
          onClick={() => navigateToUsers({ role_id: "2" })}
        />
        <StatCard
          title="Approved Couriers"
          value={stats.approvedCouriers.toLocaleString()}
          description="Couriers with approved status."
          hint="Calculated by counting unique couriers where is_approved = true."
          onClick={() => navigateToUsers({ role_id: "2", is_approved: "true" })}
        />
        <StatCard
          title="Not Approved Couriers"
          value={stats.notApprovedCouriers.toLocaleString()}
          description="Couriers awaiting approval or not approved."
          hint="Calculated by counting unique couriers where is_approved = false."
          onClick={() => navigateToUsers({ role_id: "2", is_approved: "false" })}
        />
        <StatCard
          title="Assigned Couriers"
          value={stats.assignedCouriers.toLocaleString()}
          description="Couriers currently handling in-progress orders."
          hint="Calculated by counting unique courier_id where order status = IN_PROGRESS."
          onClick={() =>
            navigateToUsers({ role_id: "2", courier_availability: "assigned" })
          }
        />
        <StatCard
          title="Free Couriers"
          value={stats.freeCouriers.toLocaleString()}
          description="Couriers not currently assigned to active orders."
          hint="Calculated as All Couriers minus Assigned Couriers."
          onClick={() =>
            navigateToUsers({ role_id: "2", courier_availability: "free" })
          }
        />

        <ProgressBarCard
          title="Courier Availability"
          rows={[
            {
              label: "Assigned (In Progress)",
              value: stats.assignedCouriers,
              total: stats.totalCouriers,
              colorClass: "bg-blue-500",
            },
            {
              label: "Free",
              value: stats.freeCouriers,
              total: stats.totalCouriers,
              colorClass: "bg-green-500",
            },
          ]}
        />
        <ProgressBarCard
          title="Courier Approval Status"
          rows={[
            {
              label: "Approved",
              value: stats.approvedCouriers,
              total: stats.totalCouriers,
              colorClass: "bg-green-500",
            },
            {
              label: "Not Approved",
              value: stats.notApprovedCouriers,
              total: stats.totalCouriers,
              colorClass: "bg-red-500",
            },
          ]}
        />
      </div>
    </div>
  );
}
