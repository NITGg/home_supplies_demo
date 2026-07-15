/**
 * Customer-side personal orders API (the supplier acting as a customer).
 * All endpoints hit the main API (`NEXT_PUBLIC_API_URL`) via the shared `api`
 * client — the same one the Create Order / shop checkout flows use.
 *
 * Monetary fields from the API are in **cents**; divide by 100 for EGP display.
 */
import api from "./api";
import { getCourierToken } from "./auth";

const COURIER_API = process.env.NEXT_PUBLIC_COURIER_API_URL;
const COURIER_BEARER_PREFIX = process.env.NEXT_PUBLIC_COURIER_BEARER_PREFIX ?? "Bearer";

export type PersonalOrderStatus =
  | "SCHEDULED"
  | "PENDING"
  | "IN_PROGRESS"
  | "DELIVERED"
  | "CANCELLED"
  | "EXPIRED"
  | "SEARCHING_FAILED";

export const ACTIVE_STATUSES: PersonalOrderStatus[] = [
  "SCHEDULED",
  "PENDING",
  "IN_PROGRESS",
];
export const HISTORY_STATUSES: PersonalOrderStatus[] = [
  "DELIVERED",
  "CANCELLED",
  "EXPIRED",
];

export interface OrderUser {
  id?: number;
  full_name?: string | null;
  phone?: string | null;
  personal_photo?: string | null;
}

export interface PersonalOrder {
  id: number;
  order_number: string;
  status: PersonalOrderStatus;
  type?: string | null;
  payment_method?: string | null;
  budget?: number | null; // cents
  courier_fee?: number | null; // cents
  platform_fee?: number | null; // cents
  total_fee?: number | null; // cents
  payable_amount?: number | null; // cents
  distance_m?: number | null;
  product_description?: string | null;
  product_image?: string | null;
  pickup_address_description?: string | null;
  pickup_lat?: number | string | null;
  pickup_long?: number | string | null;
  delivery_address_description?: string | null;
  delivery_lat?: number | string | null;
  delivery_long?: number | string | null;
  confirmation_otp?: string | null; // delivery confirmation code shown to courier
  is_scheduled?: boolean | null;
  created_at: string;
  scheduled_at?: string | null;
  proposals_deadline_at?: string | null;
  expires_at?: string | null;
  delivered_at?: string | null;
  canceled_at?: string | null;
  order_collected_at?: string | null;
  courier_id?: number | null;
  courier?: { id?: number; user?: OrderUser } | null;
  supplier?: { id?: number; user?: OrderUser } | null;
  /** Reviews the customer (this user) left about the courier — used to gate rating once. */
  customerReviews?: { id: number; rating?: number | null; comment?: string | null }[] | null;
}

export interface OrdersListResponse {
  orders: PersonalOrder[];
  totalOrders: number;
  totalPages: number;
}

const lc = (lang?: string) => (lang ? lang.toLowerCase() : undefined);

/** GET /orders — the current user's orders (active or history). */
export async function fetchMyOrders(params: {
  status?: string;
  skip?: number;
  limit?: number;
  lang?: string;
} = {}): Promise<OrdersListResponse> {
  const { status, skip = 0, limit = 50, lang } = params;
  const res = await api.get<OrdersListResponse>("/orders", {
    params: {
      includes: "courier=user,customerReviews",
      skip,
      limit,
      ...(status ? { status } : {}),
      ...(lang ? { lang: lc(lang) } : {}),
    },
  });
  return res.data;
}

// ── Proposals ────────────────────────────────────────────────────────────────
export type ProposalStatus = "PENDING" | "ACCEPTED" | "REJECTED";

