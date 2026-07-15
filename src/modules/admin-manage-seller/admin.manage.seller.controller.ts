import { requireAuth, requireRole } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminManageSellerService } from "./admin.manage.seller.service";
import { referralCodeSchema } from "./admin.manage.seller.validation";

const router = Router();
const adminManageSellerService = new AdminManageSellerService();

router.post(
  "/convert-customer-to-seller/:userId",
  requireAuth,
  requireRole("Admin"),
  adminManageSellerService.convertCustomerToSeller,
);
router.get(
  "/get-seller-stat/:userId",
  requireAuth,
  adminManageSellerService.getSellerStat,
);
router.get(
  "/list-sellers-stat",
  requireAuth,
  adminManageSellerService.listSellersStat,
);

router.get(
  "/generate-referral-link/:userId",
  requireAuth,
  requireRole("Admin", "Seller"),
  adminManageSellerService.generateReferralLink,
);

router.get(
  "/referral/:referral_code",
  adminManageSellerService.navToReferralLink,
); // PUBLIC

router.post(
  "/save-referral-code/:userId",
  validation(referralCodeSchema),
  requireAuth,
  adminManageSellerService.saveReferralCode,
);

export default router;
