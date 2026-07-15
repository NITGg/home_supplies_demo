import { NextFunction, Request, Response } from "express";
import {
  updateProfileDTO,
  updateDocumentsDTO,
  updateAreasDTO,
} from "./profile.dto";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { uploadSingleFile } from "../../utils/cloudinary/cloudinary.service";

export class ProfileService {
  constructor() {}

  // ============================ getProfile ============================
  getProfile = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get user with courier data
    const profile = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        courier: {
          include: {
            vehicle: true,
            stat: false,
          },
        },
        wallet: {
          select: {
            balance: true,
            status: true,
          },
        },
      },
    });

    let userResponse = null;
    if (profile) {
      const { password, badge, ...rest } = profile;
      userResponse = rest;
    }

    return responseHandler({
      res,
      message: res.__("messages.profile_retrieved"),
      data: { user: userResponse },
    });
  };

  // ============================ updateProfile ============================
  updateProfile = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const {
      full_name,
      gender,
      language,
      vehicle_id,
      vehicle_plate,
      badge_id,
      courier_office_id,
      min_order_price,
      max_order_price,
    }: updateProfileDTO = res.locals.validatedData;

    // step: check vehicle_id existence
    if (vehicle_id) {
      const isVehicleExist = await prisma.vehicle.findUnique({
        where: { id: Number(vehicle_id) },
      });
      if (!isVehicleExist) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.vehicle_not_found"),
        );
      }
    }

    // step: update User fields (full_name, gender, lang, badge)
    await prisma.user.update({
      where: { id: user.id },
      data: {
        full_name: full_name ?? user.full_name,
        gender: gender ?? user.gender,
        lang: language ?? user.lang,
        ...(badge_id !== undefined && { badge_id }),
      },
    });

    // step: update Courier fields (vehicle_id, vehicle_plate, courier_office_id, budget limits)
    await prisma.courier.update({
      where: { user_id: user.id },
      data: {
        ...(vehicle_id !== undefined && { vehicle_id }),
        ...(vehicle_plate !== undefined && { vehicle_plate }),
        ...(courier_office_id !== undefined && { courier_office_id }),
        ...(min_order_price !== undefined && { min_order_price }),
        ...(max_order_price !== undefined && { max_order_price }),
      },
    });

    // step: get updated profile
    const updatedProfile = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        courier: {
          include: {
            stat: true,
          },
        },
        wallet: {
          select: {
            balance: true,
            status: true,
          },
        },
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.profile_updated"),
      data: { user: updatedProfile },
    });
  };

  // ============================ updateProfileByAdmin ============================
  // Same as updateProfile but the target user is taken from the :userId path param (admin use).
  updateProfileByAdmin = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const userId = Number(req.params.userId);
    if (isNaN(userId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_user_id"),
      );
    }

    // step: get target user with courier data
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { courier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    const {
      full_name,
      gender,
      language,
      vehicle_id,
      vehicle_plate,
      badge_id,
      courier_office_id,
      min_order_price,
      max_order_price,
    }: updateProfileDTO = res.locals.validatedData;

    // step: check vehicle_id existence
    if (vehicle_id) {
      const isVehicleExist = await prisma.vehicle.findUnique({
        where: { id: Number(vehicle_id) },
      });
      if (!isVehicleExist) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.vehicle_not_found"),
        );
      }
    }

    // step: update User fields (full_name, gender, lang, badge)
    await prisma.user.update({
      where: { id: user.id },
      data: {
        full_name: full_name ?? user.full_name,
        gender: gender ?? user.gender,
        lang: language ?? user.lang,
        ...(badge_id !== undefined && { badge_id }),
      },
    });

    // step: update Courier fields (vehicle_id, vehicle_plate, courier_office_id, budget limits)
    await prisma.courier.update({
      where: { user_id: user.id },
      data: {
        ...(vehicle_id !== undefined && { vehicle_id }),
        ...(vehicle_plate !== undefined && { vehicle_plate }),
        ...(courier_office_id !== undefined && { courier_office_id }),
        ...(min_order_price !== undefined && { min_order_price }),
        ...(max_order_price !== undefined && { max_order_price }),
      },
    });

    // step: get updated profile
    const updatedProfile = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        courier: {
          include: {
            stat: true,
          },
        },
        wallet: {
          select: {
            balance: true,
            status: true,
          },
        },
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.profile_updated"),
      data: { user: updatedProfile },
    });
  };

  // ============================ updateDocuments ============================
  updateDocuments = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get courier record for the user
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.courier_not_found"),
      );
    }

    // step: get uploaded files
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const personal_photoFile = files?.personal_photo?.[0];
    const national_id_photo_frontFile = files?.national_id_photo_front?.[0];
    const national_id_photo_backFile = files?.national_id_photo_back?.[0];
    const vehicle_license_frontFile = files?.vehicle_license_front?.[0];
    const vehicle_license_backFile = files?.vehicle_license_back?.[0];
    const courier_license_frontFile = files?.courier_license_front?.[0];
    const courier_license_backFile = files?.courier_license_back?.[0];
    const courier_criminal_recordFile = files?.courier_criminal_record?.[0];

    // step: create pendingUpdates
    const pendingUpdates: any = {};
    if (personal_photoFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: personal_photoFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.personal_photo = secure_url;
    }
    if (national_id_photo_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.national_id_photo_front = secure_url;
    }
    if (national_id_photo_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.national_id_photo_back = secure_url;
    }
    if (vehicle_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.vehicle_license_front = secure_url;
    }
    if (vehicle_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.vehicle_license_back = secure_url;
    }
    if (courier_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.courier_license_front = secure_url;
    }
    if (courier_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.courier_license_back = secure_url;
    }
    if (courier_criminal_recordFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_criminal_recordFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.courier_criminal_record = secure_url;
    }

    // step: save pending update request
    if (Object.keys(pendingUpdates).length > 0) {
      // step: remove old pending request
      await prisma.profileUpdateRequest.deleteMany({
        where: {
          user_id: user.id,
          status: "PENDING",
        },
      });

      await prisma.profileUpdateRequest.create({
        data: {
          user_id: user.id,
          data: pendingUpdates,
          status: "PENDING",
        },
      });

      return responseHandler({
        res,
        message: res.__("messages.documents_pending"),
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.no_document_changes"),
    });
  };

  // ============================ updateDocumentsByAdmin ============================
  // Same as updateDocuments but the target user is taken from the :userId path param (admin use).
  updateDocumentsByAdmin = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const userId = Number(req.params.userId);
    if (isNaN(userId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_user_id"),
      );
    }

    // step: get courier record for the target user
    const courier = await prisma.courier.findUnique({
      where: { user_id: userId },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.courier_not_found"),
      );
    }

    // step: get uploaded files
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const personal_photoFile = files?.personal_photo?.[0];
    const national_id_photo_frontFile = files?.national_id_photo_front?.[0];
    const national_id_photo_backFile = files?.national_id_photo_back?.[0];
    const vehicle_license_frontFile = files?.vehicle_license_front?.[0];
    const vehicle_license_backFile = files?.vehicle_license_back?.[0];
    const courier_license_frontFile = files?.courier_license_front?.[0];
    const courier_license_backFile = files?.courier_license_back?.[0];
    const courier_criminal_recordFile = files?.courier_criminal_record?.[0];

    // step: create pendingUpdates
    const pendingUpdates: any = {};
    if (personal_photoFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: personal_photoFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.personal_photo = secure_url;
    }
    if (national_id_photo_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.national_id_photo_front = secure_url;
    }
    if (national_id_photo_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.national_id_photo_back = secure_url;
    }
    if (vehicle_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.vehicle_license_front = secure_url;
    }
    if (vehicle_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.vehicle_license_back = secure_url;
    }
    if (courier_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.courier_license_front = secure_url;
    }
    if (courier_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.courier_license_back = secure_url;
    }
    if (courier_criminal_recordFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_criminal_recordFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      pendingUpdates.courier_criminal_record = secure_url;
    }

    // step: save pending update request
    if (Object.keys(pendingUpdates).length > 0) {
      // step: remove old pending request
      await prisma.profileUpdateRequest.deleteMany({
        where: {
          user_id: userId,
          status: "PENDING",
        },
      });

      await prisma.profileUpdateRequest.create({
        data: {
          user_id: userId,
          data: pendingUpdates,
          status: "PENDING",
        },
      });

      return responseHandler({
        res,
        message: res.__("messages.documents_pending"),
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.no_document_changes"),
    });
  };

  // ============================ badgeProgress ============================
  badgeProgress = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get current badge and stats from User
    const userData = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        courier: {
          include: {
            stat: false,
          },
        },
      },
    });

    // step: get all badges ordered by requirements
    const allBadges = await prisma.userBadge.findMany({
      orderBy: { name: "asc" },
    });

    return responseHandler({
      res,
      message: res.__("messages.badge_progress_retrieved"),
      data: {
        current_badge: userData?.badge,
        all_badges: allBadges,
      },
    });
  };

  // ============================ getSelectedAreas ============================
  getSelectedAreas = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;

    // step: get courier record for the user
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.courier_not_found"),
      );
    }

    // step: get courier selected areas
    const courierAreas = await prisma.courierSelectedArea.findMany({
      where: { courier_id: courier.id },
      include: {
        area: true,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.areas_retrieved"),
      data: { areas: courierAreas },
    });
  };

  // ============================ locationGovernorates ============================
  locationGovernorates = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const is_active = res.locals.validatedData?.is_active;

    let filter: any = {};
    if (is_active !== undefined) {
      filter.is_active = is_active;
    }

    // step: get all governorates
    const governorates = await prisma.governorate.findMany({
      where: filter,
      orderBy: { name: "asc" },
    });

    return responseHandler({
      res,
      message: res.__("messages.governorates_retrieved"),
      data: { governorates },
    });
  };

  // ============================ locationGovernoratesAreas ============================
  locationGovernoratesAreas = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const id = parseInt(req.params.id as string);
    const is_active = res.locals.validatedData?.is_active;

    // step: validate id
    if (isNaN(id)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_governorate_id"),
      );
    }

    // step: check governorate exists
    const governorate = await prisma.governorate.findUnique({
      where: { id },
    });
    if (!governorate) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.governorate_not_found"),
      );
    }

    let filter: any = { governorate_id: id };
    if (is_active !== undefined) {
      filter.is_active = is_active;
    }

    // step: get areas for this governorate
    const areas = await prisma.area.findMany({
      where: filter,
      orderBy: { name: "asc" },
    });

    return responseHandler({
      res,
      message: res.__("messages.areas_retrieved"),
      data: { governorate, areas },
    });
  };

  // ============================ updateSelectedAreas ============================
  updateSelectedAreas = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const { areas }: updateAreasDTO = res.locals.validatedData;

    // step: get courier record for the user
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.courier_not_found"),
      );
    }

    // step: check courier_max_selected_areas
    const appSettings = await prisma.applicationSetting.findFirst();
    if (!appSettings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "ApplicationSettigns record not found",
      );
    }
    if (areas.length > appSettings.courier_max_selected_areas) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.too_many_selected_areas"),
      );
    }

    // step: delete old areas and create new ones
    await prisma.$transaction(async (tx) => {
      await tx.courierSelectedArea.deleteMany({
        where: { courier_id: courier.id },
      });

      if (areas && areas.length > 0) {
        await tx.courierSelectedArea.createMany({
          data: areas.map((area: { area_id: number }) => ({
            courier_id: courier.id,
            area_id: area.area_id,
          })),
        });
      }
    });

    // step: get updated areas
    const updatedAreas = await prisma.courierSelectedArea.findMany({
      where: { courier_id: courier.id },
      include: {
        area: true,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.areas_updated"),
      data: { areas: updatedAreas },
    });
  };

  // ============================ softDelete ============================
  softDelete = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: validate not already soft-deleted
    if (user.deleted_at) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.account_already_deleted"),
      );
    }

    // step: get courier record for the user
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    // step: check for active orders (only if the user is a courier)
    if (courier) {
      const activeOrder = await prisma.order.findFirst({
        where: {
          courier_id: courier.id,
          status: {
            in: ["PENDING", "IN_PROGRESS"],
          },
        },
      });

      if (activeOrder) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_active_orders"),
        );
      }
    }

    // step: check for unpaid commissions
    const unpaidCommission = await prisma.unpaidCommission.findFirst({
      where: { user_id: user.id, is_paid: false },
    });
    if (unpaidCommission) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_unpaid_commissions"),
      );
    }

    // step: check for unpaid penalties
    const unpaidPenalty = await prisma.penalty.findFirst({
      where: { user_id: user.id, is_paid: false, is_waived: false },
    });
    if (unpaidPenalty) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_unpaid_penalties"),
      );
    }

    // step: soft delete
    // Mangle phone/email with timestamp to free unique constraints for re-registration
    const ts = Date.now();
    const deletedPhone = user.phone ? `del_${ts}_${user.phone}` : null;
    const deletedEmail = user.email ? `del_${ts}_${user.email}` : null;

    await prisma.$transaction(async (tx) => {
      // Deactivate user and mark as deleted
      await tx.user.update({
        where: { id: user.id },
        data: {
          deleted_at: new Date(),
          is_active: false,
          phone: deletedPhone,
          email: deletedEmail,
          fcm_token: null, // clear push notifications
        },
      });

      // Soft-delete courier record if exists
      if (courier) {
        await tx.courier.update({
          where: { id: courier.id },
          data: { deleted_at: new Date() },
        });
      }
    });

    return responseHandler({
      res,
      message: res.__("messages.account_deletion_marked"),
    });
  };

  // ============================ hardDelete ============================
  hardDelete = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get courier data associated with user
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    // step: check for active orders
    if (courier) {
      const activeOrder = await prisma.order.findFirst({
        where: {
          courier_id: courier.id,
          status: {
            in: ["PENDING", "IN_PROGRESS"],
          },
        },
      });

      if (activeOrder) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_active_orders"),
        );
      }
    }

    // step: check for unpaid commissions
    const unpaidCommission = await prisma.unpaidCommission.findFirst({
      where: { user_id: user.id, is_paid: false },
    });
    if (unpaidCommission) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_unpaid_commissions"),
      );
    }

    // step: check for unpaid penalties
    const unpaidPenalty = await prisma.penalty.findFirst({
      where: { user_id: user.id, is_paid: false, is_waived: false },
    });
    if (unpaidPenalty) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_unpaid_penalties"),
      );
    }

    // step: delete related data and user in a transaction
    await prisma.$transaction(async (tx) => {
      // --- Relations with NO onDelete rule (will cause FK errors if not handled) ---

      // Chat: created_by has no onDelete rule, must unlink manually
      await tx.chat.updateMany({
        where: { created_by: user.id },
        data: { deleted_at: new Date() },
      });

      // --- Relations with onDelete: SetNull (handled by DB, but we clean up for consistency) ---

      // Unlink orders from courier
      if (courier) {
        await tx.order.updateMany({
          where: { courier_id: courier.id },
          data: { courier_id: null },
        });

        // Unlink order proposals
        await tx.orderProposal.updateMany({
          where: { courier_id: courier.id },
          data: { courier_id: null },
        });

        // Unlink order issues from courier
        await tx.orderIssue.updateMany({
          where: { courier_id: courier.id },
          data: { courier_id: null },
        });
      }

      // Unlink orders from customer (user)
      await tx.order.updateMany({
        where: { customer_id: user.id },
        data: { customer_id: null },
      });

      // Nullify unpaid commissions user reference
      await tx.unpaidCommission.updateMany({
        where: { user_id: user.id },
        data: { user_id: null },
      });

      // Nullify penalties user reference
      await tx.penalty.updateMany({
        where: { user_id: user.id },
        data: { user_id: null },
      });

      // Nullify wallet user reference
      await tx.wallet.updateMany({
        where: { user_id: user.id },
        data: { user_id: null },
      });

      // Nullify coupon usages
      await tx.courierCouponUsage.updateMany({
        where: { user_id: user.id },
        data: { user_id: null },
      });
      await tx.customerCouponUsage.updateMany({
        where: { user_id: user.id },
        data: { user_id: null },
      });

      // Nullify order issues from customer
      await tx.orderIssue.updateMany({
        where: { customer_id: user.id },
        data: { customer_id: null },
      });

      // --- Finally delete user (Cascade will auto-delete: Courier, UserVerify, ---
      // --- Notification, NotificationSetting, ChatParticipant, ChatMessage,    ---
      // --- PaymentMethod, CustomerAddress, Cart, SupplierReviewFromCustomer,   ---
      // --- and via Courier cascade: CourierStat, CourierSelectedArea,           ---
      // --- ProfileUpdateRequest, CourierReviewFromCustomer,                     ---
      // --- CustomerReviewFromCourier, CourierReviewFromSupplier,                ---
      // --- SupplierReviewFromCourier)                                          ---
      await tx.user.delete({ where: { id: user.id } });
    });

    return responseHandler({
      res,
      message: res.__("messages.account_deleted"),
    });
  };
}
