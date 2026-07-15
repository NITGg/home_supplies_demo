import { NextFunction, Request, Response } from "express";
import {
  appleLoginDTO,
  appleRegisterDTO,
  changePasswordDTO,
  forgetPasswordDTO,
  googleLoginDTO,
  googleRegisterDTO,
  linkAppleDTO,
  linkGoogleDTO,
  loginDTO,
  referralCodeDTO,
  registerDTO,
  resendPhoneOTPDTO,
  updatePasswordDTO,
  verifyPhonDTO,
} from "./auth.dto";
import * as jwt from "jsonwebtoken";
import jwksClient from "jwks-rsa";
import { OAuth2Client } from "google-auth-library";
import { template } from "../../utils/sendEmail/generateHTML";
import { createJwt } from "../../utils/jwt";
import { createOtp } from "../../utils/createOtp";
import { compare, hash } from "../../utils/bcrypt";
import { sendEmail } from "../../utils/sendEmail/send.email";
import { decodeToken, TokenTypesEnum } from "../../utils/decodeToken";
import { IAuthServcie } from "../../types/global.interfaces";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { GenderEnum } from "../../types/global.types";
import { uploadSingleFile } from "../../utils/cloudinary/cloudinary.service";
import logger from "../../config/logger.config";
import { env } from "../../config/env";

export class AuthService implements IAuthServcie {
  constructor() {}
  private readonly SUPPLIER_ROLE_NAME = "Supplier";
  private readonly DEFAULT_WORKING_HOURS = {
    timezone: "Africa/Cairo",
    days: {
      "0": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
      "1": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
      "2": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
      "3": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
      "4": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
      "5": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
      "6": { is_closed: false, slots: [{ open: "00:00", close: "23:59" }] },
    },
  };

  private getWorkingHours(working_hours: any): any {
    let parsed = working_hours;
    if (typeof working_hours === "string" && working_hours.trim() !== "") {
      try {
        parsed = JSON.parse(working_hours);
      } catch (err) {
        parsed = null;
      }
    }
    if (
      parsed &&
      typeof parsed === "object" &&
      Object.keys(parsed).length > 0
    ) {
      return parsed;
    }
    return this.DEFAULT_WORKING_HOURS;
  }

  // ============================ register ============================
  register = async (req: Request, res: Response, next: NextFunction) => {
    const {
      full_name,
      phone,
      password,
      gender,
      national_id_number,
      language,
      type_id,
      synonyms,
      tax_card,
      commercial_register,
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
    }: registerDTO = res.locals.validatedData;

    // step: check user existence by phone
    const isUserExist = await prisma.user.findUnique({ where: { phone } });
    if (isUserExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.user_already_exists"),
      );
    }

