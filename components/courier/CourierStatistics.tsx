import React from "react";
import { OrderStatisticsSection } from "./OrderStatisticsSection";
import { CouponStatisticsSection } from "./CouponStatisticsSection";
import { ReviewStatisticsSection } from "./ReviewStatisticsSection";

export function CourierStatistics({ courierId }: { courierId: number }) {
  if (!courierId) return null;

  return (
    <div className="space-y-12">
      <OrderStatisticsSection courierId={courierId} />
      <hr className="border-border opacity-50" />
      <CouponStatisticsSection courierId={courierId} />
      <hr className="border-border opacity-50" />
      <ReviewStatisticsSection courierId={courierId} />
    </div>
  );
}
