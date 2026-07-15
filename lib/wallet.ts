import api from "./api";

export interface Wallet {
  id: number;
  user_id?: number | null;
  owner_type?: string | null;
  balance: number;
  points?: number | null;
  status?: string | null;
  freeze_reason?: string | null;
  frozen_at?: string | null;
  created_at: string;
  updated_at: string;
  user?: { id: number; full_name: string; phone: string } | null;
}
export interface WalletsResponse {
  wallets: Wallet[];
  pagination: { total: number; total_pages: number };
}

export interface WalletTransaction {
  id: number;
  wallet_id: number;
  order_id?: number | null;
  type: string;
  status: string;
  amount: number;
  description?: string | null;
  reject_reason?: string | null;
  created_at: string;
  updated_at: string;
}
export interface TransactionsResponse {
  transactions: WalletTransaction[];
  pagination: { total: number; total_pages: number };
}

export interface WalletPenalty {
  id: number;
  user_id: number;
  created_by?: number | null;
  amount: number;
  reason: string;
  is_paid: boolean;
  paid_at?: string | null;
  is_waived: boolean;
  waived_at?: string | null;
  waived_by?: number | null;
  created_at: string;
  user?: { id: number; full_name: string; phone: string } | null;
}
export interface PenaltiesResponse {
  penalties: WalletPenalty[];
  pagination: { total: number; total_pages: number };
}

export async function fetchWallets(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: WalletsResponse }>(
    "/admin/wallet/wallets",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}
export async function fetchTransactions(
  params?: Record<string, string | number>,
) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: TransactionsResponse }>(
    "/admin/wallet/transactions",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}
export async function fetchPenalties(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: PenaltiesResponse }>(
    "/admin/wallet/penalties",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}
export async function freezeWallet(walletId: number, freeze_reason: string) {
  const res = await api.post(`/admin/wallet/freeze/${walletId}`, {
    freeze_reason,
  });
  return res.data;
}
export async function unfreezeWallet(walletId: number) {
  const res = await api.post(`/admin/wallet/unfreeze/${walletId}`);
  return res.data;
}
export async function adjustBalance(data: {
  wallet_id: number;
  type: "MANUAL_INCREASE" | "MANUAL_DECREASE";
  amount: number;
  description: string;
  related_order_id?: number;
}) {
  const res = await api.post("/admin/wallet/adjust-balance", data);
  return res.data;
}
export async function applyPenalty(
  userId: number,
  data: { amount: number; reason: string },
) {
  const res = await api.post(`/admin/wallet/apply-penalty/${userId}`, data);
  return res.data;
}
export async function waivePenalty(penaltyId: number) {
  const res = await api.post(`/admin/wallet/waive-penalty/${penaltyId}`);
  return res.data;
}

export interface WalletEscrow {
  id: number;
  order_id?: number | null;
  wallet_id: number;
  held_amount: number;
  created_at: string;
  updated_at: string;
}
export interface EscrowsResponse {
  escrows: WalletEscrow[];
  pagination: { total: number; total_pages: number };
}

export interface PaymentMethod {
  id: number;
  user_id: number;
  method_type: string;
  provider?: string | null;
  display_name?: string | null;
  instapay_number?: string | null;
  mobile_wallet_number?: string | null;
  is_default: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
  user?: { id: number; full_name: string; phone: string } | null;
}
export interface PaymentMethodsResponse {
  paymentMethods: PaymentMethod[];
  pagination: { total: number; total_pages: number };
}

export interface UnpaidCommission {
  id: number;
  order_id?: number | null;
  user_id: number;
  amount: number;
  is_paid: boolean;
  created_at: string;
  paid_at?: string | null;
  user?: { id: number; full_name: string; phone: string } | null;
}
export interface UnpaidCommissionsResponse {
  unpaidCommissions: UnpaidCommission[];
  pagination: { total: number; total_pages: number };
}

export interface PlatformWallet {
  id: number;
  user_id?: number | null;
  balance: number;
  platform_money?: number;
  platform_earnings?: number;
  status?: string | null;
  created_at: string;
  updated_at: string;
}

export async function fetchEscrows(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: EscrowsResponse }>(
    "/admin/wallet/escrows",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}

export async function fetchPaymentMethods(
  params?: Record<string, string | number>,
) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: PaymentMethodsResponse }>(
    "/admin/wallet/paymentMethods",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}

export async function fetchUnpaidCommissions(
  params?: Record<string, string | number>,
) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const res = await api.get<{ data: UnpaidCommissionsResponse }>(
    "/admin/wallet/unpaidCommissions",
    { params: { page, limit, ...rest } },
  );
  return res.data.data;
}

export async function fetchPlatformWallet() {
  const res = await api.get<{ data: { wallet: PlatformWallet } }>(
    "/admin/wallet/get-platform-wallet-record",
  );
  return res.data.data?.wallet ?? null;
}

export async function createPlatformWalletRecord(user_id: number) {
  const res = await api.post("/admin/wallet/create-platform-wallet-record", {
    user_id,
  });
  return res.data;
}

export async function incPlatformWalletBalance(data: {
  amount: number;
  description: string;
}) {
  const res = await api.patch(
    "/admin/wallet/inc-balance-platform-wallet-record",
    data,
  );
  return res.data;
}

export async function decPlatformWalletBalance(data: {
  amount: number;
  description: string;
}) {
  const res = await api.patch(
    "/admin/wallet/dec-balance-platform-wallet-record",
    data,
  );
  return res.data;
}

export async function changePlatformWalletUserId(user_id: number) {
  const res = await api.patch(
    "/admin/wallet/change-userId-platform-wallet-record",
    { user_id },
  );
  return res.data;
}

export async function settlingBalance(
  data: { target_user_id?: number; target_owner_type?: string } = {},
) {
  const res = await api.post("/admin/wallet/settling-balance", data);
  return res.data;
}

export interface WalletEntry {
  id: number;
  wallet_id: number;
  amount: number;
  order_id?: number | null;
  penalty_id?: number | null;
  unpaid_commission_id?: number | null;
  customer_coupon_id?: number | null;
  courier_coupon_id?: number | null;
  points_to_money?: string | null;
  notes?: string | null;
  is_settled: boolean;
  settled_at?: string | null;
  settlement_id?: number | null;
  created_at: string;
  wallet?: {
    user_id: any;
    owner_type: any;
    balance: any;
    status: any;
    platform_money: any;
    user?: {
      id: number;
      full_name: string;
      phone: string;
    } | null;
  } | null;
  settlement?: any;
  order?: any;
  penalty?: any;
  unpaidCommission?: any;
  customerCoupon?: any;
  courierCoupon?: any;
}

export interface WalletEntriesResponse {
  walletEntries: WalletEntry[];
  totalWalletEntry: number;
  totalPages: number;
}

export async function fetchWalletEntries(params?: Record<string, string | number | string[]>) {
  const res = await api.get<{ data: WalletEntriesResponse }>(
    "/admin/wallet/settlement-report",
    { params }
  );
  return res.data.data;
}