    // step: check national_id_number existence
    const isNationalIdExist = await prisma.supplier.findFirst({
      where: { national_id_number },
    });
    if (isNationalIdExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.national_id_already_exists"),
      );
    }

    // step: get uploaded files
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const personal_photoFile = files?.personal_photo?.[0];
    const national_id_photo_frontFile = files?.national_id_photo_front?.[0];
    const national_id_photo_backFile = files?.national_id_photo_back?.[0];
    const supplier_criminal_recordFile = files?.supplier_criminal_record?.[0];

    // step: validate required photos
    if (!national_id_photo_frontFile || !national_id_photo_backFile) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.photos_required"),
      );
    }

    // step: upload images and get URLs
    let personal_photo = null;
    let national_id_photo_front = null;
    let national_id_photo_back = null;
    let supplier_criminal_record = null;

    try {
      if (personal_photoFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: personal_photoFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        personal_photo = secure_url;
      }
      if (national_id_photo_frontFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: national_id_photo_frontFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        national_id_photo_front = secure_url;
      }
      if (national_id_photo_backFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: national_id_photo_backFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        national_id_photo_back = secure_url;
      }
      if (supplier_criminal_recordFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: supplier_criminal_recordFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        supplier_criminal_record = secure_url;
      }
    } catch (err) {
      throw new AppError(500, res.__("errors.photo_upload_failed"));
    }

    // step: generate OTP
    const otpCode = createOtp();

    // step: find Supplier role
    let supplierRole = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.supplier_role_not_found"),
      );
    }

    // step: find first badge
    const firstBadge = await prisma.userBadge.findFirst({
      where: { role_id: supplierRole.id },
    });
    if (!firstBadge) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.badge_not_found"),
      );
    }

    //TODO: step: find supplier type
    // const supplierType = await prisma.supplierType.findFirst({
    //   where: { id: Number(type_id) },
    // });
    // if (!supplierType) {
    //   throw new AppError(
    //     HttpStatusCode.BAD_REQUEST,
    //     res.__("errors.supplier_type_not_found"),
    //   );
    // }

    // step: fetch application settings for points reset days
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // create related records in transaction
    const result = await prisma.$transaction(async (tx) => {
      // step: create User
      const newUser = await tx.user.create({
        data: {
          full_name,
          phone,
          password: await hash(password),
          gender: gender ?? GenderEnum.MALE,
          personal_photo,
          badge_id: firstBadge.id,
          role_id: Number(supplierRole.id),
          lang: language ?? "AR",
          login_type: "LOCAL",
        },
      });

      // step: create Supplier
      const newSupplier = await tx.supplier.create({
        data: {
          user_id: newUser.id,
          type_id: type_id ? Number(type_id) : null,
          national_id_photo_front,
          national_id_photo_back,
          national_id_number,
          supplier_criminal_record: supplier_criminal_record ?? "",
          synonyms: synonyms ?? "",
          tax_card: tax_card ?? "",
          commercial_register: commercial_register ?? "",
          is_approved: false,
        },
      });

      // step: create SupplierStoreAddress
      await tx.supplierStoreAddress.create({
        data: {
          supplier_id: newSupplier.id,
          area_id: area_id ?? null,
          address_line_1: address_line_1 ?? null,
          address_line_2: address_line_2 ?? null,
          city: city ?? null,
          state: state ?? null,
          country: country ?? null,
          google_map_link: google_map_link ?? null,
          latitude: latitude || null,
          longitude: longitude || null,
          contact_name: contact_name ?? null,
          contact_phone: contact_phone ?? null,
          working_hours: this.getWorkingHours(working_hours),
        },
      });

      // step: create SupplierStat
      await tx.supplierStat.create({
        data: { supplier_id: newSupplier.id },
      });

      // step: create NotificationSetting
      await tx.notificationSetting.create({
        data: { user_id: newUser.id },
      });

      // step: create Wallet for supplier
      await tx.wallet.create({
        data: {
          user_id: newUser.id,
          owner_type: "SUPPLIER",
          balance: 0,
          status: "ACTIVE",
        },
      });

      // step: create UserVerify with OTP
      await tx.userVerify.create({
        data: {
          user_id: newUser.id,
          code: otpCode,
          phone,
        },
      });

      return { user: newUser, supplier: newSupplier };
    });

    // step: get user role
    const userRole = await prisma.userRole.findUnique({
      where: { id: result.user.role_id },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    // step: create tokens
    const accessToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.ACCESS_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );
    const refreshToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_refresh_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );

    logger.info(
      { userId: result.user.id, phone: result.user.phone },
      "[Auth] New supplier registered",
    );

    return responseHandler({
      res,
      status: 201,
      message: res.__("messages.register_success"),
      data: {
        accessToken,
        refreshToken,
        user: {
          id: result.user.id,
          full_name: result.user.full_name,
          email: result.user.email,
          phone: result.user.phone,
          role: userRole.name,
        },
      },
    });
  };

  // ============================ googleRegister ============================
  googleRegister = async (req: Request, res: Response, next: NextFunction) => {
    const {
      id_token,
      phone,
      gender,
      national_id_number,
      language,
      type_id,
      synonyms,
      tax_card,
      commercial_register,
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
    }: googleRegisterDTO = res.locals.validatedData;

    // step: verify Google token
    const client = new OAuth2Client(env.GOOGLE_WEB_CLIENT_ID);
    let payload;
    try {
      const ticket = await client.verifyIdToken({
        idToken: id_token,
        audience: [
          env.GOOGLE_WEB_CLIENT_ID as string,
          env.GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID as string,
          env.GOOGLE_FLUTTER_COURIER_CLIENT_ID as string,
          env.GOOGLE_WEB_TESTING_CLIENT_ID as string,
        ].filter(Boolean),
      });
      payload = ticket.getPayload();
    } catch (error) {
      logger.error({ error }, "[Auth] Google token verification failed");
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_token_invalid"),
      );
    }
    if (!payload || !payload.email) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_token_invalid"),
      );
    }
    const { email, name, sub: googleId } = payload;

    // step: check email verification
    if (!payload.email_verified) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_email_not_verified"),
      );
    }

    // TODO: all next code like in appleRegister

    // step: check user existence by phone
    const isPhoneExist = await prisma.user.findUnique({ where: { phone } });
    if (isPhoneExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.user_already_exists"),
      );
    }

    // step: check user existence by email
    const isEmailExist = await prisma.user.findUnique({ where: { email } });
    if (isEmailExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.user_already_exists"),
      );
    }

    // step: get uploaded files
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const personal_photoFile = files?.personal_photo?.[0];
    const national_id_photo_frontFile = files?.national_id_photo_front?.[0];
    const national_id_photo_backFile = files?.national_id_photo_back?.[0];
    const supplier_criminal_recordFile = files?.supplier_criminal_record?.[0];

    // step: validate required photos
    if (!national_id_photo_frontFile || !national_id_photo_backFile) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.photos_required"),
      );
    }

    // step: upload images and get URLs
    let personal_photo = null;
    let national_id_photo_front = null;
    let national_id_photo_back = null;
    let supplier_criminal_record = null;

    try {
      if (personal_photoFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: personal_photoFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        personal_photo = secure_url;
      }
      if (national_id_photo_frontFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: national_id_photo_frontFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        national_id_photo_front = secure_url;
      }
      if (national_id_photo_backFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: national_id_photo_backFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        national_id_photo_back = secure_url;
      }
      if (supplier_criminal_recordFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: supplier_criminal_recordFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        supplier_criminal_record = secure_url;
      }
    } catch (err) {
      throw new AppError(500, res.__("errors.photo_upload_failed"));
    }

    // step: generate OTP
    const otpCode = createOtp();

    // step: find Supplier role
    let supplierRole = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.supplier_role_not_found"),
      );
    }

    // step: find first badge
    const firstBadge = await prisma.userBadge.findFirst({
      where: { role_id: supplierRole.id },
    });
    if (!firstBadge) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.badge_not_found"),
      );
    }

    //TODO: step: find supplier type
    // const supplierType = await prisma.supplierType.findFirst({
    //   where: { id: type_id },
    // });
    // if (!supplierType) {
    //   throw new AppError(
    //     HttpStatusCode.BAD_REQUEST,
    //     res.__("errors.supplier_type_not_found"),
    //   );
    // }

    // step: fetch application settings for points reset days
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create related records in transaction
    const result = await prisma.$transaction(async (tx) => {
      // step: create User
      const newUser = await tx.user.create({
        data: {
          full_name: name ?? "",
          phone,
          gender: gender ?? GenderEnum.MALE,
          personal_photo,
          badge_id: firstBadge.id,
          role_id: supplierRole.id,
          lang: language ?? "AR",
          login_type: "GOOGLE",
        },
      });

      // step: create Supplier
      const newSupplier = await tx.supplier.create({
        data: {
          user_id: newUser.id,
          type_id: type_id ? Number(type_id) : null,
          national_id_photo_front,
          national_id_photo_back,
          national_id_number,
          supplier_criminal_record: supplier_criminal_record ?? "",
          synonyms: synonyms ?? "",
          tax_card: tax_card ?? "",
          commercial_register: commercial_register ?? "",
          is_approved: false,
        },
      });

      // step: create SupplierStoreAddress
      await tx.supplierStoreAddress.create({
        data: {
          supplier_id: newSupplier.id,
          area_id: area_id ?? null,
          address_line_1: address_line_1 ?? null,
          address_line_2: address_line_2 ?? null,
          city: city ?? null,
          state: state ?? null,
          country: country ?? null,
          google_map_link: google_map_link ?? null,
          latitude: latitude || null,
          longitude: longitude || null,
          contact_name: contact_name ?? null,
          contact_phone: contact_phone ?? null,
          working_hours: this.getWorkingHours(working_hours),
        },
      });

      // step: create SupplierStat
      await tx.supplierStat.create({
        data: { supplier_id: newSupplier.id },
      });

      // step: create NotificationSetting
      await tx.notificationSetting.create({
        data: { user_id: newUser.id },
      });

      // step: create Wallet for supplier
      await tx.wallet.create({
        data: {
          user_id: newUser.id,
          owner_type: "SUPPLIER",
          balance: 0,
          status: "ACTIVE",
        },
      });

      // step: create UserVerify with OTP
      await tx.userVerify.create({
        data: {
          user_id: newUser.id,
          code: otpCode,
          phone,
        },
      });

      return { user: newUser, supplier: newSupplier };
    });

    // step: get user role
    const userRole = await prisma.userRole.findUnique({
      where: { id: result.user.role_id },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    // step: create tokens
    const accessToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.ACCESS_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );
    const refreshToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_refresh_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );

    logger.info(
      { userId: result.user.id, phone: result.user.phone },
      "[Auth] New supplier registered",
    );

    return responseHandler({
      res,
      status: 201,
      message: res.__("messages.register_success"),
      data: {
        accessToken,
        refreshToken,
        user: {
          id: result.user.id,
          full_name: result.user.full_name,
          email: result.user.email,
          phone: result.user.phone,
          role: userRole.name,
        },
      },
    });
  };

  // ============================ appleRegister ============================
  appleRegister = async (req: Request, res: Response, next: NextFunction) => {
    const {
      id_token,
      phone,
      gender,
      national_id_number,
      language,
      type_id,
      synonyms,
      tax_card,
      commercial_register,
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
    }: appleRegisterDTO = res.locals.validatedData;

    // step: verify Apple token and extract payload
    let applePayload: any;
    try {
      const client = jwksClient({
        jwksUri: "https://appleid.apple.com/auth/keys",
        cache: true,
        rateLimit: true,
      });

      const decodedHeader = jwt.decode(id_token, { complete: true }) as {
        header: { kid: string; alg: string };
        payload: any;
      };

      if (!decodedHeader || !decodedHeader.header) {
        throw new AppError(
          HttpStatusCode.UNAUTHORIZED,
          res.__("errors.invalid_token_structure"),
        );
      }

      const key = await client.getSigningKey(decodedHeader.header.kid);
      const signingKey = key.getPublicKey();

      applePayload = jwt.verify(id_token, signingKey, {
        algorithms: ["RS256"],
        issuer: "https://appleid.apple.com",
      });
    } catch (error) {
      logger.error({ error }, "[Auth] Apple token verification failed");
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_token_invalid"),
      );
    }

    if (!applePayload || !applePayload.email) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_token_invalid"),
      );
    }

    const { email, sub: appleUserId } = applePayload;

    // step: check email verification
    if (!applePayload.email_verified) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_email_not_verified"),
      );
    }

    // TODO: all next code like in googleRegister

    // step: check user existence by phone
    const isPhoneExist = await prisma.user.findUnique({ where: { phone } });
    if (isPhoneExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.user_already_exists"),
      );
    }

    // step: check user existence by email
    const isEmailExist = await prisma.user.findUnique({ where: { email } });
    if (isEmailExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.user_already_exists"),
      );
    }

    // step: get uploaded files
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const personal_photoFile = files?.personal_photo?.[0];
    const national_id_photo_frontFile = files?.national_id_photo_front?.[0];
    const national_id_photo_backFile = files?.national_id_photo_back?.[0];
    const supplier_criminal_recordFile = files?.supplier_criminal_record?.[0];

    // step: validate required photos
    if (!national_id_photo_frontFile || !national_id_photo_backFile) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.photos_required"),
      );
    }

    // step: upload images and get URLs
    let personal_photo = null;
    let national_id_photo_front = null;
    let national_id_photo_back = null;
    let supplier_criminal_record = null;

    try {
      if (personal_photoFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: personal_photoFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        personal_photo = secure_url;
      }
      if (national_id_photo_frontFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: national_id_photo_frontFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        national_id_photo_front = secure_url;
      }
      if (national_id_photo_backFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: national_id_photo_backFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        national_id_photo_back = secure_url;
      }
      if (supplier_criminal_recordFile) {
        const { secure_url } = await uploadSingleFile({
          fileLocation: supplier_criminal_recordFile.path, // .path or .buffer
          storagePathOnCloudinary: "users/Supplier",
        });
        supplier_criminal_record = secure_url;
      }
    } catch (err) {
      throw new AppError(500, res.__("errors.photo_upload_failed"));
    }

    // step: generate OTP
    const otpCode = createOtp();

    // step: find Supplier role
    let supplierRole = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!supplierRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.supplier_role_not_found"),
      );
    }

    // step: find first badge
    const firstBadge = await prisma.userBadge.findFirst({
      where: { role_id: supplierRole.id },
    });
    if (!firstBadge) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.badge_not_found"),
      );
    }

    //TODO: step: find supplier type
    // const supplierType = await prisma.supplierType.findFirst({
    //   where: { id: type_id },
    // });
    // if (!supplierType) {
    //   throw new AppError(
    //     HttpStatusCode.BAD_REQUEST,
    //     res.__("errors.supplier_type_not_found"),
    //   );
    // }

    // step: fetch application settings for points reset days
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create related records in transaction
    const result = await prisma.$transaction(async (tx) => {
      // step: create User
      const newUser = await tx.user.create({
        data: {
          full_name: "",
          phone,
          gender: gender ?? GenderEnum.MALE,
          personal_photo,
          badge_id: firstBadge.id,
          role_id: Number(supplierRole.id),
          lang: language ?? "AR",
          login_type: "APPLE",
        },
      });

      // step: create Supplier
      const newSupplier = await tx.supplier.create({
        data: {
          user_id: newUser.id,
          type_id: type_id ? Number(type_id) : null,
          national_id_photo_front,
          national_id_photo_back,
          national_id_number,
          supplier_criminal_record: supplier_criminal_record ?? "",
          synonyms: synonyms ?? "",
          tax_card: tax_card ?? "",
          commercial_register: commercial_register ?? "",
          is_approved: false,
        },
      });

      // step: create SupplierStoreAddress
      await tx.supplierStoreAddress.create({
        data: {
          supplier_id: newSupplier.id,
          area_id: area_id ?? null,
          address_line_1: address_line_1 ?? null,
          address_line_2: address_line_2 ?? null,
          city: city ?? null,
          state: state ?? null,
          country: country ?? null,
          google_map_link: google_map_link ?? null,
          latitude: latitude || null,
          longitude: longitude || null,
          contact_name: contact_name ?? null,
          contact_phone: contact_phone ?? null,
          working_hours: this.getWorkingHours(working_hours),
        },
      });

      // step: create SupplierStat
      await tx.supplierStat.create({
        data: { supplier_id: newSupplier.id },
      });

      // step: create NotificationSetting
      await tx.notificationSetting.create({
        data: { user_id: newUser.id },
      });

      // step: create Wallet for supplier
      await tx.wallet.create({
        data: {
          user_id: newUser.id,
          owner_type: "SUPPLIER",
          balance: 0,
          status: "ACTIVE",
        },
      });

      // step: create UserVerify with OTP
      await tx.userVerify.create({
        data: {
          user_id: newUser.id,
          code: otpCode,
          phone,
        },
      });

      return { user: newUser, supplier: newSupplier };
    });

    // step: get user role
    const userRole = await prisma.userRole.findUnique({
      where: { id: result.user.role_id },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    // step: create tokens
    const accessToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.ACCESS_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );
    const refreshToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_refresh_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );

    logger.info(
      { userId: result.user.id, phone: result.user.phone },
      "[Auth] New supplier registered",
    );

    return responseHandler({
      res,
      status: 201,
      message: res.__("messages.register_success"),
      data: {
        accessToken,
        refreshToken,
        user: {
          id: result.user.id,
          full_name: result.user.full_name,
          email: result.user.email,
          phone: result.user.phone,
          role: userRole.name,
        },
      },
    });
  };

  // ============================ verifyPhone ============================
  verifyPhone = async (req: Request, res: Response, next: NextFunction) => {
    const { phone, user_otp }: verifyPhonDTO = req.body;

    // step: check phone existence
    const user = await prisma.user.findUnique({
      where: { phone },
      include: { supplier: true },
    });
    if (!user || !user.supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: find UserVerify
    const userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id },
    });
    if (!userVerify) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.verify_record_not_found"),
      );
    }

    // step: check user_otp
    if (!userVerify.code || userVerify.code !== user_otp) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.otp_invalid"),
      );
    }

    // step: check if otp expired (5 minutes)
    const otpTime = userVerify.updated_at ?? userVerify.created_at;
    if (otpTime.getTime() + 5 * 60 * 1000 < Date.now()) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.otp_expired"),
      );
    }

    // step: update is_phone_verified to true on User
    await prisma.user.update({
      where: { id: user.id },
      data: { is_phone_verified: true },
    });

    // step: delete UserVerify record after successful verification
    await prisma.userVerify.delete({
      where: { id: userVerify.id },
    });

    logger.info(
      { userId: user.id, phone: user.phone },
      "[Auth] Phone OTP verified",
    );

    return responseHandler({
      res,
      message: res.__("messages.phone_verified"),
    });
  };

  // ============================ resendPhoneOTP ============================
  resendPhoneOTP = async (req: Request, res: Response, next: NextFunction) => {
    const { phone }: resendPhoneOTPDTO = req.body;

    // step: check phone existence
    const user = await prisma.user.findUnique({
      where: { phone },
      include: { supplier: true },
    });
    if (!user || !user.supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: check if phone already verified
    if (user.is_phone_verified) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.phone_already_verified"),
      );
    }

    // step: find UserVerify
    const userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id },
    });
    if (!userVerify) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.verify_record_not_found"),
      );
    }

    // step: check cooldown (1 minute between resends)
    const lastOtpTime = userVerify.updated_at ?? userVerify.created_at;
    if (lastOtpTime.getTime() + 1 * 60 * 1000 > Date.now()) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.otp_cooldown"),
      );
    }

    // step: generate OTP
    const otpCode = createOtp();

    // step: update OTP in UserVerify
    await prisma.userVerify.update({
      where: { id: userVerify.id },
      data: { code: otpCode },
    });

    return responseHandler({
      res,
      message: res.__("messages.otp_sent"),
    });
  };

  // ============================ login ============================
  login = async (req: Request, res: Response, next: NextFunction) => {
    const { phone, password }: loginDTO = req.body;

    // step: check credentials 1 - check if user exists at all
    let user = await prisma.user.findUnique({
      where: { phone },
      include: { supplier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: get user role
    const userRole = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    // step: check credentials 2 - check if user has the correct role
    if (user.role_id !== userRole.id) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check credentials 3 - validate password
    if (!(await compare(password, user.password as string))) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: update last_login_at
    await prisma.user.update({
      where: { id: user.id },
      data: { last_login_at: new Date() },
    });

    // step: check login type // commnt for allow all login types
    // if (user.login_type !== "LOCAL") {
    //   throw new AppError(
    //     HttpStatusCode.UNAUTHORIZED,
    //     res.__("errors.invalid_login_type"),
    //   );
    // }

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create token
    const accessToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.ACCESS_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );
    const refreshToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_refresh_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );

    logger.info(
      { userId: user.id, phone: user.phone },
      "[Auth] Login successful",
    );

    return responseHandler({
      res,
      message: res.__("messages.login_successful"),
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          phone: user.phone,
          role: userRole.name,
          isPhoneVerified: user.is_phone_verified,
        },
      },
    });
  };

  // ============================ refreshToken ============================
  refreshToken = async (req: Request, res: Response, next: NextFunction) => {
    const authorization = req.headers.authorization;
    // step: check authorization
    if (!authorization) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.authorization_required"),
      );
    }
    // step: decode authorization
    const { user, payload } = await decodeToken({
      authorization,
      tokenType: TokenTypesEnum.refresh,
    });

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create accessToken
    const newPayload = {
      userId: payload.userId,
      userPhone: payload.userPhone,
    };
    const accessToken = createJwt(newPayload, env.ACCESS_SEGNATURE as string, {
      expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
      jwtid: createOtp(),
      issuer: "tawreedat-supplier",
    });
    return responseHandler({ res, data: { accessToken } });
  };

  // ============================ linkGoogle ============================
  linkGoogle = async (req: Request, res: Response, next: NextFunction) => {
    const { id_token }: linkGoogleDTO = req.body;
    const user = res.locals.user;

    // step: verify Google token
    const client = new OAuth2Client(env.GOOGLE_WEB_CLIENT_ID);
    let payload;
    try {
      const ticket = await client.verifyIdToken({
        idToken: id_token,
        audience: [
          env.GOOGLE_WEB_CLIENT_ID as string,
          env.GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID as string,
          env.GOOGLE_FLUTTER_COURIER_CLIENT_ID as string,
          env.GOOGLE_WEB_TESTING_CLIENT_ID as string,
        ].filter(Boolean),
      });
      payload = ticket.getPayload();
    } catch (error) {
      logger.error({ error }, "[Auth] Google token verification failed");
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_token_invalid"),
      );
    }
    if (!payload || !payload.email) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_token_invalid"),
      );
    }
    const { email, sub: googleId } = payload;

    // step: check if google_id is already linked to another user
    const existingGoogleUser = await prisma.user.findFirst({
      where: { google_id: googleId, id: { not: user.id } },
    });
    if (existingGoogleUser) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.google_already_linked"),
      );
    }

    // step: update current user with google_id and email
    await prisma.user.update({
      where: { id: user.id },
      data: {
        google_id: googleId,
        email: user.email ?? email,
        login_type: "GOOGLE",
      },
    });

    logger.info({ userId: user.id }, "[Auth] Google account linked");

    return responseHandler({
      res,
      message: res.__("messages.google_linked_success"),
    });
  };

  // ============================ linkApple ============================
  linkApple = async (req: Request, res: Response, next: NextFunction) => {
    const { id_token }: linkAppleDTO = req.body;
    const user = res.locals.user;

    // step: verify Apple token and extract payload
    let payload: any;
    try {
      const client = jwksClient({
        jwksUri: "https://appleid.apple.com/auth/keys",
        cache: true,
        rateLimit: true,
      });

      const decodedHeader = jwt.decode(id_token, { complete: true }) as {
        header: { kid: string; alg: string };
        payload: any;
      };

      if (!decodedHeader || !decodedHeader.header) {
        throw new AppError(
          HttpStatusCode.UNAUTHORIZED,
          res.__("errors.invalid_token_structure"),
        );
      }

      const key = await client.getSigningKey(decodedHeader.header.kid);
      const signingKey = key.getPublicKey();

      payload = jwt.verify(id_token, signingKey, {
        algorithms: ["RS256"],
        issuer: "https://appleid.apple.com",
      }) as {
        sub: string;
        email?: string;
        email_verified?: string | boolean;
        aud: string;
        exp: number;
        iat: number;
      };
    } catch (error) {
      logger.error({ error }, "[Auth] Apple token verification failed");
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_token_invalid"),
      );
    }

    const email = payload.email;
    const appleUserId = payload.sub;

    // step: check if apple_id is already linked to another user
    const existingAppleUser = await prisma.user.findFirst({
      where: { apple_id: appleUserId, id: { not: user.id } },
    });
    if (existingAppleUser) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.apple_already_linked"),
      );
    }

    // step: update current user with apple_id and email
    await prisma.user.update({
      where: { id: user.id },
      data: {
        apple_id: appleUserId,
        email: user.email ?? email,
        login_type: "APPLE",
      },
    });

    logger.info({ userId: user.id }, "[Auth] Apple account linked");

    return responseHandler({
      res,
      message: res.__("messages.apple_linked_success"),
    });
  };

  // ============================ googleLogin ============================
  googleLogin = async (req: Request, res: Response, next: NextFunction) => {
    const { id_token }: googleLoginDTO = req.body;

    // step: verify Google token
    const client = new OAuth2Client(env.GOOGLE_WEB_CLIENT_ID);
    let payload;
    try {
      const ticket = await client.verifyIdToken({
        idToken: id_token,
        audience: [
          env.GOOGLE_WEB_CLIENT_ID as string,
          env.GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID as string,
          env.GOOGLE_FLUTTER_COURIER_CLIENT_ID as string,
          env.GOOGLE_WEB_TESTING_CLIENT_ID as string,
        ].filter(Boolean),
      });
      payload = ticket.getPayload();
    } catch (error) {
      logger.error({ error }, "[Auth] Google token verification failed");
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_token_invalid"),
      );
    }
    if (!payload || !payload.email) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.google_token_invalid"),
      );
    }
    const { email } = payload;

    // step: check if user exists by email (without role filter)
    const user = await prisma.user.findUnique({
      where: { email },
      include: { supplier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check if user has the correct role
    const SUPPLIER_ROLE = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!SUPPLIER_ROLE) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.supplier_role_not_found"),
      );
    }
    if (user.role_id !== SUPPLIER_ROLE.id) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check login type
    if (user.login_type !== "GOOGLE") {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_login_type"),
      );
    }

    // step: update last_login_at
    await prisma.user.update({
      where: { id: user.id },
      data: { last_login_at: new Date() },
    });

    // step: get user role
    const userRole = await prisma.userRole.findUnique({
      where: { id: user.role_id },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create tokens
    const accessToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.ACCESS_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );
    const refreshToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_refresh_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );

    logger.info(
      { userId: user.id, email: user.email },
      "[Auth] Google login successful",
    );

    return responseHandler({
      res,
      message: res.__("messages.google_login_success"),
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          phone: user.phone,
          role: userRole.name,
          isPhoneVerified: user.is_phone_verified,
        },
      },
    });
  };

  // ============================ appleLogin ============================
  appleLogin = async (req: Request, res: Response, next: NextFunction) => {
    const { id_token }: appleLoginDTO = req.body;

    // step: verify Apple token and extract payload
    let payload: any;
    try {
      const client = jwksClient({
        jwksUri: "https://appleid.apple.com/auth/keys",
        cache: true,
        rateLimit: true,
      });

      const decodedHeader = jwt.decode(id_token, { complete: true }) as {
        header: { kid: string; alg: string };
        payload: any;
      };

      if (!decodedHeader || !decodedHeader.header) {
        throw new AppError(
          HttpStatusCode.UNAUTHORIZED,
          res.__("errors.invalid_token_structure"),
        );
      }

      const key = await client.getSigningKey(decodedHeader.header.kid);
      const signingKey = key.getPublicKey();

      payload = jwt.verify(id_token, signingKey, {
        algorithms: ["RS256"],
        issuer: "https://appleid.apple.com",
      }) as {
        sub: string;
        email?: string;
        email_verified?: string | boolean;
        aud: string;
        exp: number;
        iat: number;
      };
    } catch (error) {
      logger.error({ error }, "[Auth] Apple token verification failed");
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_token_invalid"),
      );
    }

    const email = payload.email;
    if (!email) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_token_invalid"),
      );
    }

    // step: check if user exists by email (without role filter)
    const user = await prisma.user.findUnique({
      where: { email },
      include: { supplier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check if user has the correct role
    const SUPPLIER_ROLE = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!SUPPLIER_ROLE) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.supplier_role_not_found"),
      );
    }
    if (user.role_id !== SUPPLIER_ROLE.id) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check login type
    if (user.login_type !== "APPLE") {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_login_type"),
      );
    }

    // step: update last_login_at
    await prisma.user.update({
      where: { id: user.id },
      data: { last_login_at: new Date() },
    });

    // step: get user role
    const userRole = await prisma.userRole.findUnique({
      where: { id: user.role_id },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create tokens
    const accessToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.ACCESS_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );
    const refreshToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.supplier_refresh_token_expires_in || "1h") as any,
        jwtid: createOtp(),
        issuer: "tawreedat-supplier",
      },
    );

    logger.info(
      { userId: user.id, email: user.email },
      "[Auth] Apple login successful",
    );

    return responseHandler({
      res,
      message: res.__("messages.apple_login_success"),
      data: {
        accessToken,
        refreshToken,
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          phone: user.phone,
          role: userRole.name,
          isPhoneVerified: user.is_phone_verified,
        },
      },
    });
  };

  // ============================ updatePassword ============================
  updatePassword = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { current_password, new_password }: updatePasswordDTO = req.body;

    // step: check password correction
    if (!(await compare(current_password, user.password))) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check new_password not equal current_password
    if (await compare(new_password, user.password)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.password_same_as_old"),
      );
    }

    // step: update password and password_last_updated
    await prisma.user.update({
      where: { id: user.id },
      data: {
        password: await hash(new_password),
        password_last_updated: new Date(Date.now()),
      },
    });

    logger.info({ userId: user.id }, "[Auth] Password updated");

    return responseHandler({
      res,
      message: res.__("messages.password_updated"),
    });
  };

  // ============================ forgetPassword ============================
  forgetPassword = async (req: Request, res: Response, next: NextFunction) => {
    const { phone }: forgetPasswordDTO = req.body;

    // step: check phone existence
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: find or create UserVerify
    let userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id },
    });

    if (!userVerify) {
      // Create new UserVerify if doesn't exist
      const otpCode = createOtp();
      userVerify = await prisma.userVerify.create({
        data: {
          user_id: user.id,
          code: otpCode,
          phone,
        },
      });
      return responseHandler({
        res,
        message: res.__("messages.otp_sent_reset"),
      });
    }

    // step: check if otp not expired yet
    const otpTime = userVerify.updated_at ?? userVerify.created_at;
    if (otpTime.getTime() + 5 * 60 * 1000 > Date.now()) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.otp_not_expired"),
      );
    }

    // step: generate fake OTP
    const otpCode = createOtp();

    // step: update OTP in UserVerify
    await prisma.userVerify.update({
      where: { id: userVerify.id },
      data: { code: otpCode },
    });

    return responseHandler({
      res,
      message: res.__("messages.otp_sent_reset"),
    });
  };

  // ============================ changePassword ============================
  changePassword = async (req: Request, res: Response, next: NextFunction) => {
    const { phone, user_otp, new_password }: changePasswordDTO = req.body;

    // step: check phone existence
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: find UserVerify
    const userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id },
    });
    if (!userVerify) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.verify_record_not_found"),
      );
    }

    // step: check user_otp
    if (!userVerify.code || userVerify.code !== user_otp) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.otp_invalid"),
      );
    }

    // step: check if otp expired
    const otpTime = userVerify.updated_at ?? userVerify.created_at;
    if (otpTime.getTime() + 5 * 60 * 1000 < Date.now()) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.otp_expired"),
      );
    }

    // step: change password
    await prisma.user.update({
      where: { id: user.id },
      data: {
        password: await hash(new_password),
      },
    });

    // step: delete UserVerify record after successful password change
    await prisma.userVerify.delete({
      where: { id: userVerify.id },
    });

    return responseHandler({
      res,
      message: res.__("messages.password_changed"),
    });
  };

  // ============================ logout ============================
  logout = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: change password_last_updated to invalidate tokens
    await prisma.user.update({
      where: { id: user.id },
      data: { password_last_updated: new Date(Date.now()) },
    });

    // step: remove fcm_token
    await prisma.user.update({
      where: { id: user.id },
      data: {
        fcm_token: null,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.logout_success"),
    });
  };
}
