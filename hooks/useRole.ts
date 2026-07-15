"use client";
import { useState, useEffect } from "react";
import { getCurrentUser, type DashboardUser } from "@/lib/auth";
import { toAppRole, type AppRole } from "@/lib/rbac";

export function useRole(): { user: DashboardUser | null; role: AppRole; isAdmin: boolean; isSeller: boolean; isSupplier: boolean; isCourierOffice: boolean } {
  const [user, setUser] = useState<DashboardUser | null>(null);

  useEffect(() => {
    setUser(getCurrentUser());

    // Re-read if storage changes (e.g. login in another tab)
    const onStorage = (e: StorageEvent) => {
      if (e.key === "dashboard_user") setUser(getCurrentUser());
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  const role = toAppRole(user?.role);
  return {
    user,
    role,
    isAdmin: role === "Admin",
    isSeller: role === "Seller",
    isSupplier: role === "Supplier",
    isCourierOffice: role === "CourierOffice",
  };
}
