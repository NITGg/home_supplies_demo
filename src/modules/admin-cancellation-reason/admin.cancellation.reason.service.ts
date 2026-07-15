import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { NextFunction, Request, Response } from "express";
import { reasonDTO, updateReasonDTO } from "./admin.cancellation.reason.dto";
import FeatureApi from "@/lib/featureApi";

export class AdminCancellationReasonService {
  constructor() {}

  // ============================ reason ============================
  reason = async (req: Request, res: Response, next: NextFunction) => {
    const { role_id, reason_ar, reason_en }: reasonDTO = req.sanitized.body;

    // step: check if role exists
    const role = await prisma.userRole.findUnique({
      where: { id: Number(role_id) },
    });
    if (!role) {
      throw new HttpError(404, "Role not found");
    }

    // step: create reason
    const reason = await prisma.cancellationReason.create({
      data: {
        role_id: Number(role_id),
        reason_en,
        reason_ar,
      },
    });

    return res.status(201).json({
      success: true,
      message: req.t(
        "cancellation-reason:messages.reason_created_successfully",
      ),
      data: reason,
    });
  };

  // ============================ updateReason ============================
  updateReason = async (req: Request, res: Response, next: NextFunction) => {
    const { reason_id } = req.sanitized.params;
    const { reason_ar, reason_en }: updateReasonDTO = req.sanitized.body;

    // step: check if reason exists
    if (!reason_id) {
      throw new HttpError(400, "Reason ID is required");
    }
    const reason = await prisma.cancellationReason.findUnique({
      where: { id: Number(reason_id) },
    });
    if (!reason) {
      throw new HttpError(404, "Reason not found");
    }

    // step: update reason
    const updatedReason = await prisma.cancellationReason.update({
      where: { id: Number(reason_id) },
      data: {
        reason_en,
        reason_ar,
      },
    });

    return res.status(200).json({
      success: true,
      message: req.t(
        "cancellation-reason:messages.reason_updated_successfully",
      ),
      data: updatedReason,
    });
  };

  // ============================ reasonDetails ============================
  reasonDetails = async (req: Request, res: Response, next: NextFunction) => {
    const { reason_id } = req.sanitized.params;

    // step: check if reason exists
    if (!reason_id) {
      throw new HttpError(400, "Reason ID is required");
    }
    const reason = await prisma.cancellationReason.findUnique({
      where: { id: Number(reason_id) },
    });
    if (!reason) {
      throw new HttpError(
        404,
        req.t("cancellation-reason:errors.reason_not_found"),
      );
    }

    return res.status(200).json({
      success: true,
      message: req.t("cancellation-reason:messages.reason_details_retrieved"),
      data: reason,
    });
  };

  // ============================ allReasons ============================
  allReasons = async (req: Request, res: Response, next: NextFunction) => {
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter()
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword(["reason_ar", "reason_en"]) // ?keyword=xxx&items=reason_ar,reason_en
      .fields().data; // ?fields=id,reason_ar,reason_en

    const [totalReasons, reasons] = await prisma.$transaction([
      prisma.cancellationReason.count({ where: queryOptions.where }),
      prisma.cancellationReason.findMany(queryOptions as any),
    ]);

    return res.status(200).json({
      success: true,
      message: req.t("cancellation-reason:messages.all_reasons_retrieved"),
      data: {
        totalReasons,
        totalPages: Math.ceil(totalReasons / (queryOptions.take ?? 10)),
        reasons,
      },
    });
  };

  // ============================ deleteReason ============================
  deleteReason = async (req: Request, res: Response, next: NextFunction) => {
    const { reason_id } = req.sanitized.params;

    // step: check if reason exists
    if (!reason_id) {
      throw new HttpError(400, "Reason ID is required");
    }
    const reason = await prisma.cancellationReason.findUnique({
      where: { id: Number(reason_id) },
    });
    if (!reason) {
      throw new HttpError(
        404,
        req.t("cancellation-reason:errors.reason_not_found"),
      );
    }

    // step: delete reason
    await prisma.cancellationReason.delete({
      where: { id: Number(reason_id) },
    });

    return res.status(200).json({
      success: true,
      message: req.t(
        "cancellation-reason:messages.reason_deleted_successfully",
      ),
    });
  };
}
