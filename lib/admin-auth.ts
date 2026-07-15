import api from "./api";

/** Role ids used by the register/OTP account-creation flow. */
export const ADMIN_ROLE_ID = 1;
export const CUSTOMER_ROLE_ID = 3;

/** Normalize an Egyptian phone number to the +20XXXXXXXXXX format. */
export function normalizeEgPhone(raw: string): string {
  let p = raw.trim().replace(/[\s\-()]/g, "");
  if (!p) return p;
  if (p.startsWith("+20")) p = p.slice(3);
  else if (p.startsWith("0020")) p = p.slice(4);
  else if (p.startsWith("20")) p = p.slice(2);
  else if (p.startsWith("0")) p = p.slice(1);
  return `+20${p}`;
}

export interface RegisterAccountInput {
  full_name: string;
  phone: string;
  password: string;
  role_id: number;
}

/**
 * Register a new account manually.
 * email and badge_id are intentionally omitted — only role_id is forced.
 */
export async function registerAccount(input: RegisterAccountInput) {
  const body = {
    full_name: input.full_name,
    phone: normalizeEgPhone(input.phone),
    password: input.password,
    role_id: input.role_id,
  };
  console.log("[registerAccount] POST /auth/register", JSON.stringify(body));
  try {
    const res = await api.post("/auth/register", body);
    console.log("[registerAccount] SUCCESS:", res.status, JSON.stringify(res.data));
    return res.data;
  } catch (err: any) {
    console.error("[registerAccount] FAILED");
    console.error("[registerAccount] Status:", err?.response?.status);
    console.error("[registerAccount] Response data:", JSON.stringify(err?.response?.data));
    console.error("[registerAccount] Request URL:", err?.config?.url);
    console.error("[registerAccount] Request baseURL:", err?.config?.baseURL);
    console.error("[registerAccount] Request headers:", JSON.stringify(err?.config?.headers));
    throw err;
  }
}

/**
 * Register a new account with a Google id token.
 * badge_id is intentionally omitted — only role_id is forced.
 */
export async function registerAccountWithGoogle(idToken: string, roleId: number) {
  const res = await api.post("/auth/google/verify", {
    idToken,
    role_id: roleId,
  });
  return res.data;
}

export interface VerifyAccountInput {
  email?: string;
  phone?: string;
  code: string;
}

/** Verify a freshly-registered account with the OTP the user received. */
export async function verifyAccount(input: VerifyAccountInput) {
  const body: Record<string, string> = { code: input.code };
  if (input.email) body.email = input.email;
  if (input.phone) body.phone = input.phone;
  const res = await api.post("/auth/verify-account", body);
  return res.data;
}

export interface RequestVerificationInput {
  email?: string;
  phone?: string;
}

/** Re-send the verification OTP to the account's email or phone. */
export async function requestVerification(input: RequestVerificationInput) {
  const body: Record<string, string> = {};
  if (input.email) body.email = input.email;
  if (input.phone) body.phone = input.phone;
  const res = await api.post("/auth/request-verification", body);
  return res.data;
}
