"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, BarChart3, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { statisticsService } from "@/services/statisticsService";
import { fetchAreas, type Area } from "@/lib/areas";
import type { Order } from "@/types/order";
import { StatisticsData } from "@/components/statistics/types";
import { OrdersOverview } from "@/components/statistics/OrdersOverview";
import { ProposalsOverview } from "@/components/statistics/ProposalsOverview";
import { CouriersOverview } from "@/components/statistics/CouriersOverview";
import { CustomerOverview } from "@/components/statistics/CustomerOverview";
import { SellerOverview } from "@/components/statistics/SellerOverview";
import { FinancialOverview } from "@/components/statistics/FinancialOverview";
import { AreasOverview } from "@/components/statistics/AreasOverview";

const parseMoney = (value?: string | null) => {
  if (!value) return 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const getErrorMessage = (error: unknown, fallback: string) => {
  if (typeof error === "object" && error !== null) {
    if ("message" in error && typeof error.message === "string") {
      return error.message;
    }
  }
  return fallback;
};

export default function StatisticsPage() {
  const router = useRouter();
  const [orders, setOrders] = useState<Order[]>([]);
  const [allAreas, setAllAreas] = useState<Area[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [activeTab, setActiveTab] = useState("orders");
  const [loadedTabs, setLoadedTabs] = useState<Set<string>>(new Set(["orders"]));

  useEffect(() => {
    let isMounted = true;

    const fetchAllData = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const [ordersData, areasData] = await Promise.all([
          statisticsService.fetchOrdersStatsSource(),
          fetchAreas({ limit: 1000 }),
        ]);
        if (isMounted) {
          setOrders(ordersData);
          setAllAreas(areasData.areas || []);
        }
      } catch (err: unknown) {
        if (isMounted) {
          setError(getErrorMessage(err, "Failed to load order statistics"));
        }
      } finally {
        if (isMounted) setIsLoading(false);
      }
    };

    fetchAllData();

    return () => {
      isMounted = false;
    };
  }, [refreshKey]);

  useEffect(() => {
    setLoadedTabs(new Set(["orders"]));
  }, [refreshKey]);

  const handleTabChange = (value: string) => {
    setActiveTab(value);
    setLoadedTabs((prev) => new Set(prev).add(value));
  };

  const ordersStats = useMemo(() => {
    if (!loadedTabs.has("orders")) {
      return {
        totalOrders: 0,
        statusCounts: {
          PENDING: 0,
          IN_PROGRESS: 0,
          DELIVERED: 0,
          CANCELLED: 0,
          SEARCHING_FAILED: 0,
          EXPIRED: 0,
        },
        paymentCounts: { CASH: 0, WALLET: 0, UNKNOWN: 0 },
        adjustmentCounts: {
          NONE: 0,
          PENDING: 0,
          ACCEPTED: 0,
          REJECTED: 0,
          UNKNOWN: 0,
        },
        ordersWithProposals: 0,
        ordersWithoutProposals: 0,
        cancelledReasonCounts: {},
      };
    }

    const totalOrders = orders.length;
    const statusCounts = {
      PENDING: 0,
      IN_PROGRESS: 0,
      DELIVERED: 0,
      CANCELLED: 0,
      SEARCHING_FAILED: 0,
      EXPIRED: 0,
    };
    const paymentCounts = { CASH: 0, WALLET: 0, UNKNOWN: 0 };
    const adjustmentCounts = {
      NONE: 0,
      PENDING: 0,
      ACCEPTED: 0,
      REJECTED: 0,
      UNKNOWN: 0,
    };

    let ordersWithProposals = 0;
    let ordersWithoutProposals = 0;

    const cancelledReasonMap = new Map<string, number>();

    for (const order of orders) {
      if (order.status && order.status in statusCounts) {
        statusCounts[order.status as keyof typeof statusCounts] += 1;
      }

      if (order.payment_method === "CASH" || order.payment_method === "WALLET") {
        paymentCounts[order.payment_method] += 1;
      } else {
        paymentCounts.UNKNOWN += 1;
      }

      if (
        order.price_adjustment_status &&
        order.price_adjustment_status in adjustmentCounts
      ) {
        adjustmentCounts[
          order.price_adjustment_status as keyof typeof adjustmentCounts
        ] += 1;
      } else {
        adjustmentCounts.UNKNOWN += 1;
      }

      if (order.proposals && order.proposals.length > 0) {
        ordersWithProposals++;
      } else {
        ordersWithoutProposals++;
      }

      const reason = order.cancelled_reason ?? "null";
      cancelledReasonMap.set(reason, (cancelledReasonMap.get(reason) || 0) + 1);
    }

    const cancelledReasonCounts: Record<string, number> = {};
    for (const [key, value] of cancelledReasonMap) {
      cancelledReasonCounts[key] = value;
    }

    return {
      totalOrders,
      statusCounts,
      paymentCounts,
      adjustmentCounts,
      ordersWithProposals,
      ordersWithoutProposals,
      cancelledReasonCounts,
    };
  }, [orders, loadedTabs]);

  const proposalsStats = useMemo(() => {
    if (!loadedTabs.has("proposals")) {
      return {
        totalProposals: 0,
        proposalStatusCounts: { ACCEPTED: 0, REJECTED: 0, PENDING: 0, UNKNOWN: 0 },
      };
    }

    const proposalStatusCounts = {
      ACCEPTED: 0,
      REJECTED: 0,
      PENDING: 0,
      UNKNOWN: 0,
    };

    for (const order of orders) {
      if (order.proposals && order.proposals.length > 0) {
        for (const proposal of order.proposals) {
          const status = proposal.status?.toUpperCase();
          if (status === "ACCEPTED") {
            proposalStatusCounts.ACCEPTED += 1;
          } else if (status === "REJECTED") {
            proposalStatusCounts.REJECTED += 1;
          } else if (status === "PENDING") {
            proposalStatusCounts.PENDING += 1;
          } else {
            proposalStatusCounts.UNKNOWN += 1;
          }
        }
      }
    }

    const totalProposals =
      proposalStatusCounts.ACCEPTED +
      proposalStatusCounts.REJECTED +
      proposalStatusCounts.PENDING +
      proposalStatusCounts.UNKNOWN;

    return { totalProposals, proposalStatusCounts };
  }, [orders, loadedTabs]);

  const couriersStats = useMemo(() => {
    if (!loadedTabs.has("couriers")) {
      return {
        totalCouriers: 0,
        assignedCouriers: 0,
        freeCouriers: 0,
        approvedCouriers: 0,
        notApprovedCouriers: 0,
      };
    }

    const assignedCourierIds = new Set<number>();
    const inProgressCourierIds = new Set<number>();
    const approvedCourierIds = new Set<number>();
    const notApprovedCourierIds = new Set<number>();

    for (const order of orders) {
      if (order.courier_id) {
        assignedCourierIds.add(order.courier_id);
        if (order.status === "IN_PROGRESS") {
          inProgressCourierIds.add(order.courier_id);
        }
        if (order.courier?.is_approved === true) {
          approvedCourierIds.add(order.courier_id);
        } else if (order.courier?.is_approved === false) {
          notApprovedCourierIds.add(order.courier_id);
        }
      }
    }

    const totalCouriers = assignedCourierIds.size;
    const assignedCouriers = inProgressCourierIds.size;
    const freeCouriers = totalCouriers - assignedCouriers;
    const approvedCouriers = approvedCourierIds.size;
    const notApprovedCouriers = notApprovedCourierIds.size;

    return {
      totalCouriers,
      assignedCouriers,
      freeCouriers,
      approvedCouriers,
      notApprovedCouriers,
    };
  }, [orders, loadedTabs]);

  const customersStats = useMemo(() => {
    if (!loadedTabs.has("customers")) {
      return { totalCustomers: 0 };
    }

    const customerIds = new Set<number>();
    for (const order of orders) {
      if (order.customer_id) {
        customerIds.add(order.customer_id);
      }
    }
    return { totalCustomers: customerIds.size };
  }, [orders, loadedTabs]);

  const sellersStats = useMemo(() => {
    if (!loadedTabs.has("sellers")) {
      return { totalSellers: 0 };
    }

    const sellerIds = new Set<number>();
    for (const order of orders) {
      if (order.customer_id && order.customer?.role_id === 4) {
        sellerIds.add(order.customer_id);
      }
    }
    return { totalSellers: sellerIds.size };
  }, [orders, loadedTabs]);

  const financialStats = useMemo(() => {
    if (!loadedTabs.has("financial")) {
      return {
        totalBudget: 0,
        totalPayable: 0,
        totalFees: 0,
        totalPlatformFees: 0,
        totalCourierFees: 0,
      };
    }

    let totalBudget = 0;
    let totalPayable = 0;
    let totalFees = 0;
    let totalPlatformFees = 0;
    let totalCourierFees = 0;

    for (const order of orders) {
      totalBudget += parseMoney(order.budget);
      totalPayable += parseMoney(order.payable_amount);
      totalFees += parseMoney(order.total_fee);
      totalPlatformFees += parseMoney(order.platform_fee);
      totalCourierFees += parseMoney(order.courier_fee);
    }

    return {
      totalBudget,
      totalPayable,
      totalFees,
      totalPlatformFees,
      totalCourierFees,
    };
  }, [orders, loadedTabs]);

  const areasStats = useMemo(() => {
    if (!loadedTabs.has("areas")) {
      return { pickupAreas: [], deliveryAreas: [] };
    }

    type AreaBucket = {
      count: number;
      areaId?: number;
      governorateId?: number;
      isUnknown?: boolean;
    };
    const pickupAreaData = new Map<string, AreaBucket>();
    const deliveryAreaData = new Map<string, AreaBucket>();

    for (const area of allAreas) {
      const areaName = area.name || `Area #${area.id}`;
      pickupAreaData.set(areaName, {
        count: 0,
        areaId: area.id,
        governorateId: area.governorate_id,
        isUnknown: false,
      });
      deliveryAreaData.set(areaName, {
        count: 0,
        areaId: area.id,
        governorateId: area.governorate_id,
        isUnknown: false,
      });
    }

    for (const order of orders) {
      const pickupName =
        order.pickup_area?.name ||
        (order.pickup_area_id ? `Area #${order.pickup_area_id}` : "Unknown");
      const existingPickup = pickupAreaData.get(pickupName);
      if (existingPickup) {
        existingPickup.count += 1;
      } else {
        pickupAreaData.set(pickupName, {
          count: 1,
          areaId: order.pickup_area?.id || order.pickup_area_id || undefined,
          governorateId: order.pickup_area?.governorate_id || undefined,
          isUnknown: true,
        });
      }

      const deliveryName =
        order.delivery_area?.name ||
        (order.delivery_area_id ? `Area #${order.delivery_area_id}` : "Unknown");
      const existingDelivery = deliveryAreaData.get(deliveryName);
      if (existingDelivery) {
        existingDelivery.count += 1;
      } else {
        deliveryAreaData.set(deliveryName, {
          count: 1,
          areaId: order.delivery_area?.id || order.delivery_area_id || undefined,
          governorateId: order.delivery_area?.governorate_id || undefined,
          isUnknown: true,
        });
      }
    }

    const pickupAreas = [...pickupAreaData.entries()]
      .sort((a, b) => b[1].count - a[1].count)
      .map(([name, data]) => ({ name, ...data }));

    const deliveryAreas = [...deliveryAreaData.entries()]
      .sort((a, b) => b[1].count - a[1].count)
      .map(([name, data]) => ({ name, ...data }));

    return { pickupAreas, deliveryAreas };
  }, [orders, allAreas, loadedTabs]);

  const stats = useMemo<StatisticsData>(() => {
    return {
      ...ordersStats,
      ...proposalsStats,
      ...couriersStats,
      ...customersStats,
      ...sellersStats,
      ...financialStats,
      ...areasStats,
    };
  }, [
    ordersStats,
    proposalsStats,
    couriersStats,
    customersStats,
    sellersStats,
    financialStats,
    areasStats,
  ]);

  const handleAreaClick = (
    areaId: number | undefined,
    governorateId: number | undefined,
    areaName: string,
    isUnknown: boolean,
  ) => {
    if (isUnknown) return;
    if (!areaId || !governorateId) {
      alert(
        `Area "${areaName}" information is incomplete. Area ID or Governorate ID is missing.`,
      );
      return;
    }
    router.push(`/areas?governorate_id=${governorateId}`);
  };

  if (isLoading) {
    return (
      <div className="space-y-6 p-6">
        <Skeleton className="h-10 w-72" />
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 12 }).map((_, index) => (
            <Skeleton key={index} className="h-32 w-full" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="m-4 space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" onClick={() => router.push("/")}>
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <h1 className="flex items-center gap-2 text-3xl font-bold">
              <BarChart3 className="h-7 w-7" />
              Statistics
            </h1>
            <p className="text-sm text-muted-foreground">
              Comprehensive analytics dashboard for orders, proposals, couriers,
              customers, and financial metrics.
            </p>
          </div>
        </div>

        <Button variant="outline" onClick={() => setRefreshKey((prev) => prev + 1)}>
          <RefreshCw className="mr-2 h-4 w-4" />
          Refresh Stats
        </Button>
      </div>

      {error && (
        <div className="rounded bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      )}

      <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full">
        <TabsList className="w-full justify-start overflow-x-auto">
          <TabsTrigger value="orders">Orders</TabsTrigger>
          <TabsTrigger value="proposals">Proposals</TabsTrigger>
          <TabsTrigger value="couriers">Couriers</TabsTrigger>
          <TabsTrigger value="customers">Customers</TabsTrigger>
          <TabsTrigger value="sellers">Sellers</TabsTrigger>
          <TabsTrigger value="financial">Financial</TabsTrigger>
          <TabsTrigger value="areas">Areas</TabsTrigger>
        </TabsList>

        <TabsContent value="orders" className="mt-6">
          <OrdersOverview stats={stats} />
        </TabsContent>

        <TabsContent value="proposals" className="mt-6">
          <ProposalsOverview stats={stats} />
        </TabsContent>

        <TabsContent value="couriers" className="mt-6">
          <CouriersOverview stats={stats} />
        </TabsContent>

        <TabsContent value="customers" className="mt-6">
          <CustomerOverview />
        </TabsContent>

        <TabsContent value="sellers" className="mt-6">
          <SellerOverview />
        </TabsContent>

        <TabsContent value="financial" className="mt-6">
          <FinancialOverview stats={stats} />
        </TabsContent>

        <TabsContent value="areas" className="mt-6">
          <AreasOverview stats={stats} onAreaClick={handleAreaClick} />
        </TabsContent>
      </Tabs>
    </div>
  );
}
