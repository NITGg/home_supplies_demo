import { Tx } from "@/types/prisma.types";
import { Prisma } from "@prisma/client";

type WalletUpdateInput = Prisma.WalletUpdateInput;

/**
 * Adjusts a wallet's balance and automatically creates a WalletEntry record.
 *
 * USE THIS instead of `tx.wallet.update({ data: { balance: { increment/decrement } } })`
 * everywhere wallet balance is being changed.
 *
 * @param tx       - Prisma transaction client (or prisma itself)
 * @param walletId - The wallet ID to adjust
 * @param amount   - Signed amount in cents: positive = credit, negative = debit
 * @param options  - Additional options like order_id, penalty_id, unpaid_commission_id, and skipEntry
 * @returns The updated wallet
 */
export async function adjustWalletBalance(
  tx: Tx,
  walletId: number,
  amount: number,
  options?: {
    order_id?: number;
    penalty_id?: number;
    unpaid_commission_id?: number;
    customer_coupon_id?: number;
    courier_coupon_id?: number;
    points_to_money?: number;
    notes?: string;
    skipEntry?: boolean;
  },
  extraData?: Omit<WalletUpdateInput, "balance">,
) {
  const updatedWallet = await tx.wallet.update({
    where: { id: walletId },
    data: { balance: { increment: amount }, ...extraData },
  });

  if (!options?.skipEntry) {
    await tx.walletEntry.create({
      data: {
        wallet_id: walletId,
        amount,
        order_id: options?.order_id,
        penalty_id: options?.penalty_id,
        unpaid_commission_id: options?.unpaid_commission_id,
        customer_coupon_id: options?.customer_coupon_id,
        courier_coupon_id: options?.courier_coupon_id,
        points_to_money: options?.points_to_money,
        notes: options?.notes,
      },
    });
  }

  return updatedWallet;
}
