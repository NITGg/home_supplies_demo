// ─── EasyKash API types ───────────────────────────────────────────────────────

export interface EasykashPayRequest {
  amount: number;         // in EGP (not piastres)
  currency: string;       // "EGP"
  name: string;
  email: string;
  mobile: string;
  redirectUrl: string;    // where user is sent after payment
  customerReference: number; // our internal transaction ID
  paymentOptions?: number[];  // optional list of payment method IDs
  cashExpiry?: number;        // hours; default 3
}

export interface EasykashPayResponse {
  redirectUrl: string;    // https://www.easykash.net/DirectPayV1/{productCode}
}

// Status values from Payment Inquiry endpoint
export type EasykashPaymentStatus =
  | "PAID"
  | "FAILED"
  | "PENDING"
  | "EXPIRED"
  | "CANCELED"
  | "REFUNDED"
  | "DELIVERED"
  | "NEW";

// Webhook callback payload sent to our configured callback URL
export interface EasykashCallbackPayload {
  ProductCode:       string;
  PaymentMethod:     string;
  ProductType:       string;
  Amount:            string;   // EGP, e.g. "50.5"
  BuyerEmail:        string;
  BuyerMobile:       string;
  BuyerName:         string;
  Timestamp:         string;
  status:            EasykashPaymentStatus;
  voucher?:          string;
  easykashRef:       string;   // EasyKash transaction reference — store for audit
  VoucherData?:      string;
  customerReference: string;   // our transactionId (number sent as string back)
  signatureHash:     string;   // HMAC-SHA512 for verification
}

// Inquiry response
export interface EasykashInquiryResponse {
  PaymentMethod: string;
  Amount:        string;
  BuyerEmail:    string;
  BuyerMobile:   string;
  BuyerName:     string;
  status:        EasykashPaymentStatus;
  voucher?:      string;
  easykashRef:   string;
}
