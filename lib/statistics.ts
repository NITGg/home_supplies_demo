import api from "./api";
import type { OrderStatus } from "./orders";

export interface StatsOrder {
  id: number;
  status: OrderStatus;
  payment_method?: "CASH" | "WALLET" | null;
  // The API returns monetary amounts as strings (e.g. "15000"); parse before use.
  actual_price?: string | number | null;
  payable_amount?: string | number | null;
  total_fee?: string | number | null;
  courier_fee?: string | number | null;
  platform_fee?: string | number | null;
  customer_id?: number | null;
  courier_id?: number | null;
  pickup_area_id?: number | null;
  delivery_area_id?: number | null;
  created_at: string;
}

/** Coerce an API money value (string | number | null) to a finite number. */
function toNum(v: string | number | null | undefined): number {
  const n = typeof v === "string" ? parseFloat(v) : v ?? 0;
  return Number.isFinite(n as number) ? (n as number) : 0;
}

export interface StatsArea {
  id: number;
  name: string;
  name_ar: string;
  governorate_id?: number | null;
}

export interface OrderStats {
  total: number;
  byStatus: Record<OrderStatus, number>;
  byCash: number;
  byWallet: number;
  totalRevenue: number;
  totalCourierFee: number;
  totalPlatformFee: number;
  uniqueCustomers: number;
  uniqueCouriers: number;
  topPickupAreas: { areaId: number; name: string; count: number }[];
  topDeliveryAreas: { areaId: number; name: string; count: number }[];
}

async function fetchAllOrders(): Promise<StatsOrder[]> {
  const PAGE_SIZE = 200;
  const first = await api.get<{ orders: StatsOrder[]; totalOrders: number; totalPages: number }>(
    "/admin/orders",
    { params: { limit: PAGE_SIZE, skip: 0, sort: "-created_at" } },
  );
  const { orders: firstBatch, totalPages } = first.data;
  if (totalPages <= 1) return firstBatch;

  const rest = await Promise.all(
    Array.from({ length: totalPages - 1 }, (_, i) =>
      api.get<{ orders: StatsOrder[] }>("/admin/orders", {
        params: { limit: PAGE_SIZE, skip: (i + 1) * PAGE_SIZE, sort: "-created_at" },
      }),
    ),
  );
  return [...firstBatch, ...rest.flatMap(r => r.data.orders)];
}

async function fetchAreas(): Promise<StatsArea[]> {
  const res = await api.get<{ areas: StatsArea[] }>("/admin/areas", {
    params: { limit: 500, skip: 0 },
  });
  return res.data.areas ?? [];
}

export async function fetchOrderStats(): Promise<OrderStats> {
  const [orders, areas] = await Promise.all([fetchAllOrders(), fetchAreas()]);

  const areaMap = new Map<number, string>(areas.map(a => [a.id, a.name]));

  const byStatus: Record<string, number> = {};
  let byCash = 0, byWallet = 0;
  let totalRevenue = 0, totalCourierFee = 0, totalPlatformFee = 0;
  const customerSet = new Set<number>();
  const courierSet = new Set<number>();
  const pickupCount = new Map<number, number>();
  const deliveryCount = new Map<number, number>();

  for (const o of orders) {
    byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
    if (o.payment_method === "CASH") byCash++;
    else if (o.payment_method === "WALLET") byWallet++;
    // Revenue = what the customer actually pays (payable_amount), per the spec.
    // Fall back to actual_price when payable_amount isn't populated.
    totalRevenue += toNum(o.payable_amount ?? o.actual_price);
    totalCourierFee += toNum(o.courier_fee);
    totalPlatformFee += toNum(o.platform_fee);
    if (o.customer_id) customerSet.add(o.customer_id);
    if (o.courier_id) courierSet.add(o.courier_id);
    if (o.pickup_area_id) pickupCount.set(o.pickup_area_id, (pickupCount.get(o.pickup_area_id) ?? 0) + 1);
    if (o.delivery_area_id) deliveryCount.set(o.delivery_area_id, (deliveryCount.get(o.delivery_area_id) ?? 0) + 1);
  }

  const topAreas = (countMap: Map<number, number>) =>
    [...countMap.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([areaId, count]) => ({ areaId, name: areaMap.get(areaId) ?? `#${areaId}`, count }));

  return {
    total: orders.length,
    byStatus: byStatus as Record<OrderStatus, number>,
    byCash,
    byWallet,
    totalRevenue,
    totalCourierFee,
    totalPlatformFee,
    uniqueCustomers: customerSet.size,
    uniqueCouriers: courierSet.size,
    topPickupAreas: topAreas(pickupCount),
    topDeliveryAreas: topAreas(deliveryCount),
  };
}