/** Normalised proposal — money kept in cents, distances/times in m/seconds. */
export interface Proposal {
  id: number;
  status: ProposalStatus;
  courierFeeCents: number;
  platformFeeCents: number;
  discountFeeCents: number;
  distanceToPickupM: number;
  timeToPickupSec: number;
  createdAt: string | null;
  courierUserId: number | null;
  courierName: string;
  courierPhone: string;
  courierPhoto: string | null;
  courierRate: number | null;
  courierVehiclePlate: string | null;
  vehicleName: string;
  vehicleNameAr: string;
  vehicleIcon: string | null;
}

function pick<T = unknown>(obj: any, ...keys: string[]): T | undefined {
  if (!obj) return undefined;
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null) return obj[k] as T;
  }
  return undefined;
}
const num = (v: unknown, fallback = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
};

/** Accepts either camelCase (Flutter model) or snake_case (raw API) shapes. */
export function normalizeProposal(raw: any): Proposal {
  const courier = pick<any>(raw, "courier") ?? {};
  const courierUser = pick<any>(courier, "user") ?? {};
  const vehicle = pick<any>(raw, "vehicle") ?? {};

  return {
    id: num(pick(raw, "id")),
    status: (pick<string>(raw, "status") ?? "PENDING") as ProposalStatus,
    courierFeeCents: num(pick(raw, "courierFee", "courier_fee")),
    platformFeeCents: num(pick(raw, "platformFee", "platform_fee")),
    discountFeeCents: num(pick(raw, "discountFee", "discount_fee")),
    distanceToPickupM: num(pick(raw, "distanceToPickupM", "distance_to_pickup_m")),
    timeToPickupSec: num(pick(raw, "timeToPickup", "time_to_pickup")),
    createdAt: (pick<string>(raw, "createdAt", "created_at") ?? null) as string | null,
    courierUserId:
      (pick<number>(raw, "courierUserId", "courier_user_id") ??
        pick<number>(courierUser, "id") ??
        null) as number | null,
    courierName: (pick<string>(courierUser, "full_name", "fullName") ?? "—") as string,
    courierPhone: (pick<string>(courierUser, "phone") ?? "") as string,
    courierPhoto: (pick<string>(courierUser, "personal_photo", "personalPhoto") ?? null) as
      | string
      | null,
    courierRate: (pick<number>(courier, "courier_rate", "courierRate") ?? null) as number | null,
    courierVehiclePlate: (pick<string>(courier, "courier_vehicle_plate", "courierVehiclePlate") ??
      null) as string | null,
    vehicleName: (pick<string>(vehicle, "name") ?? "") as string,
    vehicleNameAr: (pick<string>(vehicle, "name_ar", "nameAr") ?? "") as string,
    vehicleIcon: (pick<string>(vehicle, "icon") ?? null) as string | null,
  };
}

/** Displayed total fee (cents) for a proposal, applying any courier-fee discount. */
export function proposalTotalCents(p: Proposal): number {
  const discountedCourier = Math.max(p.courierFeeCents - p.discountFeeCents, 0);
  return discountedCourier + p.platformFeeCents;
}

/** GET /orders/{orderId}/proposals */
export async function fetchProposals(orderId: number, lang?: string): Promise<Proposal[]> {
  const res = await api.get(`/orders/${orderId}/proposals`, {
    params: { ...(lang ? { lang: lc(lang) } : {}) },
  });
  const list: any[] =
    res.data?.proposals ?? res.data?.data?.proposals ?? res.data?.data ?? res.data ?? [];
  return (Array.isArray(list) ? list : []).map(normalizeProposal);
}

/** PUT /orders/{orderId}/proposals/{proposalId} */
export async function respondToProposal(
  orderId: number,
  proposalId: number,
  status: "ACCEPTED" | "REJECTED",
  lang?: string,
) {
  const res = await api.put(
    `/orders/${orderId}/proposals/${proposalId}`,
    { status },
    { params: { ...(lang ? { lang: lc(lang) } : {}) } },
  );
  return res.data;
}

// ── Cancel ───────────────────────────────────────────────────────────────────
export interface CancellationReason {
  id: number;
  role_id: number;
  reason_en: string;
  reason_ar: string;
}

