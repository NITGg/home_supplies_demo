import { Prisma } from "@prisma/client";

/**
 * Decimal → cents (Int)
 * Example: 10.25 → 1025
 */
export function decimalToCents(value: Prisma.Decimal): number {
  return Math.round(Number(value) * 100);
}

/**
 * cents (Int) → Decimal-like number
 * Example: 1025 → 10.25
 */
export function centsToNumber(cents: number): number {
  return cents / 100;
}
