// src/utils/courierActionRules.ts

export type CourierApprovalStatus = "pending" | "approved" | "rejected" | null;
export type WalletStatus = "active" | "frozen" | null;

export interface ActionAvailability {
  canApprove: boolean;
  canReject: boolean;
  canFreeze: boolean;
  canUnfreeze: boolean;
  canAdjustBalance: boolean;
  canApplyPenalty: boolean;
}

export function getActionAvailability(
  isApproved: boolean | null,
  walletStatus: WalletStatus,
): ActionAvailability {
  // Map boolean isApproved to semantic status if possible, or use logic directly
  // By data-model:
  // pending -> Approve: true, Reject: true
  // approved (true) -> Approve: false, Reject: true
  // rejected (false) -> Approve: true, Reject: false

  let canApprove = false;
  let canReject = false;

  if (isApproved === null) {
    // Pending
    canApprove = true;
    canReject = true;
  } else if (isApproved === true) {
    canApprove = false;
    canReject = true;
  } else if (isApproved === false) {
    canApprove = true;
    canReject = false;
  }

  // Wallet
  const hasWallet = walletStatus !== null;
  const canFreeze = hasWallet && walletStatus === "active";
  const canUnfreeze = hasWallet && walletStatus === "frozen";
  const canAdjustBalance = hasWallet;
  const canApplyPenalty = hasWallet;

  return {
    canApprove,
    canReject,
    canFreeze,
    canUnfreeze,
    canAdjustBalance,
    canApplyPenalty,
  };
}
