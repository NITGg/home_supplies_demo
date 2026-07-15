import { NextFunction, Request, Response } from "express";
import { AppError } from "../errors/app.error";
import { HttpStatusCode } from "../http/http.status.code";
import { prisma } from "../../DB/lib/prisma";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Blocks access to the order module if the courier hasn't submitted their
 * criminal record within the configured grace period (from `created_at`).
 */
export const requireCriminalRecord = async (
  req: Request | any,
  res: Response,
  next: NextFunction,
) => {
  const courier = req.user?.courier;
  if (!courier) {
    throw new AppError(HttpStatusCode.FORBIDDEN, "Courier profile not found");
  }

  if (courier.courier_criminal_record) {
    return next();
  }

  const settings = await prisma.applicationSetting.findFirst({
    select: {
      courier_criminal_record_grace_period_days: true,
    },
  });
  const gracePeriodDays =
    settings?.courier_criminal_record_grace_period_days ?? 30;

  const ageInDays =
    (Date.now() - new Date(courier.created_at).getTime()) / MS_PER_DAY;

  if (ageInDays > gracePeriodDays) {
    throw new AppError(
      HttpStatusCode.FORBIDDEN,
      req.__("errors.courier_criminal_record_required"),
    );
  }

  return next();
};
