import { z } from "zod";

export const externalAppWalletRechargeInitSchema = z.object({
  amount_cents: z.coerce
    .number()
    .int("external_apps:errors.recharge_amount_invalid")
    .positive("external_apps:errors.recharge_amount_invalid"),
  redirection_url: z.string().trim().url().optional(),
  /** Which payment gateway to use. Defaults to "paymob" for backwards compat */
  provider: z.enum(["paymob", "kashier", "easykash"]).default("paymob"),
});

export type ExternalAppWalletRechargeInitInput = z.infer<
  typeof externalAppWalletRechargeInitSchema
>;
