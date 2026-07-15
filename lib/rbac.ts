/**
 * Role-Based Access Control (RBAC) for the Tawreedat dashboard.
 *
 * Role names come from the UserRole.name column in the DB:
 *   1 = Admin  |  4 = Seller  |  6 = Supplier  |  7 = CourierOffice
 *   CustomerSupport = future DB role
 */

export type AppRole = "Admin" | "Seller" | "Supplier" | "CourierOffice" | "CustomerSupport" | "Unknown";

// ── Landing page per role ─────────────────────────────────────────────────────
export const ROLE_LANDING: Record<AppRole, string> = {
  Admin:           "/categories",
  Seller:          "/support/orders",
  Supplier:        "/supplier/dashboard",
  CourierOffice:   "/office/couriers",
  CustomerSupport: "/support/orders",
  Unknown:         "/login",
};

// ── Shared pages accessible by all authenticated roles ────────────────────────
const SHARED_PATHS = [
  "/chat", "/couriers-map", "/articles", "/faqs", "/notifications",
];

// ── Which path prefixes each role can visit ───────────────────────────────────
export const ROLE_ALLOWED_PATHS: Record<AppRole, string[]> = {
  Admin:           ["*"],
  Seller:          ["/support", "/login", ...SHARED_PATHS],
  Supplier:        ["/supplier", "/login", ...SHARED_PATHS],
  CourierOffice:   ["/office", "/login", ...SHARED_PATHS],
  CustomerSupport: ["/support", "/login", ...SHARED_PATHS],
  Unknown:         ["/login"],
};

// ── Map the DB role string to AppRole ─────────────────────────────────────────
export function toAppRole(dbRole: string | null | undefined): AppRole {
  switch (dbRole) {
    case "Admin":           return "Admin";
    case "Seller":          return "Seller";
    case "Supplier":        return "Supplier";
    case "CourierOffice":   return "CourierOffice";
    case "CustomerSupport": return "CustomerSupport";
    default:                return "Unknown";
  }
}

/** Returns true if this role can access a given path */
export function canAccess(role: AppRole, path: string): boolean {
  const allowed = ROLE_ALLOWED_PATHS[role];
  if (allowed.includes("*")) return true;
  return allowed.some((prefix) => path.startsWith(prefix));
}

/** Dashboard-capable roles (can log into this dashboard at all) */
export const DASHBOARD_ROLES: AppRole[] = ["Admin", "Seller", "Supplier", "CourierOffice", "CustomerSupport"];

export function isDashboardRole(dbRole: string | null | undefined): boolean {
  return DASHBOARD_ROLES.includes(toAppRole(dbRole));
}
