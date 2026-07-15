import { prisma } from "@/config/prisma";
import { NextFunction, Request, Response } from "express";
import { applyFilters, buildPaginationResponse } from "@/lib/filter";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";
import { HttpError } from "@/lib/httpError";
export class AdminVehicleService {
  constructor() {}

  // ============================ listVehicles ============================
  listVehicles = async (req: Request, res: Response, next: NextFunction) => {
    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        name: "contains",
        name_ar: "contains",
        price_per_km: "exact",
        min_distance_per_km: "range",
        max_distance_per_km: "range",
        min_delivery_fee: "range",
        delivery_price_for_each_1m: "range",
        delivery_fee_ratio: "range",
        total_fines: "range",
      },
    );

    const [vehicles, total] = await Promise.all([
      prisma.vehicle.findMany({
        where: filters,
        ...pagination,
      }),
      prisma.vehicle.count({ where: filters }),
    ]);

    return res.json({
      data: {
        vehicles,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ vehicle============================
  vehicle = async (req: Request, res: Response, next: NextFunction) => {
    const { vehicleId } = res.locals.validatedData;

    const vehicle = await prisma.vehicle.findUnique({
      where: { id: vehicleId },
    });

    if (!vehicle) {
      return res.status(404).json({
        message: req.t("admin-vehicle:errors.vehicle_not_found"),
      });
    }

    return res.json({
      data: { vehicle },
    });
  };

  // ============================ createVehicle ============================
  createVehicle = async (req: Request, res: Response, next: NextFunction) => {
    const data = res.locals.validatedData;
    const file = req.file;

    // step: check name is unique
    const isVehicleExist = await prisma.vehicle.findFirst({
      where: { name: data.name, name_ar: data.name_ar },
    });
    if (isVehicleExist) {
      return res.status(400).json({
        message: req.t("admin-vehicle:errors.vehicle_exist"),
      });
    }

    // Process icon upload
    let iconUrl;
    if (file) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: file.path, // .path or .buffer
        storagePathOnCloudinary: "vehicles",
      });
      iconUrl = secure_url;
    }

    const vehicle = await prisma.vehicle.create({
      data: {
        ...data,
        ...(iconUrl && { icon: iconUrl }),
      },
    });

    return res.json({
      message: req.t("admin-vehicle:messages.vehicle_created"),
      data: { vehicle },
    });
  };

  // ============================ updateVehicle ============================
  updateVehicle = async (req: Request, res: Response, next: NextFunction) => {
    const { vehicleId, ...data } = res.locals.validatedData;
    const file = req.file;

    // Check existence
    const exists = await prisma.vehicle.findUnique({
      where: { id: vehicleId },
    });

    if (!exists) {
      return res.status(404).json({
        message: req.t("admin-vehicle:errors.vehicle_not_found"),
      });
    }

    let iconUrl = exists.icon;
    if (file) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: file.path, // .path or .buffer
        storagePathOnCloudinary: "vehicles",
      });
      iconUrl = secure_url;
      // Delete old icon from Cloudinary
      if (exists.icon) {
        const publicId = extractPublicIdFromUrl(exists.icon);
        if (publicId) {
          await destroySingleFile({ public_id: publicId }).catch((err) =>
            console.error(err),
          );
        }
      }
    }

    const vehicle = await prisma.vehicle.update({
      where: { id: vehicleId },
      data: {
        ...data,
        icon: iconUrl,
      },
    });

    return res.json({
      message: req.t("admin-vehicle:messages.vehicle_updated"),
      data: { vehicle },
    });
  };

  // ============================ deleteVehicle============================
  deleteVehicle = async (req: Request, res: Response, next: NextFunction) => {
    const { vehicleId } = res.locals.validatedData;

    const vehicle = await prisma.vehicle.findUnique({
      where: { id: vehicleId },
    });

    if (!vehicle) {
      return res.status(404).json({
        message: req.t("admin-vehicle:errors.vehicle_not_found"),
      });
    }

    await prisma.vehicle.delete({ where: { id: vehicleId } });

    return res.json({
      message: req.t("admin-vehicle:messages.vehicle_deleted"),
    });
  };
}
