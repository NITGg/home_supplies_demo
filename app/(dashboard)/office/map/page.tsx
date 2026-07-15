"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

// Office map — reuses the global couriers-map but filtered by office
// The couriers-map page handles filtering via query params
export default function OfficeMapPage() {
  const router = useRouter();
  useEffect(() => { router.replace("/couriers-map"); }, [router]);
  return null;
}
