import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { validation } from "../../core/middlewares/validation.middleware";
import { WalletService } from "./wallet.service";
import {
  topupSchema,
  listTransactionQuerySchema,
  listPenaltyQuerySchema,
  listUnpaidCommissionQuerySchema,
} from "./wallet.validation";

const router = Router();
const walletService = new WalletService();

router.get("/wallet-data", auth, walletService.walletData);
router.get("/list-transaction",auth,validation(listTransactionQuerySchema),walletService.listTransaction);
router.get("/list-penalty",auth,validation(listPenaltyQuerySchema),walletService.listPenalty);
router.get("/list-unpaid-commission",auth,validation(listUnpaidCommissionQuerySchema),walletService.listUnpaidCommission);
router.get("/total-fines",auth,walletService.totalFines);
router.post("/topup", auth, validation(topupSchema), walletService.topup);

router.post("/paymob/webhook", walletService.paymobWebhook);
router.post("/paymob/redirection-url", walletService.paymobRedirectionUrl);

export default router;
