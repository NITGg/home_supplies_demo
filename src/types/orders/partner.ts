import { Decimal } from "@prisma/client/runtime/client";

export interface PartnerFeeResult {
  totalFee: Decimal;
  vatAmount: Decimal;
  totalFeeWithVat: Decimal;
  courierFeeAmount: Decimal;
  appFeeAmount: Decimal;
  partnerFeeAmount: Decimal;
  app_ratio: number;
  courier_ratio: number;
  partner_ratio: number;
  contractVehicleId: number;
}

export type VehicleData = {
  id: number;
  name: string;
  name_ar: string;
};

export type ContractVehicle = {
  id: number;
  vehicle_id: number;
  min_fee: Decimal;
  m_min: number;
  m_max: number;
  extra_m_price: Decimal;
  fee_per_m: Decimal;
  splits: Array<{
    badge_id: number;
    app_ratio: number;
    courier_ratio: number;
    partner_ratio: number;
  }>;
  // Optional property for the relation
  vehicle?: VehicleData;
};

export type PartnerContract<V = false> = {
  id: number;
  is_active: boolean;
  start_date: Date;
  end_date: Date;
  can_receive_courier_offers: boolean;
  vehicle_configs: (ContractVehicle &
    (V extends true ? { vehicle: VehicleData } : {}))[];
};

export interface PartnerPayoutData {
  courier_fee: Decimal;
  platform_fee: Decimal;
  partner_fee: Decimal;
  vat_amount: Decimal;
  total_fee: Decimal;
  partner_app_ratio: number;
  partner_courier_ratio: number;
  partner_ratio: number;
}

export interface PartnerVehicleQuote {
  vehicle_id: number;
  contract_vehicle_id: number;
  name: string;
  name_ar: string;
  // Fee breakdown (mirrors order fields)
  total_fee: number;
  courier_fee: number;
  platform_fee: number;
  partner_fee: number;
  vat_amount: number;
  // What the partner actually pays (delivery fee + goods budget)
  payable_amount: number;
  // Convenience flags
  is_cheapest: boolean;
  is_selected: boolean;
}

export interface PartnerOrderPreview {
  distance_m: number;
  budget: number;
  // The cheapest eligible vehicle — what would be auto-selected on create
  recommended: PartnerVehicleQuote;
  // The explicitly requested vehicle (null if none requested)
  selected: PartnerVehicleQuote | null;
  // All eligible vehicles with their fees
  options: PartnerVehicleQuote[];
}