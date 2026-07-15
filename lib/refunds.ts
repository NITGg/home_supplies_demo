import { User } from "@/types/user";
import axiosInstance from "./axios";
import { Product } from "./products";

export type RefundStatus =
  | "REQUESTED"
  | "APPROVED"
  | "REJECTED"
  | "PROCESSING"
  | "COMPLETED"
  | "FAILED"
  | "CANCELLED";
export type FaultType = "SUPPLIER" | "COURIER";

export interface RefundItem {
  id: number;
  refund_id: number;
  order_item_id: number;
  quantity: number;
  amount: number;
  product?: Pick<Product, "name" | "name_ar" | "id">; // Adjust based on your structural OrderItem fields
}

export interface Refund {
  id: number;
  order_id: number;
  amount: number;
  currency: string;
  evidence_images: string | null;
  reason: string | null;
  status: RefundStatus;
  is_full_refund: boolean;
  requested_by_id: number | null;
  reviewed_by_id: number | null;
  created_at: string;
  updated_at: string;
  items: RefundItem[];
  requestedBy: Pick<User, "id" | "full_name" | "phone">;
  reviewedBy: Pick<User, "id" | "full_name" | "phone"> | null;
}

export interface FetchRefundsParams {
  page: number;
  limit: number;
  search?: string;
  status?: string;
  sortField?: string;
  sortDir?: "asc" | "desc";
}

export interface FetchRefundsResponse {
  refunds: Refund[];
  total: number;
  totalPages: number;
}

export interface ReviewRefundInput {
  status: "APPROVED" | "REJECTED";
  admin_notes?: string;
  fault_type: FaultType;
  penalty_amount?: number;
}

// Admin / System Fetching
export async function fetchAllRefunds(
  params: FetchRefundsParams,
): Promise<FetchRefundsResponse> {
  const { page, limit, search, status, sortField, sortDir } = params;

  // Calculate raw skip off the active layout window context
  const skip = (page - 1) * limit;

  // Build the dynamic payload matching FeatureApi specifications
  const queryPayload: Record<string, any> = {
    skip,
    limit,
    // API features matching sorting parameters format
    sort: sortField
      ? `${sortDir === "desc" ? "-" : ""}${sortField}`
      : undefined,
    // Explicit relation includes configuration requested string structure
    includes:
      "requestedBy=id-full_name-phone,reviewedBy=id-full_name-phone,items=id-refund_id-order_item_id-quantity-amount-product=name-name_ar-id",
  };

  if (search) {
    queryPayload.keyword = search;
  }

  if (status) {
    queryPayload.status = status;
  }

  const { data } = await axiosInstance.get<FetchRefundsResponse>("/refunds", {
    params: queryPayload,
  });
  return data;
}

// Admin / Review Action
export async function reviewRefundRequest(
  id: number,
  payload: ReviewRefundInput,
): Promise<Refund> {
  const { data } = await axiosInstance.put<Refund>(
    `/refunds/${id}/review`,
    payload,
  );
  return data;
}
