import { NextFunction, Request, Response } from "express";
import { responseHandler } from "../../core/handlers/response.handler";
import { prisma } from "../../DB/lib/prisma";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";
import { FaqsQueryDTO, OnBoardingQueryDTO } from "./aboutus.dto";
import { TargetUser } from "@prisma/client";

export class AboutusService {
  constructor() {}

  // ============================ faqs ============================
  faqs = async (req: Request, res: Response, next: NextFunction) => {
    const validatedData = res.locals.validatedData as FaqsQueryDTO;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      validatedData,
      {
        question: "exact",
        language: "exact",
        is_active: "exact",
        sort_id: "exact",
        target_user: "exact",
      },
    );

    // step: Custom target_user logic
    if (validatedData.target_user) {
      if (validatedData.target_user === TargetUser.CUSTOMER) {
        filters.target_user = { in: [TargetUser.ALL, TargetUser.CUSTOMER] };
      } else if (validatedData.target_user === TargetUser.SUPPLIER) {
        filters.target_user = { in: [TargetUser.ALL, TargetUser.SUPPLIER] };
      }
      // If ALL, applyFilters already set filters.target_user = 'ALL'
    }

    const [faqs, total] = await Promise.all([
      prisma.faq.findMany({
        where: filters,
        orderBy: {
          sort_id:
            (validatedData.sort_id_sorting?.toLowerCase() as "asc" | "desc") ||
            "asc",
        },
        ...pagination,
      }),
      prisma.faq.count({
        where: filters,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.faqs_retrieved"),
      data: {
        faqs,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ aboutApp ============================
  aboutApp = async (req: Request, res: Response, next: NextFunction) => {
    const aboutApp = await prisma.aboutApp.findFirst({
      orderBy: { created_at: "desc" },
    });

    return responseHandler({
      res,
      message: res.__("messages.about_app_retrieved"),
      data: aboutApp || {},
    });
  };

  // ============================ onBoarding ============================
  onBoarding = async (req: Request, res: Response, next: NextFunction) => {
    const validatedData = res.locals.validatedData as OnBoardingQueryDTO;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      validatedData,
      {
        title: "exact",
        title_ar: "exact",
        subtitle: "exact",
        subtitle_ar: "exact",
        sort_id: "exact",
        target_user: "exact",
      },
    );

    // step: Custom target_user logic
    if (validatedData.target_user) {
      if (validatedData.target_user === TargetUser.CUSTOMER) {
        filters.target_user = { in: [TargetUser.ALL, TargetUser.CUSTOMER] };
      } else if (validatedData.target_user === TargetUser.SUPPLIER) {
        filters.target_user = { in: [TargetUser.ALL, TargetUser.SUPPLIER] };
      }
    }

    const [onBoardings, total] = await Promise.all([
      prisma.onBoarding.findMany({
        where: filters,
        orderBy: {
          sort_id:
            (validatedData.sort_id_sorting?.toLowerCase() as "asc" | "desc") ||
            "asc",
        },
        ...pagination,
      }),
      prisma.onBoarding.count({
        where: filters,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.on_boarding_retrieved"),
      data: {
        onBoardings,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };
}
