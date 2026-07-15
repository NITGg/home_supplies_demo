import { Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import FeatureApi from "@/lib/featureApi";

import {
  refundReasonIdParamSchema,
  createRefundReasonSchema,
  updateRefundReasonSchema,
  deleteRefundReasonsSchema,
} from "./refunds-reasons.schema";

import {
  listRefundReasonsService,
  getRefundReasonByIdService,
  createRefundReasonService,
  updateRefundReasonService,
  deleteRefundReasonService,
  deleteRefundReasonsService,
} from "./refunds-reasons.service";

export async function listRefundReasons(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .fields().data;

  const result = await listRefundReasonsService(data);

  return res.json(result);
}

export async function getRefundReason(req: AuthedRequest, res: Response) {
  const { id } = refundReasonIdParamSchema.parse(req.sanitized.params);

  const refundReason = await getRefundReasonByIdService(id);

  return res.json({ refundReason });
}

export async function createRefundReason(req: AuthedRequest, res: Response) {
  const data = createRefundReasonSchema.parse(req.sanitized.body);

  const refundReason = await createRefundReasonService(data);

  return res.status(201).json({
    message: "Refund reason created",
    refundReason,
  });
}

export async function updateRefundReason(req: AuthedRequest, res: Response) {
  const { id } = refundReasonIdParamSchema.parse(req.sanitized.params);

  const data = updateRefundReasonSchema.parse(req.sanitized.body);

  const refundReason = await updateRefundReasonService(id, data);

  return res.json({
    message: "Refund reason updated",
    refundReason,
  });
}

export async function deleteRefundReason(req: AuthedRequest, res: Response) {
  const { id } = refundReasonIdParamSchema.parse(req.sanitized.params);

  await deleteRefundReasonService(id);

  return res.json({
    message: "Refund reason deleted",
  });
}

export async function deleteRefundReasons(req: AuthedRequest, res: Response) {
  const data = deleteRefundReasonsSchema.parse(req.sanitized.body);

  const result = await deleteRefundReasonsService(data);

  return res.json({
    message: "Refund reasons deleted",
    ...result,
  });
}
