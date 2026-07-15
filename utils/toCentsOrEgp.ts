/**
 * Converts a price value between cents and Egyptian Pounds (EGP).
 * @param value - The price value to convert. Can be a number, string, null, or undefined.
 * @param direction - Conversion direction: 'toEGP' (cents → EGP) or 'toCents' (EGP → cents). Defaults to 'toEGP'.
 * @returns Converted value as a string (e.g., "10.50" for EGP, "1050" for cents), or "-" if invalid.
 */
export const toCentsOrEgp = (
  value: string | number | null | undefined,
  direction: 'toEGP' | 'toCents' = 'toEGP'
): string => {
  if (value === null || value === undefined || value === "") return "-";

  if (direction === 'toEGP') {
    // Convert cents to EGP
    const numCents = typeof value === 'string' ? parseFloat(value) : value;
    if (isNaN(numCents)) return "-";
    return (numCents / 100).toFixed(2);
  } else {
    // Convert EGP to cents
    let egpAmount: number;

    if (typeof value === 'string') {
      // Remove any non-numeric characters except decimal point and minus sign
      const cleaned = value.replace(/[^0-9.-]/g, '');
      egpAmount = parseFloat(cleaned);
    } else {
      egpAmount = value;
    }

    if (isNaN(egpAmount)) return "-";
    // Multiply by 100 and round to avoid floating-point issues
    return Math.round(egpAmount * 100).toString();
  }
};