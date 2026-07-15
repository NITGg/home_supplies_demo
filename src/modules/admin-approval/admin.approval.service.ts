import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { NextFunction, Request, Response } from "express";
import { applyFilters, buildPaginationResponse } from "@/lib/filter";
import { any } from "zod";
import { Prisma } from "@prisma/client";

export class AdminApprovalService {
  constructor() {}

  // ============================ allCouriers ============================
  allCouriers = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        user_id: "exact",
        vehicle_type: "contains",
        vehicle_plate: "contains",
        is_approved: "exact",
        created_at: "dateRange",
        updated_at: "dateRange",
        deleted_at: "dateRange",
      },
    );

    // Apply nested relation filters for the user model
    const { user_full_name, user_phone, user_email, user_is_active } =
      res.locals.validatedData;
    if (
      user_full_name ||
      user_phone ||
      user_email ||
      user_is_active !== undefined
    ) {
      filters.user = {
        ...(user_full_name && { full_name: { contains: user_full_name } }),
        ...(user_phone && { phone: { contains: user_phone } }),
        ...(user_email && { email: { contains: user_email } }),
        ...(user_is_active !== undefined && { is_active: user_is_active }),
      };
    }

    // Apply nested relation filters for selectedAreas model
    const { governorate_id, area_id } = res.locals.validatedData;
    if (area_id || governorate_id) {
      filters.selectedAreas = {
        some: {
          ...(area_id && { area_id: area_id }),
          ...(governorate_id && {
            area: {
              governorate_id: governorate_id,
            },
          }),
        },
      };
    }

    const [couriers, total] = await Promise.all([
      prisma.courier.findMany({
        where: filters,
        include: { user: true },
        ...pagination,
      }),
      prisma.courier.count({
        where: filters,
      }),
    ]);

    return res.json({
      message: req.t("admin-approval:messages.ok"),
      data: {
        couriers,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ courierDetails ============================
  courierDetails = async (req: Request, res: Response, next: NextFunction) => {
    const { courierId } = res.locals.validatedData;

    //step: get courier
    const courier = await prisma.courier.findUnique({
      where: { id: courierId },
      include: { user: true },
    });
    if (!courier) {
      return res
        .status(404)
        .json({ message: req.t("admin-approval:errors.courier_not_found") });
    }

    // step: get selected areas
    const areasRaw = await prisma.courierSelectedArea.findMany({
      where: { courier_id: courierId },
      include: {
        area: {
          include: {
            governorate: true,
          },
        },
      },
    });

    const governoratesMap = new Map<number, any>();

    areasRaw.forEach((item) => {
      const gov = item.area.governorate;
      const area = item.area;

      if (!governoratesMap.has(gov.id)) {
        governoratesMap.set(gov.id, {
          name: gov.name,
          name_ar: gov.name_ar,
          created_at: gov.created_at,
          updated_at: gov.updated_at,
          areas: [],
        });
      }

      governoratesMap.get(gov.id).areas.push({
        name: area.name,
        name_ar: area.name_ar,
        boundaries: area.boundaries,
        created_at: area.created_at,
        updated_at: area.updated_at,
      });
    });

    const selected_governorates = Array.from(governoratesMap.values());

    return res.json({
      message: req.t("admin-approval:messages.ok"),
      data: {
        courier,
        selected_governorates,
      },
    });
  };

  // ============================ approveCourier ============================
  approveCourier = async (req: Request, res: Response, next: NextFunction) => {
    const { courierId } = res.locals.validatedData;

    // step: check existence
    const exists = await prisma.courier.findUnique({
      where: { id: courierId },
    });
    if (!exists) {
      return res
        .status(404)
        .json({ message: req.t("admin-approval:errors.courier_not_found") });
    }

    //step: update courier
    const courier = await prisma.courier.update({
      where: { id: courierId },
      data: { is_approved: true, updated_at: new Date() },
    });

    return res.json({
      message: req.t("admin-approval:messages.courier_approved"),
      data: {
        courier,
      },
    });
  };

  // ============================ rejectCourier ============================
  rejectCourier = async (req: Request, res: Response, next: NextFunction) => {
    const { courierId, reject_reason } = res.locals.validatedData;

    // step: check existence
    const exists = await prisma.courier.findUnique({
      where: { id: courierId },
    });
    if (!exists) {
      return res
        .status(404)
        .json({ message: req.t("admin-approval:errors.courier_not_found") });
    }

    //step: update courier
    const courier = await prisma.courier.update({
      where: {
        id: courierId,
      },
      data: { is_approved: false, reject_reason, updated_at: new Date() },
    });

    return res.json({
      message: req.t("admin-approval:messages.courier_rejected"),
      data: {
        courier,
      },
    });
  };

  // ============================ listProfileUpdateRequests ============================
  listProfileUpdateRequests = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        status: "exact",
        user_id: "exact",
      },
    );

    const [requests, total] = await Promise.all([
      prisma.profileUpdateRequest.findMany({
        where: filters,
        include: { user: { include: { courier: true } } },
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
      prisma.profileUpdateRequest.count({ where: filters }),
    ]);

    return res.json({
      message: req.t("admin-approval:messages.ok"),
      data: {
        requests,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ profileUpdateRequestDetails ============================
  profileUpdateRequestDetails = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { requestId } = res.locals.validatedData;

    const request = await prisma.profileUpdateRequest.findUnique({
      where: { id: requestId },
      include: { user: { include: { courier: true } } },
    });

    if (!request) {
      return res.status(404).json({
        message: req.t(
          "admin-approval:errors.profile_update_request_not_found",
        ),
      });
    }

    return res.json({
      message: req.t("admin-approval:messages.ok"),
      data: { request },
    });
  };

  // ============================ approveProfileUpdateRequest ============================
  approveProfileUpdateRequest = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { requestId } = res.locals.validatedData;

    const request = await prisma.profileUpdateRequest.findUnique({
      where: { id: requestId },
    });
    if (!request) {
      return res.status(404).json({
        message: req.t(
          "admin-approval:errors.profile_update_request_not_found",
        ),
      });
    }
    if (request.status !== "PENDING") {
      return res.status(409).json({
        message: req.t(
          "admin-approval:errors.profile_update_request_already_processed",
        ),
      });
    }

    const courier = await prisma.courier.findUnique({
      where: { user_id: request.user_id },
    });
    if (!courier) {
      return res
        .status(404)
        .json({ message: req.t("admin-approval:errors.courier_not_found") });
    }

    // `personal_photo` lives on User, not Courier — split it out so it's
    // applied to the right table. Everything else is a Courier document field.
    const { personal_photo, ...courierData } = request.data as Record<
      string,
      unknown
    >;

    const txOps: Prisma.PrismaPromise<unknown>[] = [
      prisma.courier.update({
        where: { id: courier.id },
        data: {
          ...(courierData as Prisma.CourierUpdateInput),
          updated_at: new Date(),
        },
      }),
      prisma.profileUpdateRequest.update({
        where: { id: requestId },
        data: { status: "APPROVED" },
      }),
    ];

    if (personal_photo !== undefined) {
      txOps.push(
        prisma.user.update({
          where: { id: request.user_id },
          data: { personal_photo: personal_photo as string },
        }),
      );
    }

    const [updatedCourier, updatedRequest] = await prisma.$transaction(txOps);

    return res.json({
      message: req.t("admin-approval:messages.profile_update_approved"),
      data: { courier: updatedCourier, request: updatedRequest },
    });
  };

  // ============================ rejectProfileUpdateRequest ============================
  rejectProfileUpdateRequest = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { requestId, reject_reason } = res.locals.validatedData;

    const request = await prisma.profileUpdateRequest.findUnique({
      where: { id: requestId },
    });
    if (!request) {
      return res.status(404).json({
        message: req.t(
          "admin-approval:errors.profile_update_request_not_found",
        ),
      });
    }
    if (request.status !== "PENDING") {
      return res.status(409).json({
        message: req.t(
          "admin-approval:errors.profile_update_request_already_processed",
        ),
      });
    }

    const updatedRequest = await prisma.profileUpdateRequest.update({
      where: { id: requestId },
      data: { status: "REJECTED", reject_reason },
    });

    return res.json({
      message: req.t("admin-approval:messages.profile_update_rejected"),
      data: { request: updatedRequest },
    });
  };
}
