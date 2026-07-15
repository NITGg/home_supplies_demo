import axios from "axios";
import { getCourierToken } from "./auth";

const COURIER_API = process.env.NEXT_PUBLIC_COURIER_API_URL;

/**
 * Register a new courier against the CourierAPIs service.
 * Expects a multipart/form-data payload (text fields + document images).
 */
export async function registerCourier(formData: FormData) {
  const token = await getCourierToken();
  const res = await axios.post(`${COURIER_API}/auth/register`, formData, {
    headers: {
      Authorization: `${process.env.NEXT_PUBLIC_COURIER_BEARER_PREFIX ?? "Bearer"} ${token}`,
      "Content-Type": "multipart/form-data",
    },
  });
  return res.data;
}
