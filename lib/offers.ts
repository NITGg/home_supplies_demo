import api from "./api";

export type OfferType = "PERCENT" | "FIXED_CENTS";

export interface Offer {
  id: number;
  supplier_product_id: number;
  offer_type: OfferType | null;
  offer_value: number | null;
  start_date: string | null;
  end_date: string | null;
  is_active: boolean | null;
  created_at: string;
  updated_at?: string;
  deleted_at?: string | null;
}

export interface OfferPayload {
  supplier_product_id: number;
  offer_type: OfferType;
  offer_value: number;
  start_date: string;   // required by API schema
  end_date: string;     // required by API schema, must be after start_date
  is_active?: boolean;
}

export async function fetchOffersBySpId(supplierProductId: number): Promise<Offer[]> {
  const res = await api.get("/offers", {
    params: { supplier_product_id: supplierProductId, limit: 9999 },
  });
  const d = res.data;
  if (Array.isArray(d)) return d;
  if (Array.isArray(d?.offers)) return d.offers;
  if (Array.isArray(d?.data)) return d.data;
  return [];
}

export async function createOffer(payload: OfferPayload) {
  const res = await api.post("/offers", payload);
  return res.data;
}

export async function updateOffer(id: number, payload: Partial<Omit<OfferPayload, "supplier_product_id">>) {
  const res = await api.put(`/offers/${id}`, payload);
  return res.data;
}

export async function deleteOffer(id: number) {
  const res = await api.delete(`/offers/${id}`);
  return res.data;
}
