"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

// Offers are supplier product listings — managed in the Products page
export default function SupplierOffersPage() {
  const router = useRouter();
  useEffect(() => { router.replace("/supplier/products"); }, [router]);
  return null;
}
