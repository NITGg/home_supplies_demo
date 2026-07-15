import axios, { type AxiosError, type InternalAxiosRequestConfig } from "axios";
import {
  getSupplierAccessToken,
  getSupplierRefreshToken,
  setSupplierAccessToken,
  clearSupplierTokens,
} from "./supplier-tokens";

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: { "Content-Type": "application/json" },
});

export const supplierApi = axios.create({
  baseURL: process.env.NEXT_PUBLIC_SUPPLIER_API_URL,
});

const supplierBaseURL = process.env.NEXT_PUBLIC_SUPPLIER_API_URL ?? "";

/** Bare client for refresh — avoids supplierApi interceptors (infinite loop). */
const supplierRefreshClient = axios.create({ baseURL: supplierBaseURL });

let supplierRefreshInFlight: Promise<string> | null = null;

function isSupplierAuthRoute(url?: string): boolean {
  if (!url) return false;
  return url.includes("/auth/login") || url.includes("/auth/refresh-token");
}

async function refreshSupplierAccessToken(): Promise<string> {
  const refreshToken = getSupplierRefreshToken();
  if (!refreshToken) throw new Error("No supplier refresh token");

  const res = await supplierRefreshClient.post<{
    data?: { accessToken?: string };
    accessToken?: string;
  }>(
    "/auth/refresh-token",
    {},
    { headers: { Authorization: `Bearer ${refreshToken}` } },
  );

  const accessToken =
    res.data?.data?.accessToken ?? res.data?.accessToken;
  if (!accessToken) throw new Error("Refresh response missing accessToken");

  setSupplierAccessToken(accessToken);
  return accessToken;
}

function getOrRefreshSupplierAccessToken(): Promise<string> {
  if (!supplierRefreshInFlight) {
    supplierRefreshInFlight = refreshSupplierAccessToken().finally(() => {
      supplierRefreshInFlight = null;
    });
  }
  return supplierRefreshInFlight;
}

function redirectSupplierToLogin() {
  if (typeof window === "undefined") return;
  if (window.location.pathname.startsWith("/login")) return;
  clearSupplierTokens();
  window.location.href = "/login";
}

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  // localStorage is the most reliable client-side source
  const ls = localStorage.getItem("token");
  if (ls) return ls;
  // Fallback: parse document.cookie
  const match = document.cookie.match(/(?:^|;\s*)token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : null;
}

function clearToken() {
  if (typeof window === "undefined") return;
  localStorage.removeItem("token");
  document.cookie = "token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT";
}

/** Public auth routes that must NOT carry an existing Bearer token. */
function isPublicAuthRoute(url?: string): boolean {
  if (!url) return false;
  return (
    url.includes("/auth/register") ||
    url.includes("/auth/verify-account") ||
    url.includes("/auth/request-verification") ||
    url.includes("/auth/google/verify")
  );
}

api.interceptors.request.use((config) => {
  if (!isPublicAuthRoute(config.url)) {
    const token = getToken();
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  // Send a clean 2-letter language code so the backend's i18next middleware
  // sets req.language to "en" or "ar" (not "en-us" which breaks Prisma).
  const lang = (typeof window !== "undefined" && localStorage.getItem("admin_lang")) || "EN";
  config.headers["Accept-Language"] = lang.toLowerCase(); // "en" or "ar"
  return config;
});

supplierApi.interceptors.request.use((config) => {
  if (isSupplierAuthRoute(config.url)) return config;
  const supplierToken = getSupplierAccessToken();
  const token = supplierToken ?? getToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

supplierApi.interceptors.response.use(
  (res) => res,
  async (err: AxiosError) => {
    const status = err.response?.status;
    const original = err.config as InternalAxiosRequestConfig & { _supplierRetry?: boolean };

    console.error(
      "[supplierApi] error",
      status,
      original?.url,
      err.response?.data,
    );

    // Backend currently returns 500 (not 401) for expired tokens, with
    // `message: "jwt expired"`. Treat that as an auth failure so refresh fires.
    const data = err.response?.data as { message?: string } | undefined;
    const isExpiredToken =
      status === 401 ||
      (status === 500 && data?.message === "jwt expired");

    if (
      !isExpiredToken ||
      !original ||
      original._supplierRetry ||
      isSupplierAuthRoute(original.url)
    ) {
      return Promise.reject(err);
    }

    const refreshToken = getSupplierRefreshToken();
    if (!refreshToken) {
      redirectSupplierToLogin();
      return Promise.reject(err);
    }

    original._supplierRetry = true;

    try {
      const newAccessToken = await getOrRefreshSupplierAccessToken();
      original.headers.Authorization = `Bearer ${newAccessToken}`;
      return supplierApi(original);
    } catch (refreshErr) {
      console.error("[supplierApi] refresh failed:", refreshErr);
      redirectSupplierToLogin();
      return Promise.reject(refreshErr);
    }
  },
);

api.interceptors.response.use(
  (res) => res,
  (err) => {
    // Don't redirect on /login — 401 there means wrong credentials, not expired session
    if (
      err.response?.status === 401 &&
      typeof window !== "undefined" &&
      !window.location.pathname.startsWith("/login")
    ) {
      clearToken();
      window.location.href = "/login";
    }
    return Promise.reject(err);
  },
);

export default api;
