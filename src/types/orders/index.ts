import { OrderProposal } from "@prisma/client";
import { Decimal } from "@prisma/client/runtime/client";

export interface RawProposalRow extends OrderProposal {
  user_id: number;
  full_name: string;
  phone: string;
  personal_photo: string | null;
  vehicle_plate: string | null;
  v_id: number | null;
  v_name: string | null;
  v_name_ar: string | null;
  v_price_per_km: number | null;
  v_icon: string | null;
  v_min_delivery_fee: Decimal;
  // New Vehicle Fields
  v_fee_base_distance_km: number;
  v_fee_extra_platform_per_km: number;
  v_fee_extra_courier_per_km: number;
  v_peak_time_fee_ratio: number;
  // Courier Coupon Info
  courier_active_bonus_percent: number | null;
  // Stats
  avg_rating: string | number;
  review_count: bigint | number;
  badge_ratio: number | null;
  badge_id: number | null;
}
