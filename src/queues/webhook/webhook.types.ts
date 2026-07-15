import { WebhookEventType } from "@prisma/client";

// webhook.types.ts
export interface WebhookPayloadBase {
  id?: string | number;
}

export interface WebhookJobData<
  T extends WebhookPayloadBase = WebhookPayloadBase,
> {
  webhookUrl: string;
  webhookSecret: string;
  payload: T;
  eventType: WebhookEventType; // use the enum, not loose string
  //   webhookEventId: string; // cuid from WebhookEvent.id
}

export interface WebhookJobResponse {
  status: number;
  statusText: string;
}

// Strong payload types per event
export interface WebhookOrderDeliveredPayload extends WebhookPayloadBase {
  id: number;
  order_number: string;
  status: "DELIVERED";
  delivered_at: string;
  total_fee: number;
  courier_fee: number;
  platform_fee: number;
  partner_fee: number;
}

export interface WebhookOrderCreatedPayload extends WebhookPayloadBase {
  id: number;
  order_number: string;
  status: "PENDING";
  created_at: string;
  total_fee: number;
  payable_amount: number;
  distance_m: number;
  vehicle_id: number | null;
}

export interface WebhookOrderExpiredPayload extends WebhookPayloadBase {
  id: number;
  expired_at: string;
}

// courier/src/queues/webhook/webhook.types.ts

export interface WebhookOfferSubmittedPayload extends WebhookPayloadBase {
  id: number; // The proposal ID
  proposal_id: number;
  courier_id: number;
  total_fee: number;
  courier_lat: number | null;
  courier_long: number | null;
  distance_to_pickup: number | null;
  estimated_arrival_at_pickup: number | null;
  status: string; // "PENDING"
  created_at: string;
}

export interface WebhookFixedFeeAcceptedPayload extends WebhookPayloadBase {
  id: number; // Order ID
  order_number: string;
  courier_id: number;
  status: "IN_PROGRESS";
  accepted_at: string;
  total_fee: number;
}

export interface WebhookFixedFeeRejectedPayload extends WebhookPayloadBase {
  id: number;
  proposal_id: number;
  courier_id: number;
  status: "REJECTED";
}

export interface WebhookOrderCollectedPayload extends WebhookPayloadBase {
  id: number;
  order_number: string;
  courier_id: number;
  status: "IN_PROGRESS";
  collected_at: string;
}

export interface WebhookOrderPriceReportedPayload extends WebhookPayloadBase {
  id: number;
  order_number: string;
  courier_id: number;
  original_budget: number;
  new_actual_price: number;
  status: "IN_PROGRESS";
  price_adjustment_status: "PENDING";
  reported_at: string;
}

export interface WebhookOrderCancelledPayload extends WebhookPayloadBase {
  id: number;
  order_number: string;
  status: "CANCELLED";
  reason: string;
  cancelled_at: string;
  cancelled_by_type: "COURIER";
}

export interface WebhookOrderPaymentConfirmedPayload
  extends WebhookPayloadBase {
  id: number;
  order_number: string;
  status: "PENDING" | "SCHEDULED";
  payable_amount: number;
  provider: "paymob" | "kashier" | "easykash";
  paid_at: string;
}

export interface WebhookWalletRechargedPayload extends WebhookPayloadBase {
  wallet_id: number;
  transaction_id: number;
  amount: number;
  balance: number;
  recharged_at: string;
}

// Add more as needed: WebhookOfferReceivedPayload, etc.
