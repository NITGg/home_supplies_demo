import { NextRequest, NextResponse } from "next/server";
import { canAccess, toAppRole, ROLE_LANDING } from "@/lib/rbac";

const PUBLIC_PATHS = ["/login"];

export function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Always allow public paths
  if (PUBLIC_PATHS.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }

  // ── 1. Auth check: token cookie must exist ──────────────────────────────────
  const token = req.cookies.get("token")?.value;
  if (!token) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  // ── 2. Role check: role cookie written at login time ───────────────────────
  const rawRole = req.cookies.get("role")?.value;
  if (!rawRole) {
    // Role cookie not yet set (first load after old session).
    // Let the client-side RoleGuard handle it.
    return NextResponse.next();
  }

  const role = toAppRole(rawRole);

  // If the role isn't a valid dashboard role, bounce to login
  if (role === "Unknown") {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  // If the role can't access this path, redirect to the role's landing page
  if (!canAccess(role, pathname)) {
    const url = req.nextUrl.clone();
    url.pathname = ROLE_LANDING[role];
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|api/).*)"],
};
