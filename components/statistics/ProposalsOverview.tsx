"use client";

import { StatisticsData } from "./types";
import { StatCard, ProgressBarCard, SectionHeader } from "./components";

interface ProposalsOverviewProps {
  stats: StatisticsData;
}

export function ProposalsOverview({ stats }: ProposalsOverviewProps) {
  return (
    <div className="space-y-4">
      <SectionHeader
        title="Proposals Overview"
        description="Summary of all delivery proposals and their current status."
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="All Proposals"
          value={stats.totalProposals.toLocaleString()}
          description="Total number of delivery proposals submitted."
          hint="Calculated by counting all proposal records across all orders."
        />
        <StatCard
          title="Accepted Proposals"
          value={stats.proposalStatusCounts.ACCEPTED.toLocaleString()}
          description="Proposals that were accepted by customers."
          hint="Calculated by counting proposals with status = ACCEPTED."
        />
        <StatCard
          title="Rejected Proposals"
          value={stats.proposalStatusCounts.REJECTED.toLocaleString()}
          description="Proposals that were rejected by customers."
          hint="Calculated by counting proposals with status = REJECTED."
        />
        <StatCard
          title="Pending Proposals"
          value={stats.proposalStatusCounts.PENDING.toLocaleString()}
          description="Proposals awaiting customer response."
          hint="Calculated by counting proposals with status = PENDING."
        />

        <ProgressBarCard
          title="Proposal Status Distribution"
          rows={[
            {
              label: "ACCEPTED",
              value: stats.proposalStatusCounts.ACCEPTED,
              total: stats.totalProposals,
              colorClass: "bg-green-500",
            },
            {
              label: "REJECTED",
              value: stats.proposalStatusCounts.REJECTED,
              total: stats.totalProposals,
              colorClass: "bg-red-500",
            },
            {
              label: "PENDING",
              value: stats.proposalStatusCounts.PENDING,
              total: stats.totalProposals,
              colorClass: "bg-yellow-500",
            },
          ]}
        />
      </div>
    </div>
  );
}
