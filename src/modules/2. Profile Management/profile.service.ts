import { OrderStatus, RefundStatus } from "@prisma/client";
import { NextFunction, Request, Response } from "express";
import {
  updateProfileDTO,
  updateDocumentsDTO,
  updateAreasDTO,
  createSupplierSlotMaxOrderDTO,
  updateSupplierSlotMaxOrderDTO,
  listSupplierSlotMaxOrderDTO,
  deleteSupplierSlotMaxOrderDTO,
  supplierSlotMaxOrderStatusDTO,
} from "./profile.dto";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import {
  uploadSingleFile,
  destroySingleFile,
  extractPublicIdFromUrl,
} from "../../utils/cloudinary/cloudinary.service";
import FeatureApi from "../../utils/featureApi";

export class ProfileService {
  constructor() {}
  private readonly SUPPLIER_ROLE_NAME = "SUPPLIER";
  private readonly ADMIN_ROLE_NAME = "ADMIN";

  // ============================ getProfile ============================
  getProfile = async (req: Request, res: Response, next: NextFunction) => {
    const { userId } = res.locals.validatedData as { userId: number };
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if user is supplier
    const supplierRole = await prisma.userRole.findUnique({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_role_not_found"),
      );
    }
    if (user.role_id !== supplierRole.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.not_supplier"),
      );
    }

