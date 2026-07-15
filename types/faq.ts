export type FaqTargetUser = "ALL" | "COURIER" | "CUSTOMER";
export type FaqLanguage = "EN" | "AR";

export interface FaqItem {
  id: number;
  question: string;
  answer: string;
  language: FaqLanguage;
  created_at: string;
  updated_at: string;
  is_active: boolean;
  sort_id: number;
  target_user: FaqTargetUser;
}

export interface FaqFilter {
  id?: string;
  question?: string;
  answer?: string;
  sort_id?: string;
  target_user?: "" | FaqTargetUser;
  is_active?: "" | "true" | "false";
  created_from?: string;
  created_to?: string;
  updated_from?: string;
  updated_to?: string;
}

export interface PaginatedFaqResponse {
  totalFaqs: number;
  totalPages: number;
  faqs: FaqItem[];
}

export interface CreateFaqPayload {
  question: string;
  answer: string;
  language: FaqLanguage;
  target_user: FaqTargetUser;
  is_active: boolean;
  sort_id: number;
}

export interface UpdateFaqPayload {
  question?: string;
  answer?: string;
  language?: FaqLanguage;
  is_active?: boolean;
  sort_id?: number;
  target_user?: FaqTargetUser;
}
