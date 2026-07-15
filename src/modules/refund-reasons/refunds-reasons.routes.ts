import { Router } from "express";

import { requireAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";

import {
  listRefundReasons,
  getRefundReason,
  createRefundReason,
  updateRefundReason,
  deleteRefundReason,
  deleteRefundReasons,
} from "./refunds-reasons.controller";

export const refundReasonsRouter = Router();

refundReasonsRouter.use(requireAuth);

refundReasonsRouter.get("/", asyncHandler(listRefundReasons));

refundReasonsRouter.get("/:id", asyncHandler(getRefundReason));

refundReasonsRouter.post("/", asyncHandler(createRefundReason));

refundReasonsRouter.put("/:id", asyncHandler(updateRefundReason));

refundReasonsRouter.delete("/", asyncHandler(deleteRefundReasons));

refundReasonsRouter.delete("/:id", asyncHandler(deleteRefundReason));

export default refundReasonsRouter;