    // step: get user with supplier data
    const profile = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        supplier: {
          include: {
            stats: false,
            addresses: true,
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
    const { userId } = res.locals.validatedData as { userId: number };
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if user is supplier
    const supplierRole = await prisma.userRole.findUnique({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_role_not_found"),
      );
    }
    if (user.role_id !== supplierRole.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.not_supplier"),
      );
    }

    const {
      full_name,
      phone,
      gender,
      language,
      type_id,
      badge_id,
      synonyms,
      tax_card,
      commercial_register,
      min_price_for_one_order,
      max_price_for_one_order,
      shopping_min_price_for_one_order,
      shopping_max_price_for_one_order,
      shopping_budget_fee,
      area_id,
      address_line_1,
      address_line_2,
      city,
      state,
      country,
      google_map_link,
      latitude,
      longitude,
      contact_name,
      contact_phone,
      working_hours,
    }: updateProfileDTO = res.locals.validatedData;

    // step: get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      return responseHandler({
        res,
        message: res.__("messages.supplier_not_found"),
        status: 404,
      });
    }

    // step: get SupplierStoreAddress
    const supplierStoreAddress = await prisma.supplierStoreAddress.findFirst({
      where: { supplier_id: supplier.id },
    });
    if (!supplierStoreAddress) {
      return responseHandler({
        res,
        message: res.__("messages.supplier_store_address_not_found"),
        status: 404,
      });
    }

    // step: check phone uniqueness if phone is being updated
    if (phone && phone !== user.phone) {
      const existingUserWithPhone = await prisma.user.findUnique({
        where: { phone },
      });
      if (existingUserWithPhone) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.phone_already_exists"),
        );
      }
    }

    // step: update User
    await prisma.user.update({
      where: { id: user.id },
      data: {
        full_name: full_name ?? user.full_name,
        phone: phone ?? user.phone,
        gender: gender ?? user.gender,
        lang: language ?? user.lang,
        badge_id: badge_id ? Number(badge_id) : user.badge_id,
      },
    });

    // step: update Supplier
    await prisma.supplier.update({
      where: { user_id: user.id },
      data: {
        type_id: type_id ? Number(type_id) : supplier.type_id,
        synonyms: synonyms ? synonyms : supplier.synonyms,
        tax_card: tax_card ? tax_card : supplier.tax_card,
        commercial_register: commercial_register
          ? commercial_register
          : supplier.commercial_register,
        min_price_for_one_order: min_price_for_one_order
          ? min_price_for_one_order
          : supplier.min_price_for_one_order,
        max_price_for_one_order: max_price_for_one_order
          ? max_price_for_one_order
          : supplier.max_price_for_one_order,
        shopping_min_price_for_one_order: shopping_min_price_for_one_order
          ? shopping_min_price_for_one_order
          : supplier.shopping_min_price_for_one_order,
        shopping_max_price_for_one_order: shopping_max_price_for_one_order
          ? shopping_max_price_for_one_order
          : supplier.shopping_max_price_for_one_order,
        shopping_budget_fee: shopping_budget_fee
          ? shopping_budget_fee
          : supplier.shopping_budget_fee,
      },
    });

    // step: check working hours not overlaps
    if (working_hours) {
      const days = (working_hours as any).days;
      if (days) {
        for (const day in days) {
          const dayData = days[day];
          if (!dayData.is_closed && dayData.slots && dayData.slots.length > 0) {
            const sortedSlots = [...dayData.slots].sort((a: any, b: any) => {
              if (a.open < b.open) return -1;
              if (a.open > b.open) return 1;
              return 0;
            });

            for (let i = 0; i < sortedSlots.length; i++) {
              if (sortedSlots[i].open >= sortedSlots[i].close) {
                throw new AppError(
                  HttpStatusCode.BAD_REQUEST,
                  res.__("errors.invalid_time"),
                );
              }
              if (i < sortedSlots.length - 1) {
                if (sortedSlots[i].close > sortedSlots[i + 1].open) {
                  throw new AppError(
                    HttpStatusCode.BAD_REQUEST,
                    res.__("errors.working_hours_overlap"),
                  );
                }
              }
            }
          }
        }
      }
    }

    // step: update SupplierStoreAddress
    await prisma.supplierStoreAddress.update({
      where: { id: supplierStoreAddress.id },
      data: {
        area_id: area_id ? area_id : supplierStoreAddress.area_id,
        address_line_1: address_line_1
          ? address_line_1
          : supplierStoreAddress.address_line_1,
        address_line_2: address_line_2
          ? address_line_2
          : supplierStoreAddress.address_line_2,
        city: city ? city : supplierStoreAddress.city,
        state: state ? state : supplierStoreAddress.state,
        country: country ? country : supplierStoreAddress.country,
        google_map_link: google_map_link
          ? google_map_link
          : supplierStoreAddress.google_map_link,
        latitude: latitude ? latitude : supplierStoreAddress.latitude,
        longitude: longitude ? longitude : supplierStoreAddress.longitude,
        contact_name: contact_name
          ? contact_name
          : supplierStoreAddress.contact_name,
        contact_phone: contact_phone
          ? contact_phone
          : supplierStoreAddress.contact_phone,
        working_hours: working_hours
          ? (working_hours as any)
          : supplierStoreAddress.working_hours,
      },
    });

    // step: get updated profile
    const updatedProfile = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        supplier: {
          include: {
            stats: true,
            addresses: true,
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
    const { userId } = res.locals.validatedData as { userId: number };
    const { national_id_number }: updateDocumentsDTO = res.locals.validatedData;

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if user is supplier
    const supplierRole = await prisma.userRole.findUnique({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_role_not_found"),
      );
    }
    if (user.role_id !== supplierRole.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.not_supplier"),
      );
    }

    // step: check national_id_number existence
    if (national_id_number) {
      const isNationalIdExist = await prisma.supplier.findFirst({
        where: { national_id_number },
      });
      if (isNationalIdExist) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.national_id_already_exists"),
        );
      }
    }

    // step: get supplier record for the user
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });

    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    // step: get uploaded files
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const personalPhotoFile = files?.personal_photo?.[0];
    const nationalIdPhotoFrontFile = files?.national_id_photo_front?.[0];
    const nationalIdPhotoBackFile = files?.national_id_photo_back?.[0];
    const supplier_criminal_recordFile = files?.supplier_criminal_record?.[0];

    // step: create pendingUpdates
    const pendingUpdates: any = {};
    if (personalPhotoFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: personalPhotoFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Supplier",
      });
      pendingUpdates.personal_photo = secure_url;
    }
    if (nationalIdPhotoFrontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: nationalIdPhotoFrontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Supplier",
      });
      pendingUpdates.national_id_photo_front = secure_url;
    }
    if (nationalIdPhotoBackFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: nationalIdPhotoBackFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Supplier",
      });
      pendingUpdates.national_id_photo_back = secure_url;
    }
    if (supplier_criminal_recordFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: supplier_criminal_recordFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Supplier",
      });
      pendingUpdates.supplier_criminal_record = secure_url;
    }
    if (national_id_number) {
      pendingUpdates.national_id_number = national_id_number;
    }

    // step: update supplier documents
    await prisma.user.update({
      where: {
        id: userId,
      },
      data: {
        personal_photo: pendingUpdates.personal_photo ?? user.personal_photo,
      },
    });

    await prisma.supplier.update({
      where: { user_id: userId },
      data: {
        national_id_number:
          pendingUpdates.national_id_number ?? supplier.national_id_number,

        national_id_photo_front:
          pendingUpdates.national_id_photo_front ??
          supplier.national_id_photo_front,

        national_id_photo_back:
          pendingUpdates.national_id_photo_back ??
          supplier.national_id_photo_back,

        supplier_criminal_record:
          pendingUpdates.supplier_criminal_record ??
          supplier.supplier_criminal_record,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.profile_documents_awaiting_approval"),
    });

    //TODO: step: save pending update request
    // if (Object.keys(pendingUpdates).length > 0) {
    //   // step: remove old pending request
    //   await prisma.profileUpdateRequest.deleteMany({
    //     where: {
    //       user_id: user.id,
    //       status: "PENDING",
    //     },
    //   });

    //   await prisma.profileUpdateRequest.create({
    //     data: {
    //       user_id: user.id,
    //       data: pendingUpdates,
    //       status: "PENDING",
    //     },
    //   });

    //   return responseHandler({
    //     res,
    //     message: res.__("messages.documents_pending"),
    //   });
    // }
  };

  // ============================ badgeProgress ============================
  badgeProgress = async (req: Request, res: Response, next: NextFunction) => {
    const { userId } = res.locals.validatedData as { userId: number };
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if user is supplier
    const supplierRole = await prisma.userRole.findUnique({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_role_not_found"),
      );
    }
    if (user.role_id !== supplierRole.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.not_supplier"),
      );
    }

    // step: get current badge and stats from User
    const userData = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        badge: true,
        supplier: {
          include: {
            stats: false,
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

  // ============================ softDelete ============================
  softDelete = async (req: Request, res: Response, next: NextFunction) => {
    const { userId } = res.locals.validatedData as { userId: number };
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if user is supplier or admin
    const supplierRole = await prisma.userRole.findUnique({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    const adminRole = await prisma.userRole.findUnique({
      where: { name: this.ADMIN_ROLE_NAME },
    });
    if (!supplierRole || !adminRole) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_or_admin_role_not_found"),
      );
    }
    if (user.role_id !== supplierRole.id && user.role_id !== adminRole.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.not_supplier_or_admin"),
      );
    }

    // step: validate not already deleted
    if (user.deleted_at) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.account_already_deleted"),
      );
    }

    // step: get user with all related data
    const userData = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        supplier: true,
        courier: true,
        wallet: true,
      },
    });

    if (!userData) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check for active orders based on user role
    const activeOrderStatuses: OrderStatus[] = [
      OrderStatus.PENDING,
      OrderStatus.IN_PROGRESS,
    ];

    // Check supplier active orders
    if (userData.supplier) {
      const activeSupplierOrders = await prisma.order.findFirst({
        where: {
          supplier_id: userData.supplier.id,
          status: { in: activeOrderStatuses },
        },
      });
      if (activeSupplierOrders) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_active_orders"),
        );
      }
    }

    // Check courier active orders
    if (userData.courier) {
      const activeCourierOrders = await prisma.order.findFirst({
        where: {
          courier_id: userData.courier.id,
          status: { in: activeOrderStatuses },
        },
      });
      if (activeCourierOrders) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_active_orders"),
        );
      }
    }

    // Check customer active orders
    const activeCustomerOrders = await prisma.order.findFirst({
      where: {
        customer_id: user.id,
        status: { in: activeOrderStatuses },
      },
    });
    if (activeCustomerOrders) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_active_orders"),
      );
    }

    // step: check for unpaid commissions
    const unpaidCommissions = await prisma.unpaidCommission.findFirst({
      where: {
        user_id: user.id,
        is_paid: false,
      },
    });
    if (unpaidCommissions) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_unpaid_commissions"),
      );
    }

    // step: check for wallet balance
    if (userData.wallet && userData.wallet.balance > 0) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_wallet_balance"),
      );
    }

    // step: check for escrow funds (linked via wallet)
    if (userData.wallet) {
      const activeEscrows = await prisma.escrow.findFirst({
        where: {
          wallet_id: userData.wallet.id,
          held_amount: { gt: 0 },
        },
      });
      if (activeEscrows) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_escrow_funds"),
        );
      }
    }

    // step: check for pending refunds
    const pendingRefunds = await prisma.refund.findFirst({
      where: {
        requested_by_id: user.id,
        status: { in: [RefundStatus.REQUESTED, RefundStatus.PROCESSING] },
      },
    });
    if (pendingRefunds) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_pending_refunds"),
      );
    }

    // step: soft delete - mark phone/email as deleted to allow reuse
    const deletedPhone = user.phone
      ? `deleted_${user.phone}_${Date.now()}`
      : null;
    const deletedEmail = user.email
      ? `deleted_${user.email}_${Date.now()}`
      : null;

    await prisma.user.update({
      where: { id: user.id },
      data: {
        deleted_at: new Date(),
        is_active: false,
        phone: deletedPhone,
        email: deletedEmail,
        fcm_token: null,
      },
    });

    // step: soft delete supplier if exists
    if (userData.supplier) {
      await prisma.supplier.update({
        where: { id: userData.supplier.id },
        data: {
          deleted_at: new Date(),
          is_approved: false,
        },
      });
    }

    // step: soft delete courier if exists
    if (userData.courier) {
      await prisma.courier.update({
        where: { id: userData.courier.id },
        data: {
          deleted_at: new Date(),
          is_approved: false,
        },
      });
    }

    // step: soft delete wallet if exists
    if (userData.wallet) {
      await prisma.wallet.update({
        where: { id: userData.wallet.id },
        data: {
          deleted_at: new Date(),
          status: "FROZEN",
        },
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.account_deletion_marked"),
    });
  };

  // ============================ hardDelete ============================
  hardDelete = async (req: Request, res: Response, next: NextFunction) => {
    const { userId } = res.locals.validatedData as { userId: number };
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if user is supplier or admin
    const supplierRole = await prisma.userRole.findUnique({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    const adminRole = await prisma.userRole.findUnique({
      where: { name: this.ADMIN_ROLE_NAME },
    });
    if (!supplierRole || !adminRole) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_or_admin_role_not_found"),
      );
    }
    if (user.role_id !== supplierRole.id && user.role_id !== adminRole.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.not_supplier_or_admin"),
      );
    }

    // step: get user with all related data
    const userData = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        supplier: true,
        courier: true,
        wallet: true,
      },
    });

    if (!userData) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check for active orders based on user role
    const activeOrderStatuses: OrderStatus[] = [
      OrderStatus.PENDING,
      OrderStatus.IN_PROGRESS,
    ];

    // Check supplier active orders
    if (userData.supplier) {
      const activeSupplierOrders = await prisma.order.findFirst({
        where: {
          supplier_id: userData.supplier.id,
          status: { in: activeOrderStatuses },
        },
      });
      if (activeSupplierOrders) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_active_orders"),
        );
      }
    }

    // Check courier active orders
    if (userData.courier) {
      const activeCourierOrders = await prisma.order.findFirst({
        where: {
          courier_id: userData.courier.id,
          status: { in: activeOrderStatuses },
        },
      });
      if (activeCourierOrders) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_active_orders"),
        );
      }
    }

    // Check customer active orders
    const activeCustomerOrders = await prisma.order.findFirst({
      where: {
        customer_id: user.id,
        status: { in: activeOrderStatuses },
      },
    });
    if (activeCustomerOrders) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_active_orders"),
      );
    }

    // step: check for unpaid commissions
    const unpaidCommissions = await prisma.unpaidCommission.findFirst({
      where: {
        user_id: user.id,
        is_paid: false,
      },
    });
    if (unpaidCommissions) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_unpaid_commissions"),
      );
    }

    // step: check for wallet balance
    if (userData.wallet && userData.wallet.balance > 0) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_wallet_balance"),
      );
    }

    // step: check for escrow funds (linked via wallet)
    if (userData.wallet) {
      const activeEscrows = await prisma.escrow.findFirst({
        where: {
          wallet_id: userData.wallet.id,
          held_amount: { gt: 0 },
        },
      });
      if (activeEscrows) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.cannot_delete_escrow_funds"),
        );
      }
    }

    // step: check for pending refunds
    const pendingRefunds = await prisma.refund.findFirst({
      where: {
        requested_by_id: user.id,
        status: { in: [RefundStatus.REQUESTED, RefundStatus.PROCESSING] },
      },
    });
    if (pendingRefunds) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_delete_pending_refunds"),
      );
    }

    // step: delete related images from Cloudinary
    try {
      const imagesToDelete = [
        userData.personal_photo,
        userData.supplier?.national_id_photo_front,
        userData.supplier?.national_id_photo_back,
        userData.supplier?.supplier_criminal_record,
      ].filter(Boolean) as string[];

      for (const imageUrl of imagesToDelete) {
        const publicId = extractPublicIdFromUrl(imageUrl);
        if (publicId) {
          await destroySingleFile({ public_id: publicId });
        }
      }
    } catch (error) {
      console.error(
        "[ProfileService] Error deleting images from Cloudinary during hardDelete:",
        error,
      );
    }

    // step: hard delete all user data in a transaction
    await prisma.$transaction(async (tx) => {
      // Delete courier-related data
      if (userData.courier) {
        await tx.courierSelectedArea.deleteMany({
          where: { courier_id: userData.courier.id },
        });
        await tx.orderProposal.deleteMany({
          where: { courier_id: userData.courier.id },
        });
        await tx.courierReviewFromCustomer.deleteMany({
          where: { courier_id: userData.courier.id },
        });
        await tx.courierReviewFromSupplier.deleteMany({
          where: { courier_id: userData.courier.id },
        });
        await tx.courierStat.deleteMany({
          where: { courier_id: userData.courier.id },
        });
        await tx.profileUpdateRequest.deleteMany({
          where: { user_id: userData.courier.id },
        });
        await tx.unavailableAreaRequest.deleteMany({
          where: { customer_id: user.id },
        });
        await tx.courierCouponUsage.deleteMany({
          where: { user_id: user.id },
        });
        await tx.courier.delete({
          where: { id: userData.courier.id },
        });
      }

      // Delete supplier-related data
      if (userData.supplier) {
        await tx.supplierStoreAddress.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.contract.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.supplierStat.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.courierReviewFromSupplier.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.supplierReviewFromCustomer.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.supplierReviewFromCourier.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.supplierProduct.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.supplierCategory.deleteMany({
          where: { supplier_id: userData.supplier.id },
        });
        await tx.supplier.delete({
          where: { id: userData.supplier.id },
        });
      }

      // Delete user-related data (that doesn't have cascade delete)
      await tx.customerAddress.deleteMany({
        where: { customer_id: user.id },
      });
      await tx.customerReviewFromCourier.deleteMany({
        where: { customer_id: user.id },
      });
      await tx.chatParticipant.deleteMany({
        where: { user_id: user.id },
      });
      await tx.chatMessage.deleteMany({
        where: { sender_id: user.id },
      });
      await tx.customerCouponUsage.deleteMany({
        where: { user_id: user.id },
      });
      await tx.paymentMethod.deleteMany({
        where: { user_id: user.id },
      });
      await tx.userVerify.deleteMany({
        where: { user_id: user.id },
      });
      await tx.cart.deleteMany({
        where: { id: user.id },
      });

      // Delete wallet and related data
      if (userData.wallet) {
        await tx.transaction.deleteMany({
          where: { wallet_id: userData.wallet.id },
        });
        await tx.escrow.deleteMany({
          where: { wallet_id: userData.wallet.id },
        });
        await tx.wallet.delete({
          where: { id: userData.wallet.id },
        });
      }

      // Finally, delete the user
      await tx.user.delete({
        where: { id: user.id },
      });
    });

    return responseHandler({
      res,
      message: res.__("messages.account_deleted"),
    });
  };

  // ============================ createSupplierSlotMaxOrder ============================
  createSupplierSlotMaxOrder = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { store_address_id, day_of_week, time_from, time_to, max_orders } =
      res.locals.validatedData as createSupplierSlotMaxOrderDTO;

    // step: check store address
    const storeAddress = await prisma.supplierStoreAddress.findFirst({
      where: {
        id: store_address_id,
      },
    });
    if (!storeAddress) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.store_address_not_found"),
      );
    }

    // step: check time validation
    if (time_from >= time_to) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_time"),
      );
    }

    // step: check working hours
    if (!storeAddress.working_hours) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.working_hours_not_configured"),
      );
    }
    const workingHours = storeAddress.working_hours as any;
    const dayData = workingHours.days?.[String(day_of_week)];
    if (!dayData || dayData.is_closed) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.store_closed"),
      );
    }
    const storeSlots = dayData.slots || [];
    const isWithinWorkingHours = storeSlots.some((slot: any) => {
      return slot.open <= time_from && time_to <= slot.close;
    });
    if (!isWithinWorkingHours) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.outside_working_hours"),
      );
    }

    // step: check overlap
    const overlap = await prisma.supplierSlotMaxOrder.findFirst({
      where: {
        store_address_id,
        day_of_week,
        time_from: { lt: time_to },
        time_to: { gt: time_from },
      },
    });

    if (overlap) {
      throw new AppError(HttpStatusCode.BAD_REQUEST, res.__("errors.overlap"));
    }

    // step: create new slot
    const createdSlot = await prisma.supplierSlotMaxOrder.create({
      data: {
        store_address_id,
        day_of_week,
        time_from,
        time_to,
        max_orders: max_orders ?? null,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.slot_added"),
      data: { createdSlot },
    });
  };

  // ============================ updateSupplierSlotMaxOrder ============================
  updateSupplierSlotMaxOrder = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierSlotMaxOrderId, time_from, time_to, max_orders } = res
      .locals.validatedData as updateSupplierSlotMaxOrderDTO;

    // step: check slot existence
    const existingSlot = await prisma.supplierSlotMaxOrder.findUnique({
      where: { id: supplierSlotMaxOrderId },
    });
    if (!existingSlot) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.slot_not_found"),
      );
    }

    // step: check store address existence
    const storeAddress = await prisma.supplierStoreAddress.findFirst({
      where: {
        id: existingSlot.store_address_id,
      },
    });
    if (!storeAddress) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.store_address_not_found"),
      );
    }

    // step: check time validation
    const final_time_from = time_from ?? existingSlot.time_from;
    const final_time_to = time_to ?? existingSlot.time_to;
    if (final_time_from >= final_time_to) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_time"),
      );
    }

    // step: check working hours
    if (!storeAddress.working_hours) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.working_hours_not_configured"),
      );
    }
    const workingHours = storeAddress.working_hours as any;
    const dayData = workingHours.days?.[String(existingSlot.day_of_week)];
    if (!dayData || dayData.is_closed) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.store_closed") || "Store is closed on this day",
      );
    }
    const storeSlots = dayData.slots || [];
    const isWithinWorkingHours = storeSlots.some((slot: any) => {
      return slot.open <= final_time_from && final_time_to <= slot.close;
    });
    if (!isWithinWorkingHours) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.outside_working_hours") ||
          "Slot is outside of store working hours",
      );
    }

    // step: check overlap
    const overlap = await prisma.supplierSlotMaxOrder.findFirst({
      where: {
        id: { not: supplierSlotMaxOrderId },
        store_address_id: existingSlot.store_address_id,
        day_of_week: existingSlot.day_of_week,
        time_from: { lt: final_time_to },
        time_to: { gt: final_time_from },
      },
    });
    if (overlap) {
      throw new AppError(HttpStatusCode.BAD_REQUEST, res.__("errors.overlap"));
    }

    // step: update slot
    const updatedSlot = await prisma.supplierSlotMaxOrder.update({
      where: { id: supplierSlotMaxOrderId },
      data: {
        time_from: time_from ?? existingSlot.time_from,
        time_to: time_to ?? existingSlot.time_to,
        max_orders:
          max_orders !== undefined
            ? (max_orders ?? null)
            : existingSlot.max_orders,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.slot_updated"),
      data: { updatedSlot },
    });
  };

  // ============================ listSupplierSlotMaxOrder ============================
  listSupplierSlotMaxOrder = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierStoreAddressId } = res.locals
      .validatedData as listSupplierSlotMaxOrderDTO;

    // step: check store address existence
    const storeAddress = await prisma.supplierStoreAddress.findFirst({
      where: { id: supplierStoreAddressId },
    });
    if (!storeAddress) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.store_address_not_found"),
      );
    }

    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter() //{}{allowKeys:[]}
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword([]) // ?keyword=xxx&items=reason_ar,reason_en
      .fields().data; // ?fields=id,reason_ar,reason_en

    const [totalSupplierSlotMaxOrder, supplierSlotMaxOrders] =
      await prisma.$transaction([
        prisma.supplierSlotMaxOrder.count({
          ...(queryOptions.where ? { where: queryOptions.where } : {}),
        }),
        prisma.supplierSlotMaxOrder.findMany(queryOptions as any),
      ]);

    return responseHandler({
      res,
      message: res.__("messages.slots_retrieved"),
      data: {
        totalSupplierSlotMaxOrder,
        totalPages: Math.ceil(
          totalSupplierSlotMaxOrder / (queryOptions.take ?? 10),
        ),
        supplierSlotMaxOrders,
      },
    });
  };

  // ============================ deleteSupplierSlotMaxOrder ============================
  deleteSupplierSlotMaxOrder = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierSlotMaxOrderId } = res.locals
      .validatedData as deleteSupplierSlotMaxOrderDTO;

    // step: check slot existence
    const supplierSlotMaxOrder = await prisma.supplierSlotMaxOrder.findFirst({
      where: { id: supplierSlotMaxOrderId },
    });
    if (!supplierSlotMaxOrder) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.slot_not_found"),
      );
    }

    // step: delete slot
    await prisma.supplierSlotMaxOrder.delete({
      where: { id: supplierSlotMaxOrderId },
    });

    return responseHandler({
      res,
      message: res.__("messages.slot_deleted"),
    });
  };

  // ============================ supplierSlotMaxOrderStatus ============================
  supplierSlotMaxOrderStatus = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierStoreAddressId } = res.locals
      .validatedData as supplierSlotMaxOrderStatusDTO;

    // step: check store address existence
    const storeAddress = await prisma.supplierStoreAddress.findFirst({
      where: { id: supplierStoreAddressId },
    });
    if (!storeAddress) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.store_address_not_found"),
      );
    }

    // step: parse working hours
    const workingHours = storeAddress.working_hours as any;
    if (!workingHours || !workingHours.days) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.working_hours_not_configured"),
      );
    }

    // step: fetch all slot configs for this store address
    const slotConfigs = await prisma.supplierSlotMaxOrder.findMany({
      where: { store_address_id: supplierStoreAddressId },
      orderBy: [{ day_of_week: "asc" }, { time_from: "asc" }],
    });

    // step: compute date range for the next 7 days (today + 6)
    const now = new Date();
    const todayStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const weekEnd = new Date(todayStart);
    weekEnd.setDate(weekEnd.getDate() + 7);

    // step: fetch active orders within the 7-day window
    const activeOrders = await prisma.order.findMany({
      where: {
        supplier_id: storeAddress.supplier_id,
        status: OrderStatus.SCHEDULED,
        order_schedule_at: {
          gte: todayStart,
          lt: weekEnd,
        },
      },
      select: {
        id: true,
        created_at: true,
        order_schedule_at: true,
        is_order_scheduled: true,
      },
    });

    // step: helpers
    const storeTimezone = workingHours.timezone || "UTC";

    const toHHmm = (date: Date): string => {
      return new Intl.DateTimeFormat("en-GB", {
        timeZone: storeTimezone,
        hour: "2-digit",
        minute: "2-digit",
        hourCycle: "h23",
      }).format(date);
    };

    const toDateStr = (date: Date): string => {
      return date.toLocaleDateString("en-CA", { timeZone: storeTimezone });
    };

    const dayNames = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];

    const todayStr = toDateStr(now);

    // step: derive unique dates from scheduled orders
    const orderDates = new Set<string>();
    for (const order of activeOrders) {
      const effectiveDate =
        order.is_order_scheduled && order.order_schedule_at
          ? new Date(order.order_schedule_at)
          : new Date(order.created_at);
      orderDates.add(toDateStr(effectiveDate));
    }

    // step: build status only for dates that have scheduled orders
    const days = [];
    for (const dateStr of Array.from(orderDates).sort()) {
      const currentDate = new Date(dateStr + "T00:00:00");
      const dayOfWeek = currentDate.getDay();
      const isToday = dateStr === todayStr;

      const dayData = workingHours.days[String(dayOfWeek)];
      const isClosed = !dayData || dayData.is_closed;
      const workingSlots = isClosed ? [] : dayData.slots || [];

      // get slot configs for this day of week
      const daySlotConfigs = slotConfigs.filter(
        (s) => s.day_of_week === dayOfWeek,
      );

      // count orders for each configured slot on this specific date
      const slotsWithStatus = daySlotConfigs.map((slotConfig) => {
        const currentOrders = activeOrders.filter((order) => {
          const effectiveDate =
            order.is_order_scheduled && order.order_schedule_at
              ? new Date(order.order_schedule_at)
              : new Date(order.created_at);

          if (toDateStr(effectiveDate) !== dateStr) return false;

          const orderTime = toHHmm(effectiveDate);
          return (
            orderTime >= slotConfig.time_from && orderTime < slotConfig.time_to
          );
        });

        return {
          id: slotConfig.id,
          time_from: slotConfig.time_from,
          time_to: slotConfig.time_to,
          max_orders: slotConfig.max_orders,
          current_orders: currentOrders.length,
          is_full:
            slotConfig.max_orders !== null
              ? currentOrders.length >= slotConfig.max_orders
              : false,
        };
      });

      // count orders that don't fall into any configured slot
      const unslottedOrders = activeOrders.filter((order) => {
        const effectiveDate =
          order.is_order_scheduled && order.order_schedule_at
            ? new Date(order.order_schedule_at)
            : new Date(order.created_at);

        if (toDateStr(effectiveDate) !== dateStr) return false;

        const orderTime = toHHmm(effectiveDate);
        return !daySlotConfigs.some(
          (s) => orderTime >= s.time_from && orderTime < s.time_to,
        );
      });

      const totalOrdersForDay = activeOrders.filter((order) => {
        const effectiveDate =
          order.is_order_scheduled && order.order_schedule_at
            ? new Date(order.order_schedule_at)
            : new Date(order.created_at);
        return toDateStr(effectiveDate) === dateStr;
      });

      days.push({
        date: dateStr,
        day_of_week: dayOfWeek,
        day_name: dayNames[dayOfWeek],
        is_today: isToday,
        is_closed: isClosed,
        working_hours: workingSlots,
        total_orders: totalOrdersForDay.length,
        unslotted_orders: unslottedOrders.length,
        slots: slotsWithStatus,
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.slot_status_retrieved"),
      data: {
        store_address_id: supplierStoreAddressId,
        workingHours,
        timezone: workingHours.timezone || null,
        days,
      },
    });
  };
}
