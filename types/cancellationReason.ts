export interface CancellationReason {
  id: number;
  role_id: number;
  reason_en: string;
  reason_ar: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface CancellationReasonFilter {
  id: string;
  role_id: string;
  reason_en: string;
  reason_ar: string;
  created_atFrom: string;
  created_atTo: string;
  updated_atFrom: string;
  updated_atTo: string;
}

export interface PaginatedCancellationReasonsResponse {
  totalReasons: number;
  totalPages: number;
  reasons: CancellationReason[];
}

export interface CreateCancellationReasonPayload {
  role_id: string;
  reason_en: string;
  reason_ar: string;
}

export interface UpdateCancellationReasonPayload {
  reason_en?: string;
  reason_ar?: string;
}
