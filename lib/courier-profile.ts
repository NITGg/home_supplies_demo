import axios from "axios";
import { getCourierToken } from "./auth";

const COURIER_API = process.env.NEXT_PUBLIC_COURIER_API_URL;
const BEARER_PREFIX = process.env.NEXT_PUBLIC_COURIER_BEARER_PREFIX ?? "Bearer";

/** Courier record as returned by the Courier API profile endpoint. */
export interface CourierProfile {
  id: number;
  courier_office_id?: number | null;
  vehicle_id?: number | null;
  vehicle_plate?: string | null;
  national_id_number?: string | null;
  is_approved?: boolean;
  /** Stored in cents on the backend. */
  min_order_price?: number | null;
  max_order_price?: number | null;
  // Document images
  personal_photo?: string | null;
  national_id_photo_front?: string | null;
  national_id_photo_back?: string | null;
  vehicle_license_front?: string | null;
  vehicle_license_back?: string | null;
  courier_license_front?: string | null;
  courier_license_back?: string | null;
  courier_criminal_record?: string | null;
}

export interface CourierProfileUser {
  id: number;
  full_name: string;
  gender?: "MALE" | "FEMALE" | null;
  lang?: "AR" | "EN" | null;
  badge_id?: number | null;
  personal_photo?: string | null;
  courier?: CourierProfile | null;
}

async function authHeaders(
  extra?: Record<string, string>,
): Promise<Record<string, string>> {
  const token = await getCourierToken();
  return { Authorization: `${BEARER_PREFIX} ${token}`, ...(extra ?? {}) };
}

/** Fetch a courier's full profile (admin acting on a specific courier). */
export async function fetchCourierProfile(
  userId: number,
): Promise<CourierProfileUser> {
  const res = await axios.get(`${COURIER_API}/profile/get-profile/${userId}`, {
    headers: await authHeaders(),
  });
  return res.data?.data?.user ?? res.data?.user;
}

/**
 * Body for PATCH /profile/update-profile/:userId.
 * Mirrors the Courier API `updateProfileSchema`.
 * NOTE: `min_order_price` / `max_order_price` are in **cents**.
 */
export interface UpdateCourierProfileData {
  full_name?: string;
  gender?: "MALE" | "FEMALE";
  language?: "AR" | "EN";
  vehicle_id?: string;
  vehicle_plate?: string;
  badge_id?: number | null;
  courier_office_id?: number | null;
  lang?: "AR" | "EN";
  min_order_price?: number;
  max_order_price?: number;
}

export async function updateCourierProfile(
  userId: number,
  data: UpdateCourierProfileData,
) {
  const res = await axios.patch(
    `${COURIER_API}/profile/update-profile/${userId}`,
    data,
    { headers: await authHeaders() },
  );
  return res.data;
}

/**
 * PATCH /profile/update-documents/:userId — multipart/form-data.
 * Accepted file fields: personal_photo, national_id_photo_front,
 * national_id_photo_back, vehicle_license_front, vehicle_license_back,
 * courier_license_front, courier_license_back, courier_criminal_record.
 */
export async function updateCourierDocuments(userId: number, data: FormData) {
  const res = await axios.patch(
    `${COURIER_API}/profile/update-documents/${userId}`,
    data,
    { headers: await authHeaders({ "Content-Type": "multipart/form-data" }) },
  );
  return res.data;
}