/**
 * GET {NEXT_PUBLIC_API_URL}/admin/cancellation-reason/all-reasons?role_id=2
 * role_id=2 is the correct role for these customer-facing reasons — do not change it.
 */
export async function fetchCustomerCancellationReasons(): Promise<CancellationReason[]> {
  const res = await api.get<{ data?: { reasons?: CancellationReason[] } }>(
    "/admin/cancellation-reason/all-reasons",
    { params: { role_id: 2 } },
  );
  return res.data?.data?.reasons ?? [];
}

/** POST /orders/{orderId}/cancel */
export async function cancelOrder(orderId: number, cancelledReason: string, lang?: string) {
  const res = await api.post(
    `/orders/${orderId}/cancel`,
    { cancelled_reason: cancelledReason },
    { params: { ...(lang ? { lang: lc(lang) } : {}) } },
  );
  return res.data;
}

// ── Retry ────────────────────────────────────────────────────────────────────
/** POST /orders/{orderId}/retry */
export async function retryOrder(orderId: number, lang?: string) {
  const res = await api.post(
    `/orders/${orderId}/retry`,
    {},
    { params: { ...(lang ? { lang: lc(lang) } : {}) } },
  );
  return res.data;
}

// ── Reviews ──────────────────────────────────────────────────────────────────
/** POST /customer-reviews — rate the courier for a delivered order. */
export async function submitCourierReview(input: {
  order_id: number;
  courier_id: number;
  rating: number;
  comment?: string;
}) {
  const res = await api.post("/customer-reviews", input);
  return res.data;
}

/** A single review row as returned by the courier review-status endpoint. */
export interface ReviewStatusReview {
  id: number;
  rating: number | null;
  comment: string | null;
  created_at: string;
  customer?: { id: number; full_name: string | null; personal_photo?: string | null } | null;
}

export interface ReviewStatus {
  reviewed_by_customer: boolean;
  reviewed_by_supplier: boolean;
  reviewed_by: string[];
  /** The review the customer (this user) left about the courier, if any. */
  customer_review: ReviewStatusReview | null;
  supplier_review: ReviewStatusReview | null;
}

/**
 * GET {COURIER_API}/review/review-status/{orderId}/{courierId}
 * Tells whether this order/courier pair has already been reviewed by the
 * customer and/or supplier. Lives on the Courier API (not the main `api`),
 * so it uses the courier bearer token like the chat client.
 */
export async function fetchReviewStatus(
  orderId: number,
  courierId: number,
): Promise<ReviewStatus> {
  const token = await getCourierToken();
  const res = await fetch(`${COURIER_API}/review/review-status/${orderId}/${courierId}`, {
    headers: { Authorization: `${COURIER_BEARER_PREFIX} ${token}` },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body?.message ?? `Request failed: ${res.status}`);
  }
  const json = await res.json();
  return json?.data as ReviewStatus;
}

/** POST /customer/points/give-points-to-courier/{courierUserId} */
export async function giveCourierPoints(courierUserId: number) {
  const res = await api.post(`/customer/points/give-points-to-courier/${courierUserId}`);
  return res.data;
}

// ── Refunds ──────────────────────────────────────────────────────────────────
export interface RefundReason {
  id: number;
  reason_en: string;
  reason_ar: string;
}

/** GET /refund-reasons */
export async function fetchRefundReasons(lang?: string): Promise<RefundReason[]> {
  const res = await api.get("/refund-reasons", {
    params: { ...(lang ? { lang: lc(lang) } : {}) },
  });
  return res.data?.refundReasons ?? res.data?.data?.refundReasons ?? res.data?.data ?? [];
}

// ── Display helper ───────────────────────────────────────────────────────────
export function formatCents(cents?: number | null): string {
  return `${((cents ?? 0) / 100).toFixed(2)} EGP`;
}
