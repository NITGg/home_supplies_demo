const SUPPLIER_ACCESS_KEY = "supplier_token";
const SUPPLIER_REFRESH_KEY = "supplier_refresh_token";

export function getSupplierAccessToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(SUPPLIER_ACCESS_KEY);
}

export function getSupplierRefreshToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(SUPPLIER_REFRESH_KEY);
}

export function setSupplierAccessToken(token: string) {
  if (typeof window !== "undefined") {
    localStorage.setItem(SUPPLIER_ACCESS_KEY, token);
  }
}

export function setSupplierTokens(accessToken: string, refreshToken?: string) {
  if (typeof window === "undefined") return;
  localStorage.setItem(SUPPLIER_ACCESS_KEY, accessToken);
  if (refreshToken) localStorage.setItem(SUPPLIER_REFRESH_KEY, refreshToken);
}

export function clearSupplierTokens() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(SUPPLIER_ACCESS_KEY);
  localStorage.removeItem(SUPPLIER_REFRESH_KEY);
}
