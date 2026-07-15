"use client";
import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useRole } from "@/hooks/useRole";
import { canAccess, ROLE_LANDING } from "@/lib/rbac";
import { Loader2 } from "lucide-react";

/**
 * Client-side fallback guard.
 * Middleware already handles server-side redirects when the `role` cookie is
 * present. This guard covers the case where the cookie hasn't been written yet
 * (legacy sessions) and provides a smooth loading state on first paint.
 */
export default function RoleGuard({ children }: { children: React.ReactNode }) {
  const { role, user } = useRole();
  const pathname = usePathname();
  const router = useRouter();

  // Track whether the client has hydrated (localStorage is available)
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => { setHydrated(true); }, []);

  useEffect(() => {
    if (!hydrated) return;   // wait for localStorage read
    if (!user) return;       // still loading / not logged in (middleware handles no-token)
    if (!canAccess(role, pathname)) {
      router.replace(ROLE_LANDING[role]);
    }
  }, [hydrated, role, user, pathname, router]);

  // Show spinner while hydrating OR while a redirect is in flight
  if (!hydrated || (user && !canAccess(role, pathname))) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-50">
        <Loader2 className="animate-spin text-indigo-600" size={32} />
      </div>
    );
  }

  return <>{children}</>;
}
