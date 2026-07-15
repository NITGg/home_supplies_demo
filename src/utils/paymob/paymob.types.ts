// ============ CONFIG ============

export type PaymobConfig = {
  API_KEY: string;
  SECRET_KEY: string;
  PUBLIC_KEY: string;
  INTEGRATION_ID: string;
  HMAC_SECRET: string;
  BASE_URL: string;
  NOTIFICATION_URL: string;
  REDIRECTION_URL: string;
  REDIRECTION_URL_SUCCESS_URL: string;
  REDIRECTION_URL_FAILED_URL: string;
};

// ============ INTENTION ============

export interface CreateIntentionRequest {
  amount: number; // in cents
  currency: string;
  payment_methods: (number | string)[];
  items: PaymentItem[];
  billing_data: BillingData;
  special_reference?: string; // Unique identifier for the transaction (e.g. Order ID)
  notification_url?: string; // Webhook URL where Paymob sends transaction updates (POST)
  redirection_url?: string; // URL to redirect the user after payment completion
}

export interface PaymentItem {
  name: string;
  amount: number; // in cents
  description?: string;
  quantity?: number;
}

export interface BillingData {
  first_name: string;
  last_name: string;
  email: string;
  phone_number: string;
  apartment?: string;
  floor?: string;
  street?: string;
  building?: string;
  city?: string;
  country?: string;
  state?: string;
}

export interface IntentionResponse {
  id: string;
  intention_order_id: number;
  client_secret: string;
  status: string;
}

// ============ CALLBACK ============

export interface TransactionCallback {
  obj: {
    id: number;
    success: boolean;
    pending: boolean;
    amount_cents: number;
    currency: string;
    order: { id: number };
    is_voided: boolean;
    is_refunded: boolean;
    is_3d_secure: boolean;
    integration_id: number;
    created_at: string;
    error_occured: boolean;
    has_parent_transaction: boolean;
    is_auth: boolean;
    is_capture: boolean;
    is_standalone_payment: boolean;
    owner: number;
    source_data: { type: string; pan: string; sub_type: string };
  };
  hmac: string;
}

// ============ QUICKLINK ============

export interface CreateQuickLinkRequest {
  amount_cents: number;
  reference_id: string;
  integration_id: number[];
  client_email: string;
  client_name: string;
  client_mobile: string;
  description?: string;
  expires_at?: string;
  is_live: boolean;
}

export interface QuickLinkResponse {
  id: number;
  link: string;
  amount_cents: number;
  reference_id: string;
}
