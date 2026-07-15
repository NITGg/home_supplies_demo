import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import { HttpError } from "@/lib/httpError";
import {
  getExternalAppWalletService,
  getExternalAppWalletTransactionsService,
  initiateExternalAppWalletRechargeService,
} from "../services/externalApp.wallet.service";
import { externalAppWalletRechargeInitSchema } from "../schemas/externalApp.wallet.schema";

export async function getExternalAppWallet(req: Request, res: Response) {
  if (!req.externalApp) throw new HttpError(401, "errors.unauthorized");

  const wallet = await getExternalAppWalletService(req.externalApp.id);
  return res.json({ wallet });
}

export async function getExternalAppWalletTransactions(
  req: Request,
  res: Response,
) {
  if (!req.externalApp) throw new HttpError(401, "errors.unauthorized");

  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(10)
    .skip(0)
    .includes()
    .keyword()
    .fields().data;

  const transactions = await getExternalAppWalletTransactionsService(
    req.externalApp.id,
    data,
  );
  return res.json(transactions);
}

export async function initiateExternalAppWalletRecharge(
  req: Request,
  res: Response,
) {
  if (!req.externalApp) throw new HttpError(401, "errors.unauthorized");

  const data = externalAppWalletRechargeInitSchema.parse(req.sanitized.body);
  // const baseUrl = `${req.protocol}://${req.get("host")}/admin_apis/api/v1`;
    const baseUrl = `https://unwaddling-jericho-checkable.ngrok-free.dev/api/v1`;


  const result = await initiateExternalAppWalletRechargeService({
    externalAppId: req.externalApp.id,
    notificationUrl: `${baseUrl}/profile/wallet/recharge/paymob/confirm`,
    kashierWebhookUrl: `${baseUrl}/profile/wallet/recharge/kashier/confirm`,
    easykashWebhookUrl: `${baseUrl}/profile/wallet/recharge/easykash/confirm`,
    lang: req.language,
    data,
  });

  return res.status(201).json({
    message:
      req.t?.("external_apps:messages.recharge_initiated") ??
      "Wallet recharge initiated",
    ...result,
  });
}
