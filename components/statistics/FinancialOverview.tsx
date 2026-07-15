"use client";

import { useRouter } from "next/navigation";
import { StatisticsData } from "./types";
import {
  StatCard,
  StatCardWithUnit,
  ProgressBarCard,
  SectionHeader,
  GroupLabel,
} from "./components";

interface FinancialOverviewProps {
  stats: StatisticsData;
}

const formatCurrency = (value: number) => `${Number(value).toLocaleString()}`;

export function FinancialOverview({ stats }: FinancialOverviewProps) {
  const router = useRouter();

  const navigateToOrdersWithFilter = (
    filterKey: string,
    filterValue: string,
  ) => {
    router.push(`/orders?${filterKey}=${encodeURIComponent(filterValue)}`);
  };

  return (
    <div className="space-y-4">
      <SectionHeader
        title="Financial Overview"
        description="Financial metrics, payment methods, and price adjustment breakdowns."
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        {/* Group 1: Core Financial Metrics */}
        <GroupLabel>Core Financial Metrics</GroupLabel>
        <StatCardWithUnit
          title="Total Budget"
          unit="EG"
          value={formatCurrency(stats.totalBudget)}
          description="The sum of the budget amount across all orders."
          hint="Calculated by summing the budget field from all orders."
        />
        <StatCardWithUnit
          title="Total Payable"
          unit="EG"
          value={formatCurrency(stats.totalPayable)}
          description="The total payable amount across all orders."
          hint="Calculated by summing the payable_amount field from all orders."
        />

        {/* Group 2: Fee Breakdown */}
        <GroupLabel>Fee Breakdown</GroupLabel>
        <StatCardWithUnit
          title="Total Fees"
          unit="EG"
          value={formatCurrency(stats.totalFees)}
          description="The total fee collected from all orders."
          hint="Calculated by summing the total_fee field from all orders."
        />
        <StatCardWithUnit
          title="Platform Fees"
          unit="EG"
          value={formatCurrency(stats.totalPlatformFees)}
          description="The total platform fee collected from all orders."
          hint="Calculated by summing the platform_fee field from all orders."
        />
        <StatCardWithUnit
          title="Courier Fees"
          unit="EG"
          value={formatCurrency(stats.totalCourierFees)}
          description="The total courier fee across all orders."
          hint="Calculated by summing the courier_fee field from all orders."
        />
        <ProgressBarCard
          title="Fee Distribution"
          rows={[
            {
              label: "Platform Fees",
              value: stats.totalPlatformFees,
              total: stats.totalFees,
              colorClass: "bg-purple-500",
            },
            {
              label: "Courier Fees",
              value: stats.totalCourierFees,
              total: stats.totalFees,
              colorClass: "bg-orange-500",
            },
          ]}
        />

        {/* Group 3: Payment Methods */}
        <GroupLabel>Payment Methods</GroupLabel>
        <StatCard
          title="Payment Methods CASH"
          value={stats.paymentCounts.CASH.toLocaleString()}
          description="Orders using cash as the payment method."
          hint="Calculated by counting orders where payment_method = CASH."
          onClick={() => navigateToOrdersWithFilter("payment_method", "CASH")}
        />
        <StatCard
          title="Payment Methods WALLET"
          value={stats.paymentCounts.WALLET.toLocaleString()}
          description="Orders using wallet as the payment method."
          hint="Calculated by counting orders where payment_method = WALLET."
          onClick={() => navigateToOrdersWithFilter("payment_method", "WALLET")}
        />
        <ProgressBarCard
          title="Payment Methods Distribution"
          rows={[
            {
              label: "CASH",
              value: stats.paymentCounts.CASH,
              total: stats.totalOrders,
              colorClass: "bg-emerald-500",
            },
            {
              label: "WALLET",
              value: stats.paymentCounts.WALLET,
              total: stats.totalOrders,
              colorClass: "bg-cyan-500",
            },
          ]}
        />

        {/* Group 4: Price Adjustment Status */}
        <GroupLabel>Price Adjustment Status</GroupLabel>
        <StatCard
          title="Price Adjustment Status NONE"
          value={stats.adjustmentCounts.NONE.toLocaleString()}
          description="Orders with no price adjustment requested."
          hint="Calculated by counting orders where price_adjustment_status = NONE."
          onClick={() =>
            navigateToOrdersWithFilter("price_adjustment_status", "NONE")
          }
        />
        <StatCard
          title="Price Adjustment Status PENDING"
          value={stats.adjustmentCounts.PENDING.toLocaleString()}
          description="Orders with price adjustments awaiting approval."
          hint="Calculated by counting orders where price_adjustment_status = PENDING."
          onClick={() =>
            navigateToOrdersWithFilter("price_adjustment_status", "PENDING")
          }
        />
        <StatCard
          title="Price Adjustment Status ACCEPTED"
          value={stats.adjustmentCounts.ACCEPTED.toLocaleString()}
          description="Orders with approved price adjustments."
          hint="Calculated by counting orders where price_adjustment_status = ACCEPTED."
          onClick={() =>
            navigateToOrdersWithFilter("price_adjustment_status", "ACCEPTED")
          }
        />
        <StatCard
          title="Price Adjustment Status REJECTED"
          value={stats.adjustmentCounts.REJECTED.toLocaleString()}
          description="Orders with rejected price adjustments."
          hint="Calculated by counting orders where price_adjustment_status = REJECTED."
          onClick={() =>
            navigateToOrdersWithFilter("price_adjustment_status", "REJECTED")
          }
        />
        <ProgressBarCard
          title="Price Adjustment Status Distribution"
          rows={[
            {
              label: "NONE",
              value: stats.adjustmentCounts.NONE,
              total: stats.totalOrders,
              colorClass: "bg-gray-500",
            },
            {
              label: "PENDING",
              value: stats.adjustmentCounts.PENDING,
              total: stats.totalOrders,
              colorClass: "bg-yellow-500",
            },
            {
              label: "ACCEPTED",
              value: stats.adjustmentCounts.ACCEPTED,
              total: stats.totalOrders,
              colorClass: "bg-green-500",
            },
            {
              label: "REJECTED",
              value: stats.adjustmentCounts.REJECTED,
              total: stats.totalOrders,
              colorClass: "bg-red-500",
            },
          ]}
        />
      </div>
    </div>
  );
}
