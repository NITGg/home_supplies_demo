import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireExternalApp } from "@/middlewares/auth";
import {
  getExternalAppWallet,
  getExternalAppWalletTransactions,
  initiateExternalAppWalletRecharge,
} from "../controllers/externalApp.wallet.controller";

const router = Router();

router.use(requireExternalApp);

router.get("/", asyncHandler(getExternalAppWallet));
router.get(
  "/transactions",
  asyncHandler(getExternalAppWalletTransactions),
);
router.post(
  "/recharge/initiate",
  asyncHandler(initiateExternalAppWalletRecharge),
);

export default router;
