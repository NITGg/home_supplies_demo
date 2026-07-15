import { Tx } from "@/types/prisma.types";
import { adjustWalletBalance } from "./adjustWalletBalance";

export async function ensureWallet(
  tx: Tx,
  userId: number,
  ownerType: "CUSTOMER" | "COURIER",
) {
  return tx.wallet.upsert({
    where: { user_id: userId },
    update: {}, // keep existing
    create: { user_id: userId, owner_type: ownerType },
    select: {
      id: true,
      user_id: true,
      balance: true,
      points: true,
      owner_type: true,
      status: true,
    },
  });
}

export type WalletCreditTarget = "BALANCE" | "POINTS";
type BalanceTransactionType =
  | "TOPUP"
  | "WITHDRAWAL"
  | "ESCROW_HOLD"
  | "ESCROW_RELEASE"
  | "ESCROW_REMOVE"
  | "PLATFORM_COD_COMMISSION"
  | "PENALTY"
  | "WAIVE_PENALTY"
  | "COUPON_PURCHASE"
  | "MANUAL_INCREASE"
  | "MANUAL_DECREASE";

type BalanceTransactionStatus =
  | "PENDING"
  | "COMPLETED"
  | "FAILED"
  | "REJECTED"
  | "WAIVED";

type AddToWalletInput =
  | {
      target: "BALANCE";
      amount: number; // cents
      description?: string;
      type?: BalanceTransactionType; // pick what you like
      status?: BalanceTransactionStatus;
      orderId?: number;
      processedBy?: number;
      escrowId?: number;
    }
  | {
      target: "POINTS";
      points: number;
      // type?: PointsTransactionType;
      description?: string;
      orderId?: number;
      couponUsageId?: number;
      processedBy?: number;
    };

export async function addToWallet(
  tx: Tx,
  userId: number,
  input: AddToWalletInput,
) {
  if (input.target === "BALANCE") {
    const wallet = await tx.wallet.findUniqueOrThrow({
      where: { user_id: userId },
      select: { id: true },
    });

    await adjustWalletBalance(
      tx,
      wallet.id,
      input.amount > 0 ? input.amount : -Math.abs(input.amount),
      { order_id: input.orderId },
    );

    return await tx.transaction.create({
      data: {
        wallet_id: wallet.id,
        order_id: input.orderId,
        escrow_id: input?.escrowId,
        type: input.type ?? "ESCROW_RELEASE",
        status: input.status,
        amount: Number(input.amount),
        description: input.description,
        processed_by: input.processedBy,
      },
    });
  }

  // POINTS
  if (input.points <= 0) return;

  const wallet = await tx.wallet.update({
    where: { user_id: userId },
    data: { points: { increment: input.points } },
    select: { id: true },
  });

  // await tx.pointsTransaction.create({
  //   data: {
  //     wallet_id: wallet.id,
  //     type: input.type ?? "ORDER_REWARD",
  //     amount: input.points,
  //     description: input.description,
  //     order_id: input.orderId,
  //     coupon_usage_id: input.couponUsageId,
  //     processed_by: input.processedBy,
  //   },
  //   select: { id: true },
  // });
}

/**
 * Assumption:
 * - paymentAmountCents is in cents
 * - badge.ratio is "points per 1 major currency unit" (e.g., per 1 EGP)
 */
export async function calcRewardPointsFromBadge(
  tx: Tx,
  userId: number,
  paymentAmountCents: number,
) {
  const user = await tx.user.findUnique({
    where: { id: userId },
    select: {
      badge: { select: { ratio: true } },
    },
  });

  const ratio = Number(user?.badge?.ratio ?? 0);

  if (ratio <= 0) return 0;
  if (paymentAmountCents <= 0) return 0;
  console.log("paymentAmountCents", paymentAmountCents);
  console.log("paymentAmountCents / 100", paymentAmountCents / 100);

  const paymentMajor = paymentAmountCents / 100;
  console.log("points", Math.floor(paymentMajor * (ratio / 100)));
  const points = Math.floor(paymentMajor * (ratio / 100));

  return points;
}

export async function getPlatformWalletOrThrow(tx: Tx) {
  const platformWallet = await tx.wallet.findFirst({
    where: { owner_type: "PLATFORM", deleted_at: null },
    orderBy: { id: "asc" },
    select: { id: true, user_id: true, balance: true, status: true },
  });

  if (!platformWallet) throw new Error("Platform wallet not found");
  if (platformWallet.status !== "ACTIVE")
    throw new Error("Platform wallet not active");

  return platformWallet;
}
