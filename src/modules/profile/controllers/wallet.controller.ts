import type { Request, Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  confirmWalletRechargeService,
  confirmKashierRechargeService,
  confirmEasykashRechargeService,
  getMyPenaltiesService,
  getMyTransactionsServices,
  getMyUnpaidCommissionService,
  getMyWalletService,
  initiateWalletRechargeService,
  redeemWalletCouponService,
} from "../services/wallet.service";
import {
  walletCouponCodeSchema,
  walletRechargeConfirmCallbackSchema,
  walletRechargeConfirmHmacSchema,
  walletRechargeInitSchema,
  kashierWebhookBodySchema,
} from "../schemas/wallet.schema";
import { validateCustomerCouponService } from "@/modules/customer-coupons/customer-coupons.service";
import type { EasykashCallbackPayload } from "@/types/easykash.types";
import { HttpError } from "@/lib/httpError";
import FeatureApi from "@/lib/featureApi";
import { logger } from "@/config/logger";
import { roles } from "@/middlewares/auth/requireRole";

export async function getMyWallet(req: AuthedRequest, res: Response) {
  const wallet = await getMyWalletService(req.user.id);
  return res.status(200).json(wallet);
}
export async function getMyTransactions(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter() // always enforce
    .sort("-created_at") // default sort if query.sort missing
    .limit(10) // default limit if query.limit missing
    .skip(0)
    .includes()
    .keyword()
    .fields().data;

  const transactions = await getMyTransactionsServices(req.user.id, data);
  return res.status(200).json(transactions);
}
export async function getMyPenalties(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter() // always enforce
    .sort("-created_at") // default sort if query.sort missing
    .limit(10) // default limit if query.limit missing
    .skip(0)
    .includes()
    .keyword()
    .fields().data;

  const penalties = await getMyPenaltiesService(req.user.id, data);
  return res.status(200).json(penalties);
}
export async function getMyUnpaidCommissions(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter() // always enforce
    .sort("-created_at") // default sort if query.sort missing
    .limit(10) // default limit if query.limit missing
    .skip(0)
    .includes()
    .keyword()
    .fields().data;

  const unpaidCommissions = await getMyUnpaidCommissionService(
    req.user.id,
    data,
  );
  return res.status(200).json(unpaidCommissions);
}

export async function validateWalletCoupon(req: AuthedRequest, res: Response) {
  const { code } = walletCouponCodeSchema.parse(req.sanitized.body);

  const { coupon } = await validateCustomerCouponService({
    userId: req.user.id,
    code,
    orderType: "CATALOG_PURCHASE",
  });

  if (coupon.type !== "WALLET_CREDIT") {
    throw new HttpError(400, "customer-coupons:errors.not_wallet_coupon");
  }

  // Optional: ensure it actually credits something
  if (
    (coupon.wallet_amount_cents ?? 0) <= 0 &&
    (coupon.wallet_points ?? 0) <= 0
  ) {
    throw new HttpError(400, "customer-coupons:errors.invalid_wallet_reward");
  }

  return res.status(200).json({
    valid: true,
    coupon: {
      id: coupon.id,
      code: coupon.code,
      type: coupon.type,
      wallet_amount_cents: coupon.wallet_amount_cents,
      wallet_points: coupon.wallet_points,
    },
  });
}

export async function redeemWalletCoupon(req: AuthedRequest, res: Response) {
  const { code } = walletCouponCodeSchema.parse(req.sanitized.body);

  const result = await redeemWalletCouponService({
    userId: req.user.id,
    code,
  });

  return res.status(200).json(result);
}

export async function initiateWalletRecharge(
  req: AuthedRequest,
  res: Response,
) {
  const data = walletRechargeInitSchema.parse(req.sanitized.body);
  // const baseUrl = `https://unwaddling-jericho-checkable.ngrok-free.dev/api/v1`;
  const baseUrl = `${req.protocol}://${req.get("host")}/admin_apis/api/v1`;

  const result = await initiateWalletRechargeService({
    userId: req.user.id,
    user: {
      full_name: req.user.full_name,
      email: req.user.email,
      phone: req.user.phone,
      role: req.user.role.name as roles,
    },
    notificationUrl: `${baseUrl}/profile/wallet/recharge/paymob/confirm`,
    kashierWebhookUrl: `${baseUrl}/profile/wallet/recharge/kashier/confirm`,
    easykashWebhookUrl: `${baseUrl}/profile/wallet/recharge/easykash/confirm`,
    lang: req.language,
    data,
  });

  return res.status(201).json({
    message:
      req.t?.("profile:messages.recharge_initiated") ??
      "Wallet recharge initiated",
    ...result,
  });
}

export async function confirmKashierRecharge(req: Request, res: Response) {
  const body = kashierWebhookBodySchema.parse(req.sanitized.body);

  // Kashier sends the signature in the `x-kashier-signature` header.
  // Some integrations also pass it as a query param — accept both.
  const headerSig =
    (req.headers["x-kashier-signature"] as string | undefined) ?? "";
  const querySig = (req.query?.signature as string | undefined) ?? "";
  const signature = headerSig || querySig;

  if (!signature) {
    logger.warn("[Kashier] Webhook received without signature — rejecting");
    return res.status(401).json({ message: "Missing Kashier signature" });
  }

  logger.debug(
    { signature, source: headerSig ? "header" : "query" },
    "[Kashier] Webhook signature source",
  );

  const result = await confirmKashierRechargeService({
    body,
    signature,
  });

  return res.status(200).json({
    message: result.alreadyApplied
      ? (req.t?.("profile:messages.recharge_already_applied") ??
        "Already applied")
      : (req.t?.("profile:messages.recharge_completed") ??
        "Wallet recharge completed"),
    ...result,
  });
}

export async function confirmEasykashRecharge(req: Request, res: Response) {
  // EasyKash sends the callback as a GET with query params.
  const payload = req.query as unknown as EasykashCallbackPayload;

  logger.debug({ payload }, "[Wallet/EasyKash] recharge callback received");

  const result = await confirmEasykashRechargeService(payload);

  return res.status(200).json({
    message: result.alreadyApplied
      ? (req.t?.("profile:messages.recharge_already_applied") ?? "Already applied")
      : (req.t?.("profile:messages.recharge_completed") ?? "Wallet recharge completed"),
    ...result,
  });
}

export async function confirmWalletRecharge(req: Request, res: Response) {
  const body = walletRechargeConfirmCallbackSchema.parse(req.sanitized.body);
  const { hmac } = walletRechargeConfirmHmacSchema.parse(req.query);
  const result = await confirmWalletRechargeService({
    body,
    hmac,
  });

  return res.status(200).json({
    message: result.alreadyApplied
      ? (req.t?.("profile:messages.recharge_already_applied") ??
        "Wallet recharge already applied")
      : (req.t?.("profile:messages.recharge_completed") ??
        "Wallet recharge completed"),
    ...result,
  });
}
