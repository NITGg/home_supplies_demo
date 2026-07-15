import { requireAuth, requireRole } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminWalletService } from "./admin.wallet.service";
import {
  walletsSchema,
  unpaidCommissionSchema,
  penaltiesSchema,
  escrowsSchema,
  paymentMethodsSchema,
  transactionsSchema,
  adjustBalanceSchema,
  freezeSchema,
  applyPenaltySchema,
  CPWRSchema,
  changeUserIdPWRSchema,
  incBalancePWRSchema,
  decBalancePWRSchema,
  settlingBalanceSchema,
  settlementReportSchema,
} from "./admin.wallet.validation";

const router = Router();
const adminWalletService = new AdminWalletService();

router.get(
  "/wallets",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  validation(walletsSchema),
  adminWalletService.wallets,
);

router.get(
  "/unpaidCommissions",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  validation(unpaidCommissionSchema),
  adminWalletService.unpaidCommissions,
);

router.get(
  "/penalties",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  validation(penaltiesSchema),
  adminWalletService.penalties,
);

router.get(
  "/escrows",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  validation(escrowsSchema),
  adminWalletService.escrows,
);
router.get(
  "/paymentMethods",
  requireAuth,
  requireRole("Admin", "CustomerSupport"),
  validation(paymentMethodsSchema),
  adminWalletService.paymentMethods,
);

router.get(
  "/transactions",
  requireAuth,
  requireRole("Admin", "CustomerSupport", "Supplier"),
  validation(transactionsSchema),
  adminWalletService.transactions,
);

router.post(
  "/adjust-balance",
  requireAuth,
  requireRole("Admin"),
  validation(adjustBalanceSchema),
  adminWalletService.adjustBalance,
);

router.post(
  "/freeze/:walletId",
  validation(freezeSchema),
  requireAuth,
  requireRole("Admin"),
  adminWalletService.freeze,
);

router.post(
  "/unfreeze/:walletId",
  requireAuth,
  requireRole("Admin"),
  adminWalletService.unfreeze,
);

router.post(
  "/apply-penalty/:userId",
  validation(applyPenaltySchema),
  requireAuth,
  requireRole("Admin"),
  adminWalletService.applyPenalty,
);

router.post(
  "/waive-penalty/:penaltyId",
  requireAuth,
  requireRole("Admin"),
  adminWalletService.waivePenalty,
);

router.post(
  "/create-platform-wallet-record",
  requireAuth,
  requireRole("Admin"),
  validation(CPWRSchema),
  adminWalletService.CPWR,
);

router.get(
  "/get-platform-wallet-record",
  requireAuth,
  requireRole("Admin"),
  adminWalletService.GPWR,
);

router.patch(
  "/change-userId-platform-wallet-record",
  requireAuth,
  requireRole("Admin"),
  validation(changeUserIdPWRSchema),
  adminWalletService.changeUserIdPWR,
);

router.patch(
  "/inc-balance-platform-wallet-record",
  requireAuth,
  requireRole("Admin"),
  validation(incBalancePWRSchema),
  adminWalletService.incBalancePWR,
);

router.patch(
  "/dec-balance-platform-wallet-record",
  requireAuth,
  requireRole("Admin"),
  validation(decBalancePWRSchema),
  adminWalletService.decBalancePWR,
);

router.post(
  "/settling-balance",
  requireAuth,
  requireRole("Admin"),
  validation(settlingBalanceSchema),
  adminWalletService.settlingBalance,
);

router.get(
  "/settlement-report",
  requireAuth,
  requireRole("Admin"),
  validation(settlementReportSchema),
  adminWalletService.settlementReport2,
);

export default router;
