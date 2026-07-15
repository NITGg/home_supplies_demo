import { Order } from "@/types/order";
import { Wallet } from "@/types/user";
import { Vehicle } from "@/types/vehicle";

export type ExternalApp = {
  id: number;
  name: string;
  webhook_url: string | null;
  environment: "SANDBOX" | "PRODUCTION";
  is_active: boolean;
  partner_id: number | null;
  webhook_version: number;
  webhook_retry_count: number;
  client_id: string;
  client_secret: string;
  webhook_secret: string | null;
  created_at: Date;
  contracts: PartnerContract[];
  orders: Order[];
  wallet?: Wallet;
};

export type PartnerContract = {
  id: number;
  is_active: boolean;
  start_date: Date;
  end_date: Date;
  can_receive_courier_offers: boolean;
  external_app_id: number;
  vehicle_configs: PartnerContractVehicle[];
};

export type PartnerContractVehicle = {
  id: number;
  vehicle_id: number;
  min_fee: string | number;
  m_min: number;
  m_max: number;
  fee_per_m: string | number;
  extra_m_price: string | number;
  contract_id: number;
  splits: PartnerFeeSplit[];
  vehicle: Vehicle;
};

export type PartnerFeeSplit = {
  badge_id: number;
  app_ratio: number;
  courier_ratio: number;
  partner_ratio: number;
  id: number;
  contract_vehicle_id: number;
};
