import { Router } from "express";
import { requireAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import upload from "@/middlewares/upload";

import {
  getMyProfile,
  updateProfile,
  deleteMyAccount,
  updateFcmToken,
  changeEmail,
  changePhone,
  confirmOtp,
  changePassword,
} from "./controllers/profile.controller";

import {
  listMyAddresses,
  createMyAddress,
  updateMyAddress,
  deleteMyAddress,
} from "./controllers/addresses.controller";

import {
  confirmWalletRecharge,
  confirmKashierRecharge,
  confirmEasykashRecharge,
  getMyWallet,
  initiateWalletRecharge,
  validateWalletCoupon,
  redeemWalletCoupon,
  getMyTransactions,
  getMyPenalties,
  getMyUnpaidCommissions,
} from "./controllers/wallet.controller";

const router = Router();


// These webhook routes MUST stay above 'requireAuth'.
// They are called by external payment provider servers.
// Security is handled via HMAC signature verification inside each service
// rather than user session tokens.
router.post("/wallet/recharge/paymob/confirm",   asyncHandler(confirmWalletRecharge));
router.post("/wallet/recharge/kashier/confirm",  asyncHandler(confirmKashierRecharge));
router.get("/wallet/recharge/easykash/confirm",  asyncHandler(confirmEasykashRecharge));

// Legacy path — keep Paymob working for any already-deployed notification URLs
router.post("/wallet/recharge/confirm", asyncHandler(confirmWalletRecharge));


router.use(requireAuth);

// profile
router.get("/", asyncHandler(getMyProfile));
router.put("/", upload.single("personal_photo"), asyncHandler(updateProfile));
router.delete("/", asyncHandler(deleteMyAccount));

// fcm
router.post("/fcm-token", asyncHandler(updateFcmToken));

// contact changes
router.post("/change-email", asyncHandler(changeEmail));
router.post("/change-phone", asyncHandler(changePhone));
router.post("/confirm-otp", asyncHandler(confirmOtp));

// password
router.post("/change-password", asyncHandler(changePassword));

// addresses
router.get("/addresses", asyncHandler(listMyAddresses));
router.post("/addresses", asyncHandler(createMyAddress));
router.put("/addresses/:id", asyncHandler(updateMyAddress));
router.delete("/addresses/:id", asyncHandler(deleteMyAddress));

// wallet
router.get("/wallet", asyncHandler(getMyWallet));
router.get("/wallet/transactions", asyncHandler(getMyTransactions));
router.get("/wallet/penalties", asyncHandler(getMyPenalties));
router.get("/wallet/unpaid-commissions", asyncHandler(getMyUnpaidCommissions));

// ✅ wallet coupon
router.post("/wallet/coupon/validate", asyncHandler(validateWalletCoupon));
router.post("/wallet/coupon/redeem", asyncHandler(redeemWalletCoupon));
router.post("/wallet/recharge/initiate", asyncHandler(initiateWalletRecharge));

export default router;
