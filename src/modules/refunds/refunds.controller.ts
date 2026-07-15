// File Path: backend/src/modules/refunds/refunds.controller.ts
import { Response } from "express";
import { AuthedRequest } from "@/types/authedRequest";
import FeatureApi from "@/lib/featureApi";
import {
  requestRefundSchema,
  refundIdParamSchema,
  reviewRefundSchema,
} from "./refunds.schema";
import {
  requestRefundService,
  listRefundsService,
  processRefundReviewService,
  getRefundByIdService,
  cancelRefundService,
} from "./refunds.service";

export async function requestRefund(req: AuthedRequest, res: Response) {
  const customerId = req.user!.id;
  const data = requestRefundSchema.parse(req.sanitized.body);
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const refund = await requestRefundService(data, customerId, files);

  return res.status(201).json({
    message:
      req.t?.("refunds:messages.requested") ?? "Refund request submitted",
    refund,
  });
}
export async function listMyRefunds(req: AuthedRequest, res: Response) {
  const isAdmin = req.user.role.name === "Admin";
  const customerId = req.user.id;

  const data = new FeatureApi(req)
    .filter(isAdmin ? {} : { requested_by_id: customerId })
    .sort("created_at")
    .limit(10)
    .skip()
    .includes()
    .fields()
    .keyword([
      "requestedBy.full_name",
      "reviewedBy.full_name",
      "requestedBy.phone",
    ]).data;

  const result = await listRefundsService(data);
  return res.json(result);
}

export async function getRefundById(req: AuthedRequest, res: Response) {
  const { id } = refundIdParamSchema.parse(req.params);
  const isAdmin = req.user!.role.name === "Admin";
  const customerId = req.user!.id;

  const refund = await getRefundByIdService(
    id,
    isAdmin ? undefined : customerId,
  );
  return res.json({ refund });
}

export async function cancelRefundRequest(req: AuthedRequest, res: Response) {
  const { id } = refundIdParamSchema.parse(req.params);
  const customerId = req.user!.id;

  await cancelRefundService(id, customerId);
  return res.json({
    message:
      req.t?.("refunds:messages.cancelled") ?? "Refund request cancelled",
  });
}

export async function reviewRefundRequest(req: AuthedRequest, res: Response) {
  const adminId = req.user!.id;
  const { id } = refundIdParamSchema.parse(req.params);
  const data = reviewRefundSchema.parse(req.body);

  const result = await processRefundReviewService(id, data, adminId);

  return res.json({
    message: req.t?.("refunds:messages.reviewed") ?? "Refund status updated",
    result,
  });
}
