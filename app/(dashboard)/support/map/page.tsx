"use client";
/**
 * Support → Live Map
 * Reuses the existing couriers-map page component wholesale.
 * The existing map already shows all online couriers with real-time locations.
 */
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function SupportMapPage() {
  // The full map implementation lives at /couriers-map — redirect there.
  // This keeps the seller in their nav context via the sidebar.
  const router = useRouter();
  useEffect(() => {
    router.replace("/couriers-map");
  }, [router]);
  return null;
}
