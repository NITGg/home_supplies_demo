import api from "./api";

export type OrderStatus =
  | "PENDING"
  | "IN_PROGRESS"
  | "DELIVERED"
  | "CANCELLED"
  | "EXPIRED"
  | "SEARCHING_FAILED";

export interface OrderCustomer {
  id: number;
  full_name: string;
  phone: string;
  email?: string | null;
  personal_photo?: string | null;
}

export interface OrderCourier {
  id: number;
  full_name?: string;
  phone?: string;
  user?: {
    id: number;
    full_name: string;
    phone: string;
  };
}

export interface OrderSupplier {
  id: number;
  user?: { id: number; full_name: string; phone: string } | null;
}

export interface OrderItemProduct {
  id: number;
  name: string;
  name_ar?: string | null;
  images?: string | null;
}

export interface OrderItem {
  id: number;
  product_id: number;
  sp_id?: number | null;
  quantity: number;
  unit_price: number;       // selling price (what customer pays per unit)
  cost_price?: number | null; // supplier cost per unit
  offer_id?: number | null;
  product?: OrderItemProduct | null;
  supplierProduct?: { product?: OrderItemProduct | null } | null;
}

export interface Order {
  id: number;
  order_number: string;
  type?: "CATALOG_PURCHASE" | "CUSTOM_PICKUP" | null;
  status: OrderStatus;
  payment_method?: string | null;
  supplier?: OrderSupplier | null;
  actual_price?: number | null;
  products_total?: number | null;
  total_fee?: number | null;
  courier_fee?: number | null;
  platform_fee?: number | null;
  vat_amount?: number | null;
  discount_amount?: number | null;
  payable_amount?: number | null;
  estemated_delivery_fee?: number | null;
  distance_m?: number | null;
  cancelled_reason?: string | null;
  cancellation_fee?: number | null;
  failure_reason?: string | null;
  admin_notes?: string | null;
  retry_count?: number | null;
  product_description?: string | null;
  product_image?: string | null;
  is_scheduled?: boolean | null;
  is_ready_for_pickup?: boolean | null;
  is_fixed_fee?: boolean | null;
  created_at: string;
  updated_at: string;
  delivered_at?: string | null;
  canceled_at?: string | null;
  order_collected_at?: string | null;
  offer_accepted_at?: string | null;
  proposals_deadline_at?: string | null;
  expires_at?: string | null;
  search_failed_at?: string | null;
  escalated_to_admin_at?: string | null;
  total_cost_price?: number | null;  // sum of cost_price × qty (supplier view)
  orderItems?: OrderItem[];
  customer?: OrderCustomer | null;
  courier?: OrderCourier | null;
  pickup_lat?: string | number | null;
  pickup_long?: string | number | null;
  delivery_lat?: string | number | null;
  delivery_long?: string | number | null;
  pickup_address_description?: string | null;
  delivery_address_description?: string | null;
}

export interface OrdersResponse {
  totalOrders: number;
  totalPages: number;
  orders: Order[];
}

export async function fetchOrders(params?: Record<string, string | number>) {
  const { page = 1, limit = 15, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<OrdersResponse>("/admin/orders", {
    params: { limit, skip, includes: "customer,courier.user,supplier.user", ...rest },
  });
  return res.data;
}

export async function fetchPendingOrders(): Promise<Order[]> {
  const res = await api.get<OrdersResponse>("/admin/orders", {
    params: { limit: 50, skip: 0, status: "PENDING" },
  });
  return res.data.orders ?? [];
}

// Fetches PENDING + IN_PROGRESS orders for the live map view
export async function fetchMapOrders(): Promise<Order[]> {
  const [pending, inProgress] = await Promise.all([
    api.get<OrdersResponse>("/admin/orders", {
      params: {
        limit: 100,
        skip: 0,
        status: "PENDING",
        includes: "customer,courier.user",
      },
    }),
    api.get<OrdersResponse>("/admin/orders", {
      params: {
        limit: 100,
        skip: 0,
        status: "IN_PROGRESS",
        includes: "customer,courier.user",
      },
    }),
  ]);
  return [...(pending.data.orders ?? []), ...(inProgress.data.orders ?? [])];
}

export async function fetchOrder(id: number): Promise<Order> {
  const res = await api.get<{ order: Order }>(`/admin/orders/${id}`);
  return res.data.order;
}

export async function fetchOrderDetail(id: number): Promise<Order> {
  const res = await api.get<{ order: Order }>(`/admin/orders/${id}`, {
    params: { includes: "orderItems.product" },
  });
  return res.data.order;
}

export async function cancelOrder(
  id: number,
  data: { cancelled_reason: string; cancellation_fee?: number },
) {
  const res = await api.post(`/admin/orders/${id}/cancel`, data);
  return res.data;
}

export async function fetchAssignedCourierIds(): Promise<number[]> {
  const res = await api.get<OrdersResponse>("/admin/orders", {
    params: {
      limit: 0,
      skip: 0,
      status: "IN_PROGRESS",
      includes: "courier=user_id",
    },
  });
  const orders = res.data?.orders || [];
  const ids = new Set<number>();
  orders.forEach((o: any) => {
    if (o.courier?.user_id) ids.add(o.courier.user_id);
  });
  return Array.from(ids);
}
