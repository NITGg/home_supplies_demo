import { parsePhoneNumberFromString } from "libphonenumber-js";
import { z } from "zod";

export type PhoneNormalizeOptions = {
  defaultCountry?: "EG"; // you can widen later
};

export function normalizePhone(
  input: string,
  opts: PhoneNormalizeOptions = {},
): string {
  const defaultCountry = opts.defaultCountry ?? "EG";

  const raw = String(input ?? "").trim();
  if (!raw) throw new Error("INVALID_PHONE");

  // If already international format
  if (raw.startsWith("+")) {
    const parsed = parsePhoneNumberFromString(raw);
    if (!parsed?.isValid()) throw new Error("INVALID_PHONE");
    return parsed.number; // E.164
  }

  // If user forgot +20 (assume Egypt national format)
  // parsePhoneNumberFromString without + uses defaultCountry rules
  const parsed = parsePhoneNumberFromString(raw, defaultCountry);
  if (!parsed?.isValid()) throw new Error("INVALID_PHONE");

  return parsed.number; // will include +20
}

export const zPhoneEG = z.string().transform((val, ctx) => {
  try {
    return normalizePhone(val, { defaultCountry: "EG" });
  } catch {
    ctx.addIssue({
      code: "custom",
      message: "common:errors.phone_invalid",
    });
    return z.NEVER;
  }
});
