"use client";

import { StatisticsData } from "./types";
import { SectionHeader, AreaListCard } from "./components";

interface AreasOverviewProps {
  stats: StatisticsData;
  onAreaClick: (
    areaId: number | undefined,
    governorateId: number | undefined,
    areaName: string,
    isUnknown: boolean,
  ) => void;
}

export function AreasOverview({ stats, onAreaClick }: AreasOverviewProps) {
  return (
    <div className="space-y-4">
      <SectionHeader
        title="Areas Overview"
        description="Pickup and delivery area usage statistics. Click on any area to view details."
      />

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <AreaListCard
          title="Pickup Areas"
          areas={stats.pickupAreas}
          onAreaClick={onAreaClick}
          emptyMessage="No pickup area data found."
          showUnknown={true}
          unknownLabel="Unknown"
        />
        <AreaListCard
          title="Delivery Areas"
          areas={stats.deliveryAreas}
          onAreaClick={onAreaClick}
          emptyMessage="No delivery area data found."
          showUnknown={true}
          unknownLabel="Unknown"
        />
      </div>
    </div>
  );
}
