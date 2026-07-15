import { prisma } from "@/config/prisma";
import { NextFunction, Request, Response } from "express";
import {
  createCourierOfficeDTO,
  updateCourierOfficeDTO,
} from "./admin.courier.office.dto";
import FeatureApi from "@/lib/featureApi";

export class AdminCourierOfficeService {
  constructor() {}

  // ============================ createCourierOffice ============================
  createCourierOffice = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const {
      name,
      address,
      phone,
      email,
      website,
      description,
      commission_type,
      commission_value,
    }: createCourierOfficeDTO = req.sanitized.body;

    // step: create courier office
    const courierOffice = await prisma.courierOffice.create({
      data: {
        name,
        address,
        phone,
        email,
        website,
        description,
        commission_type,
        commission_value,
      },
    });

    return res.status(201).json({
      message: req.t("admin-courier-office:messages.ok"),
      data: courierOffice,
    });
  };

  // ============================ updateCourierOffice ============================
  updateCourierOffice = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const {
      name,
      address,
      phone,
      email,
      website,
      description,
      commission_type,
      commission_value,
    }: updateCourierOfficeDTO = req.sanitized.body;
    const { courierOfficeId } = req.sanitized.params;

    // step: check if courier office exists
    const courierOffice = await prisma.courierOffice.findUnique({
      where: { id: Number(courierOfficeId) },
    });
    if (!courierOffice) {
      return res.status(404).json({
        message: req.t("admin-courier-office:errors.courier_office_not_found"),
      });
    }

    // step: update courier office
    const updatedCourierOffice = await prisma.courierOffice.update({
      where: { id: Number(courierOfficeId) },
      data: {
        name,
        address,
        phone,
        email,
        website,
        description,
        commission_type,
        commission_value,
      },
    });
    return res.status(200).json({
      message: req.t("admin-courier-office:messages.ok"),
      data: updatedCourierOffice,
    });
  };

  // ============================ courierOfficeDetails ============================
  courierOfficeDetails = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { courierOfficeId } = req.sanitized.params;

    // step: find courier office
    const courierOffice = await prisma.courierOffice.findUnique({
      where: { id: Number(courierOfficeId) },
    });
    if (!courierOffice) {
      return res.status(404).json({
        message: req.t("admin-courier-office:errors.courier_office_not_found"),
      });
    }

    return res.status(200).json({
      message: req.t("admin-courier-office:messages.ok"),
      data: courierOffice,
    });
  };

  // ============================ allCourierOffices ============================
  allCourierOffices = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter()
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword(["name"]) // ?keyword=xxx&items=name,address,phone,email,website,description
      .fields().data; // ?fields=id,name,address,phone,email,website,description

    const [totalCouriers, couriers] = await prisma.$transaction([
      prisma.courierOffice.count({ where: queryOptions.where }),
      prisma.courierOffice.findMany(queryOptions as any),
    ]);

    return res.status(200).json({
      message: req.t("admin-courier-office:messages.ok"),
      data: {
        totalCouriers,
        totalPages: Math.ceil(totalCouriers / (queryOptions.take ?? 10)),
        couriers,
      },
    });
  };

  // ============================ appendCourierToOffice ============================
  appendCourierToOffice = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { courierId, courierOfficeId } = req.sanitized.body;

    // step: find courier
    const courier = await prisma.courier.findUnique({
      where: { id: Number(courierId) },
    });
    if (!courier) {
      return res.status(404).json({
        message: req.t("admin-courier-office:errors.courier_not_found"),
      });
    }

    // step: find courier office (only if courierOfficeId is provided)
    let courierOffice = null;
    if (courierOfficeId) {
      courierOffice = await prisma.courierOffice.findUnique({
        where: { id: Number(courierOfficeId) },
      });
    }
    if (!courierOffice) {
      await prisma.courier.update({
        where: { id: Number(courierId) },
        data: { courier_office_id: null },
      });
      return res.status(200).json({
        message: req.t(
          "admin-courier-office:messages.courier_removed_from_office",
        ),
      });
    }

    // step: add courier to office
    await prisma.courier.update({
      where: { id: Number(courierId) },
      data: { courier_office_id: Number(courierOfficeId) },
    });

    // step: return response
    return res.status(200).json({
      message: req.t("admin-courier-office:messages.courier_added_to_office"),
    });
  };

  // ============================ getOfficeEarnings ============================
  // GET /admin/courier-office/earnings
  // Query params:
  //   courier_id        – filter to a single courier (optional)
  //   created_at[gte]   – ISO date lower bound (optional)
  //   created_at[lte]   – ISO date upper bound (optional)
  //
  // The caller must be authenticated. The office is resolved from the
  // authenticated user's courier record (courier.courier_office_id).
  getOfficeEarnings = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const userId = (req as any).user?.id;

    // 1. Find which office this user belongs to via their Courier record
    const myCourier = await prisma.courier.findFirst({
      where: { user_id: userId },
      select: { courier_office_id: true },
    });

    const officeId = myCourier?.courier_office_id;
    if (!officeId) {
      return res.status(404).json({ message: "No office found for this user" });
    }

    // 2. Load the office so we know commission type/value
    const office = await prisma.courierOffice.findUnique({
      where: { id: officeId },
    });
    if (!office) {
      return res.status(404).json({ message: "Office not found" });
    }

    // 3. Build the order filter
    const {
      courier_id,
      "created_at[gte]": gte,
      "created_at[lte]": lte,
    } = req.query as Record<string, string | undefined>;

    // Resolve all courier IDs that belong to this office
    const officeCouriers = await prisma.courier.findMany({
      where: {
        courier_office_id: officeId,
        user_id: { not: userId }, // ── FILTER: Remove current user from general office stats ──
      },
      select: { id: true },
    });
    const officeCouerierIds = officeCouriers.map((c) => c.id);

    // If a specific courier_id is requested, ensure it belongs to this office
    let courierIds: number[] = officeCouerierIds;
    if (courier_id) {
      const requestedId = Number(courier_id);
      if (!officeCouerierIds.includes(requestedId)) {
        return res
          .status(403)
          .json({ message: "Courier does not belong to your office" });
      }
      courierIds = [requestedId];
    }

    const dateFilter: Record<string, Date> = {};
    if (gte) dateFilter.gte = new Date(gte);
    if (lte) dateFilter.lte = new Date(lte);

    // 4. Aggregate courier_fee for DELIVERED orders
    const agg = await prisma.order.aggregate({
      _sum: { courier_fee: true },
      _count: { id: true },
      where: {
        courier_id: { in: courierIds },
        status: "DELIVERED",
        ...(Object.keys(dateFilter).length && { created_at: dateFilter }),
      },
    });

    const deliveredCount = agg._count.id;
    const courierFeeTotal = Number(agg._sum.courier_fee ?? 0);

    // 5. Calculate earnings based on commission model
    // FIXED_PER_ORDER: commission_value is stored in cents (e.g. 200 = 2.00 EGP)
    // PERCENTAGE:      commission_value is a plain percentage (e.g. 10 = 10%)
    //                  applied to courier_fee which is also in cents
    let earningsCents = 0;
    if (office.commission_type === "FIXED_PER_ORDER") {
      earningsCents = deliveredCount * Number(office.commission_value); // cents
    } else {
      earningsCents = courierFeeTotal * (Number(office.commission_value) / 100); // cents
    }

    return res.status(200).json({
      message: req.t("admin-courier-office:messages.ok"),
      data: {
        // All monetary values in cents so the frontend can divide by 100
        earnings_cents: Math.round(earningsCents),
        courier_fee_total_cents: Math.round(courierFeeTotal),
        delivered_count: deliveredCount,
        commission_type: office.commission_type,
        commission_value: Number(office.commission_value), // cents for FIXED, % for PERCENTAGE
        office_id: officeId,
        courier_id: courier_id ?? null,
      },
    });
  };

  // ============================ getCourierEarningsBreakdown ============================
  // GET /admin/courier-office/couriers-earnings
  // Returns per-courier earnings for the authenticated user's office.
  // Query params: period (week | month | year), limit, skip
  getCourierEarningsBreakdown = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const userId = (req as any).user?.id;

    const myCourier = await prisma.courier.findFirst({
      where: { user_id: userId },
      select: { courier_office_id: true },
    });
    const officeId = myCourier?.courier_office_id;
    if (!officeId) {
      return res.status(404).json({ message: "No office found for this user" });
    }

    const office = await prisma.courierOffice.findUnique({
      where: { id: officeId },
    });
    if (!office) {
      return res.status(404).json({ message: "Office not found" });
    }

    // Period filter
    const period = (req.query.period as string) ?? "month";
    const now = new Date();
    let periodStart: Date;
    if (period === "week") {
      periodStart = new Date(now);
      periodStart.setDate(now.getDate() - 7);
    } else if (period === "year") {
      periodStart = new Date(now);
      periodStart.setFullYear(now.getFullYear() - 1);
    } else {
      periodStart = new Date(now);
      periodStart.setMonth(now.getMonth() - 1);
    }

    const limit = Number(req.query.limit ?? 20);
    const skip = Number(req.query.skip ?? 0);

    // All couriers in this office
    const officeCouriers = await prisma.courier.findMany({
      where: {
        courier_office_id: officeId,
        user_id: { not: userId }, // ── FILTER: Remove current user from general office stats ──
      },
      select: {
        id: true,
        user: { select: { id: true, full_name: true, personal_photo: true } },
      },
      take: limit,
      skip,
    });
    const totalCouriers = await prisma.courier.count({
      where: {
        courier_office_id: officeId,
        user_id: { not: userId }, // ── FILTER: Remove current user from general office stats ──
      },
    });

    // Per-courier delivered order aggregates
    const breakdowns = await Promise.all(
      officeCouriers.map(async (c) => {
        const agg = await prisma.order.aggregate({
          _sum: { courier_fee: true },
          _count: { id: true },
          where: {
            courier_id: c.id,
            status: "DELIVERED",
            created_at: { gte: periodStart },
          },
        });

        const deliveredCount = agg._count.id;
        const courierFeeCents = Number(agg._sum.courier_fee ?? 0);

        let earningsCents = 0;
        if (office.commission_type === "FIXED_PER_ORDER") {
          earningsCents = deliveredCount * Number(office.commission_value);
        } else {
          earningsCents =
            courierFeeCents * (Number(office.commission_value) / 100);
        }

        return {
          id: c.id,
          full_name: c.user?.full_name ?? null,
          personal_photo: c.user?.personal_photo ?? null,
          delivered_count: deliveredCount,
          courier_fee_total_cents: Math.round(courierFeeCents),
          earnings_cents: Math.round(earningsCents),
        };
      }),
    );

    // Office-level totals
    const totalAgg = await prisma.order.aggregate({
      _sum: { courier_fee: true },
      _count: { id: true },
      where: {
        courier_id: { in: officeCouriers.map((c) => c.id) },
        status: "DELIVERED",
        created_at: { gte: periodStart },
      },
    });
    const totalDelivered = totalAgg._count.id;
    const totalFeeCents = Number(totalAgg._sum.courier_fee ?? 0);
    let totalEarningsCents = 0;
    if (office.commission_type === "FIXED_PER_ORDER") {
      totalEarningsCents = totalDelivered * Number(office.commission_value);
    } else {
      totalEarningsCents =
        totalFeeCents * (Number(office.commission_value) / 100);
    }

    return res.status(200).json({
      message: req.t("admin-courier-office:messages.ok"),
      data: {
        summary: {
          total_earnings_cents: Math.round(totalEarningsCents),
          total_delivered: totalDelivered,
          active_couriers: totalCouriers,
          commission_type: office.commission_type,
          commission_value: Number(office.commission_value),
        },
        couriers: breakdowns,
        total: totalCouriers,
        totalPages: Math.ceil(totalCouriers / limit),
      },
    });
  };

  // ============================ deleteCourierOffice ============================
  deleteCourierOffice = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { courierOfficeId } = req.sanitized.params;

    // step: check if courier office exists
    const courierOffice = await prisma.courierOffice.findUnique({
      where: { id: Number(courierOfficeId) },
    });
    if (!courierOffice) {
      return res.status(404).json({
        message: req.t("admin-courier-office:errors.courier_office_not_found"),
      });
    }

    // step: delete courier office
    await prisma.courierOffice.delete({
      where: { id: Number(courierOfficeId) },
    });

    // step: remove all couriers from office
    await prisma.courier.updateMany({
      where: { courier_office_id: Number(courierOfficeId) },
      data: { courier_office_id: null },
    });

    // step: return response
    return res.status(200).json({
      message: req.t("admin-courier-office:messages.courier_office_deleted"),
    });
  };
}
