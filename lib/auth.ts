import api, { supplierApi } from "./api";
import { isDashboardRole, toAppRole, ROLE_LANDING } from "./rbac";
import {
  getSupplierAccessToken,
  setSupplierTokens,
  clearSupplierTokens,
} from "./supplier-tokens";

/** @deprecated Use getSupplierAccessToken from supplier-tokens */
export function getSupplierToken(): string | null {
  return getSupplierAccessToken();
}

export interface DashboardUser {
  id: number;
  full_name: string;
  email: string | null;
  phone: string | null;
  role: string;           // raw DB role name: "Admin" | "Seller" | "Supplier" | …
  personal_photo?: string | null;
}

// ── Token helpers ─────────────────────────────────────────────────────────────

/** Set cookie + localStorage so both middleware and axios interceptor can read it */
function setToken(token: string) {
  const expires = new Date();
  expires.setDate(expires.getDate() + 7);
  document.cookie = `token=${token}; path=/; expires=${expires.toUTCString()}; SameSite=Lax`;
  localStorage.setItem("token", token);
}

/** Set the role cookie so middleware can read it for server-side route guarding */
function setRoleCookie(role: string) {
  const expires = new Date();
  expires.setDate(expires.getDate() + 7);
  document.cookie = `role=${role}; path=/; expires=${expires.toUTCString()}; SameSite=Lax`;
}

function clearToken() {
  document.cookie = "token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT";
  document.cookie = "role=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT";
  localStorage.removeItem("token");
}

export function getToken(): string | null {
  const ls = typeof window !== "undefined" ? localStorage.getItem("token") : null;
  if (ls) return ls;
  if (typeof document !== "undefined") {
    const match = document.cookie.match(/(?:^|;\s*)token=([^;]+)/);
    return match ? decodeURIComponent(match[1]) : null;
  }
  return null;
}

export function isAuthenticated(): boolean {
  return !!getToken();
}

export function getCurrentUserId(): number | null {
  const token = getToken();
  if (!token) return null;
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    return typeof payload.userId === "number"
      ? payload.userId
      : typeof payload.id === "number"
      ? payload.id
      : null;
  } catch {
    return null;
  }
}

// ── User storage ──────────────────────────────────────────────────────────────

const USER_KEY = "dashboard_user";

export function setCurrentUser(user: DashboardUser) {
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function getCurrentUser(): DashboardUser | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as DashboardUser) : null;
  } catch {
    return null;
  }
}

export function getCurrentRole(): string {
  return getCurrentUser()?.role ?? "Unknown";
}

// ── Login / Logout ────────────────────────────────────────────────────────────

/** Detect whether the identifier is an email or a phone number */
function buildCredential(identifier: string, password: string) {
  const trimmed = identifier.trim();
  // Contains @ → treat as email; otherwise treat as phone
  return trimmed.includes("@")
    ? { email: trimmed, password }
    : { phone: trimmed, password };
}

export async function login(
  identifier: string,
  password: string,
): Promise<{ user: DashboardUser; redirectTo: string }> {
  const res = await api.post("/auth/login", buildCredential(identifier, password));
  const { token, user } = res.data as { token: string; user: DashboardUser };

  if (!isDashboardRole(user.role)) {
    throw new Error("Access denied: this account cannot access the dashboard");
  }

  setToken(token);
  setRoleCookie(user.role);
  setCurrentUser(user);

  // If supplier — also authenticate against the Supplier API (different JWT/bearer)
  if (user.role === "Supplier") {
    try {
      const cred = { ...buildCredential(identifier, password), device_token: "web" };
      const sRes = await supplierApi.post("/auth/login", cred);
      const sData = sRes.data?.data;
      const accessToken: string | undefined =
        sData?.accessToken ?? sRes.data?.token;
      const refreshToken: string | undefined = sData?.refreshToken;
      if (accessToken) setSupplierTokens(accessToken, refreshToken);
    } catch (err: unknown) {
      // non-fatal — supplier API login failure won't block dashboard access
      console.error("[auth] Supplier API login failed:", (err as { response?: { data?: unknown; status?: number } })?.response?.data ?? err);
    }
  }

  const appRole = toAppRole(user.role);
  const redirectTo = ROLE_LANDING[appRole];
  return { user, redirectTo };
}

export function logout() {
  clearToken();
  clearSupplierTokens();
  localStorage.removeItem("courierToken");
  localStorage.removeItem(USER_KEY);
  window.location.href = "/login";
}

// ── Courier token exchange ────────────────────────────────────────────────────

/** Exchange the admin JWT for a CourierAPIs-compatible token (cached in localStorage). */
export async function getCourierToken(): Promise<string> {
  const adminToken = getToken();
  if (!adminToken) throw new Error("Not authenticated");
  
  // Since tokens are now interchangeable and the backend handles both 'id' and 'userId' payloads,
  // we can use the admin token directly.
  localStorage.setItem("courierToken", adminToken);
  return adminToken;
}
