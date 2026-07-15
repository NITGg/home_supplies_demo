import api from "@/lib/api";

import type { ExternalApp, PartnerFeeSplit } from "@/types/external-apps";

const BASE = "/external-apps";

// ─── Request Types ────────────────────────────────────────────────────────────

type SplitInput = Pick<
  PartnerFeeSplit,
  "badge_id" | "app_ratio" | "courier_ratio" | "partner_ratio"
>;

type VehicleInput = {
  vehicle_id: number;
  min_fee: number;
  m_min?: number;
  m_max: number;
  fee_per_m: number;
  extra_m_price: number;
  splits: SplitInput[];
};

type ContractInput = {
  start_date: string;
  end_date: string;
  can_receive_courier_offers?: boolean;
  vehicles?: VehicleInput[];
};

export type CreateExternalAppInput = {
  name: string;
  environment?: "SANDBOX" | "PRODUCTION";
  is_active?: boolean;
  webhook_url?: string | null;
  partner_id?: number | null;
  webhook_enabled?: boolean;
  webhook_version?: number;
  webhook_retry_count?: number;
  contract?: ContractInput;
};

export type UpdateExternalAppInput = Partial<CreateExternalAppInput> & {
  regenerate_client_id?: boolean;
  regenerate_client_secret?: boolean;
  regenerate_webhook_secret?: boolean;
};

type ListParams = {
  page?: number;
  limit?: number;
  keyword?: string;
  sort?: string;
  includes?: string;
  fields?: string;
};

// ─── Response Types ───────────────────────────────────────────────────────────

type ListResponse = {
  apps: ExternalApp[];
  totalCount: number;
  totalPages: number;
};

type CreateResponse = {
  message: string;
  app: ExternalApp;
  client_secret_raw: string;
};

type UpdateResponse = {
  message: string;
  app: ExternalApp;
  newSecretRaw?: string;
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function buildQuery(params: Record<string, unknown>): string {
  const q = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      q.set(key, String(value));
    }
  });

  const str = q.toString();
  return str ? `?${str}` : "";
}

// ─── CRUD ─────────────────────────────────────────────────────────────────────

export async function fetchExternalApps(
  params: ListParams = {},
): Promise<ListResponse> {
  const { page = 1, limit = 10, ...rest } = params;

  const skip = (page - 1) * limit;
  const query = buildQuery({
    limit,
    skip,
    ...rest,
  });

  const { data } = await api.get<ListResponse>(`${BASE}${query}`);
  return data;
}

export async function fetchExternalApp(
  id: number,
  params: Pick<ListParams, "fields" | "includes"> = {},
): Promise<ExternalApp> {
  const query = buildQuery(params);

  const { data } = await api.get<{ app: ExternalApp }>(`${BASE}/${id}${query}`);

  return data.app;
}

export async function createExternalApp(
  input: CreateExternalAppInput,
): Promise<CreateResponse> {
  const { data } = await api.post<CreateResponse>(BASE, input);
  return data;
}

export async function updateExternalApp(
  id: number,
  input: UpdateExternalAppInput,
): Promise<UpdateResponse> {
  const { data } = await api.put<UpdateResponse>(`${BASE}/${id}`, input);

  return data;
}

export async function deleteExternalApp(
  id: number,
): Promise<{ message: string }> {
  const { data } = await api.delete<{ message: string }>(`${BASE}/${id}`);

  return data;
}
