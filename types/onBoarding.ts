export type OnBoardingTargetUser = "ALL" | "COURIER" | "CUSTOMER";

export interface OnBoardingItem {
  id: number;
  title: string;
  title_ar: string;
  content: string;
  content_ar: string;
  subtitle: string;
  subtitle_ar: string;
  image_url: string | null;
  sort_id: number;
  target_user: OnBoardingTargetUser;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface OnBoardingFilter {
  id: string;
  title: string;
  title_ar: string;
  content: string;
  content_ar: string;
  subtitle: string;
  subtitle_ar: string;
  sort_id: string;
  target_user: "" | OnBoardingTargetUser;
}

export interface PaginatedOnBoardingResponse {
  totalItems: number;
  totalPages: number;
  items: OnBoardingItem[];
}

export interface CreateOnBoardingPayload {
  title: string;
  title_ar: string;
  content: string;
  content_ar: string;
  subtitle: string;
  subtitle_ar: string;
  sort_id: number;
  target_user: OnBoardingTargetUser;
  image: File | null;
}

export interface UpdateOnBoardingPayload {
  title?: string;
  title_ar?: string;
  content?: string;
  content_ar?: string;
  subtitle?: string;
  subtitle_ar?: string;
  sort_id?: number;
  target_user?: OnBoardingTargetUser;
  image?: File | null;
}
