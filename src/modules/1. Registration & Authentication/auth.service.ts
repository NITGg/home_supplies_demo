import { NextFunction, Request, Response } from "express";
import {
  appleLoginDTO,
  appleRegisterDTO,
  changePasswordDTO,
  changePhoneDTO,
  forgetPasswordDTO,
  googleLoginDTO,
  googleRegisterDTO,
  linkAppleDTO,
  linkGoogleDTO,
  loginDTO,
  referralCodeDTO,
  registerDTO,
  resendOtpDTO,
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
import { IAuthServcie } from "../../core/types/global.interfaces";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { GenderEnum } from "../../core/types/global.types";
import { uploadSingleFile } from "../../utils/cloudinary/cloudinary.service";
import logger from "../../config/logger.config";
import { env } from "../../config/env";
import { sendSms } from "../../utils/sms/broadnet";
import { buildVerificationSms } from "../../utils/sms/verificationSms";
import { VerifyType } from "@prisma/client";

export class AuthService implements IAuthServcie {
  constructor() {}
  private readonly COURIER_ROLE_NAME = "courier";

  // ============================ register ============================
  register = async (req: Request, res: Response, next: NextFunction) => {
    const {
      full_name,
      phone,
      password,
      gender,
      vehicle_id,
      vehicle_plate,
      national_id_number,
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
    const isNationalIdExist = await prisma.courier.findFirst({
      where: { national_id_number },
    });
    if (isNationalIdExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.national_id_already_exists"),
      );
    }

    // step: check vehicle_id existence
    const isVehicleExist = await prisma.vehicle.findUnique({
      where: { id: vehicle_id },
    });
    if (!isVehicleExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.vehicle_not_found"),
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
    let vehicle_license_front = null;
    let vehicle_license_back = null;
    let courier_license_front = null;
    let courier_license_back = null;
    let courier_criminal_record = null;

    if (personal_photoFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: personal_photoFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      personal_photo = secure_url;
    }
    if (national_id_photo_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      national_id_photo_front = secure_url;
    }
    if (national_id_photo_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      national_id_photo_back = secure_url;
    }
    if (vehicle_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      vehicle_license_front = secure_url;
    }
    if (vehicle_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      vehicle_license_back = secure_url;
    }
    if (courier_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_license_front = secure_url;
    }
    if (courier_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_license_back = secure_url;
    }
    if (courier_criminal_recordFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_criminal_recordFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_criminal_record = secure_url;
    }

    // step: generate OTP
    const otpCode = createOtp(settings.otp_length);

    // step: find Courier role
    let courierRole = await prisma.userRole.findFirst({
      where: { name: this.COURIER_ROLE_NAME },
    });
    if (!courierRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.courier_role_not_found"),
      );
    }

    // step: find firstBadge
    const firstBadge = await prisma.userBadge.findFirst({
      where: { role_id: courierRole.id },
    });
    if (!firstBadge) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.badge_not_found"),
      );
    }

    // step: create User and Courier in transaction
    const result = await prisma.$transaction(async (tx) => {
      // Create User first (now includes photos and badge)
      const newUser = await tx.user.create({
        data: {
          full_name,
          phone,
          password: await hash(password),
          gender: gender ?? GenderEnum.MALE,
          personal_photo,
          badge_id: firstBadge.id,
          role_id: courierRole.id,
          lang: "AR",
          login_type: "LOCAL",
        },
      });

      // Create Courier with same ID (only courier-specific fields)
      const newCourier = await tx.courier.create({
        data: {
          user_id: newUser.id,
          national_id_photo_front,
          national_id_photo_back,
          national_id_number,
          vehicle_license_front: vehicle_license_front ?? null,
          vehicle_license_back: vehicle_license_back ?? null,
          courier_license_front: courier_license_front ?? null,
          courier_license_back: courier_license_back ?? null,
          vehicle_id: vehicle_id,
          vehicle_plate: vehicle_plate ?? null,
          courier_criminal_record: courier_criminal_record ?? null,
        },
      });

      // Create CourierStat
      await tx.courierStat.create({
        data: { courier_id: newCourier.id },
      });

      // Create NotificationSetting
      await tx.notificationSetting.create({
        data: { user_id: newUser.id },
      });

      // Create Wallet for courier
      await tx.wallet.create({
        data: {
          user_id: newUser.id,
          owner_type: "COURIER",
          balance: 0,
          status: "ACTIVE",
        },
      });

      // Create UserVerify with OTP
      await tx.userVerify.create({
        data: {
          user_id: newUser.id,
          code: otpCode,
          phone,
          type: VerifyType.VERIFY,
        },
      });

      // step: check user is created
      if (!newUser || !newCourier) {
        throw new AppError(
          HttpStatusCode.INTERNAL_SERVER_ERROR,
          "User not created",
        );
      }

      // step: send otp via sms
      // TODO: un comment next line after Broadnet credentials are ready
      // const { text } = buildVerificationSms({
      //   code: otpCode,
      //   lang: newUser.lang == "AR" ? "ar" : "en",
      // });
      // await sendSms({
      //   to: newUser.phone as string,
      //   text,
      //   lang: newUser.lang == "AR" ? "ar" : "en",
      // });

      return { user: newUser, courier: newCourier };
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
        expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );
    const refreshToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.courier_refresh_token_expires_in || "7d") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );

    logger.info(
      { userId: result.user.id, phone: result.user.phone },
      "[Auth] New courier registered",
    );

    return responseHandler({
      res,
      status: 201,
      message: res.__("messages.register_success"),
      data: {
        accessToken,
        refreshToken,
        // user: { ...result.user, courier: result.courier },
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
      full_name,
      phone,
      gender,
      vehicle_id,
      vehicle_plate,
      national_id_number,
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
    const { email, sub: googleId } = payload;

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

    // step: check vehicle_id existence
    const isVehicleExist = await prisma.vehicle.findUnique({
      where: { id: vehicle_id },
    });
    if (!isVehicleExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.vehicle_not_found"),
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
    let vehicle_license_front = null;
    let vehicle_license_back = null;
    let courier_license_front = null;
    let courier_license_back = null;
    let courier_criminal_record = null;

    if (personal_photoFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: personal_photoFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      personal_photo = secure_url;
    }
    if (national_id_photo_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      national_id_photo_front = secure_url;
    }
    if (national_id_photo_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      national_id_photo_back = secure_url;
    }
    if (vehicle_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      vehicle_license_front = secure_url;
    }
    if (vehicle_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      vehicle_license_back = secure_url;
    }
    if (courier_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_license_front = secure_url;
    }
    if (courier_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_license_back = secure_url;
    }
    if (courier_criminal_recordFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_criminal_recordFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_criminal_record = secure_url;
    }

    // step: find Courier role
    const courierRole = await prisma.userRole.findFirst({
      where: { name: this.COURIER_ROLE_NAME },
    });
    if (!courierRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.courier_role_not_found"),
      );
    }

    // step: find firstBadge
    const firstBadge = await prisma.userBadge.findFirst({
      where: { role_id: courierRole.id },
    });
    if (!firstBadge) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.badge_not_found"),
      );
    }

    // step: fetch application settings for points reset days
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create User and Courier in transaction
    const result = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          full_name,
          phone,
          email,
          google_id: googleId,
          gender: gender ?? GenderEnum.MALE,
          personal_photo,
          badge_id: firstBadge.id,
          role_id: courierRole.id,
          lang: "AR",
          login_type: "GOOGLE",
          is_phone_verified: false,
        },
      });

      const newCourier = await tx.courier.create({
        data: {
          user_id: newUser.id,
          national_id_photo_front,
          national_id_photo_back,
          national_id_number,
          vehicle_license_front: vehicle_license_front ?? null,
          vehicle_license_back: vehicle_license_back ?? null,
          courier_license_front: courier_license_front ?? null,
          courier_license_back: courier_license_back ?? null,
          vehicle_id: vehicle_id,
          vehicle_plate: vehicle_plate ?? null,
          courier_criminal_record: courier_criminal_record ?? null,
        },
      });

      await tx.courierStat.create({ data: { courier_id: newCourier.id } });
      await tx.notificationSetting.create({ data: { user_id: newUser.id } });
      await tx.wallet.create({
        data: {
          user_id: newUser.id,
          owner_type: "COURIER",
          balance: 0,
          status: "ACTIVE",
        },
      });

      // Note: no UserVerify record — email already verified by Google

      return { user: newUser, courier: newCourier };
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
        expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );
    const refreshToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.courier_refresh_token_expires_in || "7d") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );

    logger.info(
      { userId: result.user.id, email: result.user.email },
      "[Auth] New courier registered via Google",
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
      full_name,
      phone,
      gender,
      vehicle_id,
      vehicle_plate,
      national_id_number,
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
        throw new Error("Invalid token structure");
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

    const email = applePayload.email;
    const appleUserId = applePayload.sub;

    if (!email) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.apple_token_invalid"),
      );
    }

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

    // step: check vehicle_id existence
    const isVehicleExist = await prisma.vehicle.findUnique({
      where: { id: vehicle_id },
    });
    if (!isVehicleExist) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.vehicle_not_found"),
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
    let vehicle_license_front = null;
    let vehicle_license_back = null;
    let courier_license_front = null;
    let courier_license_back = null;
    let courier_criminal_record = null;

    if (personal_photoFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: personal_photoFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      personal_photo = secure_url;
    }
    if (national_id_photo_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      national_id_photo_front = secure_url;
    }
    if (national_id_photo_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: national_id_photo_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      national_id_photo_back = secure_url;
    }
    if (vehicle_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      vehicle_license_front = secure_url;
    }
    if (vehicle_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: vehicle_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      vehicle_license_back = secure_url;
    }
    if (courier_license_frontFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_frontFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_license_front = secure_url;
    }
    if (courier_license_backFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_license_backFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_license_back = secure_url;
    }
    if (courier_criminal_recordFile) {
      const { secure_url } = await uploadSingleFile({
        fileLocation: courier_criminal_recordFile.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      courier_criminal_record = secure_url;
    }

    // step: find Courier role
    const courierRole = await prisma.userRole.findFirst({
      where: { name: this.COURIER_ROLE_NAME },
    });
    if (!courierRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.courier_role_not_found"),
      );
    }

    // step: find firstBadge
    const firstBadge = await prisma.userBadge.findFirst({
      where: { role_id: courierRole.id },
    });
    if (!firstBadge) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.badge_not_found"),
      );
    }

    // step: fetch application settings for points reset days
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: create User and Courier in transaction
    const result = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          full_name,
          phone,
          email,
          apple_id: appleUserId,
          gender: gender ?? GenderEnum.MALE,
          personal_photo,
          badge_id: firstBadge.id,
          role_id: courierRole.id,
          lang: "AR",
          login_type: "APPLE",
          is_phone_verified: false,
        },
      });

      const newCourier = await tx.courier.create({
        data: {
          user_id: newUser.id,
          national_id_photo_front,
          national_id_photo_back,
          national_id_number,
          vehicle_license_front: vehicle_license_front ?? null,
          vehicle_license_back: vehicle_license_back ?? null,
          courier_license_front: courier_license_front ?? null,
          courier_license_back: courier_license_back ?? null,
          vehicle_id: vehicle_id,
          vehicle_plate: vehicle_plate ?? null,
          courier_criminal_record: courier_criminal_record ?? null,
        },
      });

      await tx.courierStat.create({ data: { courier_id: newCourier.id } });
      await tx.notificationSetting.create({ data: { user_id: newUser.id } });
      await tx.wallet.create({
        data: {
          user_id: newUser.id,
          owner_type: "COURIER",
          balance: 0,
          status: "ACTIVE",
        },
      });

      // Note: no UserVerify record — email already verified by Apple

      return { user: newUser, courier: newCourier };
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
        expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );
    const refreshToken = createJwt(
      { userId: result.user.id, userPhone: result.user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.courier_refresh_token_expires_in || "7d") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );

    logger.info(
      { userId: result.user.id, email: result.user.email },
      "[Auth] New courier registered via Apple",
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

  // ============================ verifyOtp ============================
  verifyOtp = async (req: Request, res: Response, next: NextFunction) => {
    const {
      phone,
      user_otp,
      second_phone,
      second_user_otp,
      new_password,
      verify_type,
    }: verifyPhonDTO = req.body;
    console.log({
      phone,
      user_otp,
      second_phone,
      second_user_otp,
      new_password,
      verify_type,
    });
    // step: check phone existence
    const user = await prisma.user.findFirst({
      where: { phone },
      include: { courier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: find UserVerify
    const userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id, type: verify_type, phone },
    });
    if (!userVerify) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.verify_record_not_found"),
      );
    }
    // step: find UserVerify2
    let userVerify2: any;
    if (verify_type === VerifyType.CHANGE_PHONE) {
      userVerify2 = await prisma.userVerify.findFirst({
        where: {
          user_id: user.id,
          type: VerifyType.CHANGE_PHONE,
          phone: second_phone as string,
        },
      });
      if (!userVerify2) {
        throw new AppError(
          HttpStatusCode.INTERNAL_SERVER_ERROR,
          res.__("errors.verify_record_not_found"),
        );
      }
    }

    // step: check user_otp
    if (!userVerify.code || userVerify.code !== user_otp) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.otp_invalid"),
      );
    }
    // step: check second_user_otp
    if (verify_type === VerifyType.CHANGE_PHONE) {
      if (!userVerify2.code || userVerify2.code !== second_user_otp) {
        throw new AppError(
          HttpStatusCode.UNAUTHORIZED,
          res.__("errors.otp_invalid"),
        );
      }
    }

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst({
      select: { otp_validity_duration_minutes: true },
    });
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: check if otp expired
    const otpTime = userVerify.updated_at ?? userVerify.created_at;
    if (
      otpTime.getTime() +
        (settings.otp_validity_duration_minutes ?? 5) * 60 * 1000 <
      Date.now()
    ) {
      // await prisma.userVerify.delete({ where: { id: userVerify.id } });
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.otp_expired"),
      );
    }
    // step: check if second_otp expired
    if (verify_type === VerifyType.CHANGE_PHONE) {
      const otpTime2 = userVerify2.updated_at ?? userVerify2.created_at;
      if (
        otpTime2.getTime() +
          (settings.otp_validity_duration_minutes ?? 5) * 60 * 1000 <
        Date.now()
      ) {
        // await prisma.userVerify.delete({ where: { id: userVerify2.id } });
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.otp_expired"),
        );
      }
    }

    // step: actions depend on verify type
    switch (verify_type) {
      case VerifyType.VERIFY:
        await prisma.user.update({
          where: { id: user.id },
          data: { is_phone_verified: true },
        });
        break;

      case VerifyType.CHANGE_PHONE: {
        // step: ensure the new phone is not already used by another account
        const phoneTaken = await prisma.user.findFirst({
          where: { phone: second_phone as string, id: { not: user.id } },
        });
        if (phoneTaken) {
          throw new AppError(
            HttpStatusCode.BAD_REQUEST,
            res.__("errors.user_already_exists"),
          );
        }
        await prisma.user.update({
          where: { id: user.id },
          data: { phone: second_phone as string, is_phone_verified: true },
        });
        break;
      }

      case VerifyType.FORGET_PASSWORD:
        await prisma.user.update({
          where: { id: user.id },
          data: { password: await hash(new_password as string) },
        });
        break;

      default:
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.invalid_verify_type"),
        );
    }

    // step: delete UserVerify record after successful verification
    await prisma.userVerify.delete({
      where: { id: userVerify.id },
    });
    if (verify_type === VerifyType.CHANGE_PHONE) {
      await prisma.userVerify.delete({
        where: { id: userVerify2.id },
      });
    }

    logger.info(
      { userId: user.id, phone: user.phone },
      "[Auth] Phone OTP verified",
    );

    return responseHandler({
      res,
      message: res.__("messages.phone_verified"),
    });
  };

  // ============================ resendOtp ============================
  resendOtp = async (req: Request, res: Response, next: NextFunction) => {
    const { phone, second_phone, verify_type }: resendOtpDTO = req.body;

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst({
      select: { otp_length: true },
    });
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: check phone existence
    const user = await prisma.user.findUnique({
      where: { phone },
      include: { courier: true },
    });
    if (!user || !user.courier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: find and delete UserVerify
    const userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id, type: verify_type, phone },
    });
    let userVerify2;
    if (verify_type === VerifyType.CHANGE_PHONE) {
      userVerify2 = await prisma.userVerify.findFirst({
        where: {
          user_id: user.id,
          type: VerifyType.CHANGE_PHONE,
          phone: second_phone as string,
        },
      });
    }
    if (userVerify) {
      await prisma.userVerify.delete({
        where: { id: userVerify.id },
      });
    }
    if (userVerify2) {
      await prisma.userVerify.delete({
        where: { id: userVerify2.id },
      });
    }

    // step: generate OTP
    const otpCode = createOtp(settings.otp_length);
    let otpCode2;
    if (verify_type === VerifyType.CHANGE_PHONE) {
      otpCode2 = createOtp(settings.otp_length);
    }

    // step: create UserVerify record
    await prisma.userVerify.create({
      data: {
        user_id: user.id,
        code: otpCode,
        type: verify_type,
        phone,
      },
    });
    if (verify_type === VerifyType.CHANGE_PHONE) {
      await prisma.userVerify.create({
        data: {
          user_id: user.id,
          code: otpCode2 as string,
          type: VerifyType.CHANGE_PHONE,
          phone: second_phone as string,
        },
      });
    }

    // step: send otp via sms
    // TODO: un comment next line after Broadnet credentials are ready
    // const { text } = buildVerificationSms({
    //   code: otpCode,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });
    // await sendSms({
    //   to: user.phone as string,
    //   text,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });
    // if (verify_type === VerifyType.CHANGE_PHONE) {
    //   const { text } = buildVerificationSms({
    //     code: otpCode2 as string,
    //     lang: user.lang == "AR" ? "ar" : "en",
    //   });
    //   await sendSms({
    //     to: second_phone as string,
    //     text,
    //     lang: user.lang == "AR" ? "ar" : "en",
    //   });
    // }

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
      include: { courier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check credentials 2 - check if user has the correct role
    if (user.role_id !== 2) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check credentials 3 - reject accounts without a local password (e.g. Google/Apple)
    if (!user.password) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check credentials 4 - validate password
    if (!(await compare(password, user.password))) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check credentials 3 - user verify phone
    if (!user.is_phone_verified) {
      // step: fetch application settings
      const settings = await prisma.applicationSetting.findFirst({
        select: { otp_length: true },
      });
      if (!settings) {
        throw new AppError(
          HttpStatusCode.INTERNAL_SERVER_ERROR,
          res.__("errors.settings_not_found"),
        );
      }

      // step: generate OTP
      const otpCode = createOtp(settings.otp_length);

      // step: create UserVerify record
      await prisma.userVerify.create({
        data: {
          user_id: user.id,
          code: otpCode,
          type: VerifyType.VERIFY,
          phone,
        },
      });

      // step: send otp via sms
      // TODO: un comment next line after Broadnet credentials are ready
      // const { text } = buildVerificationSms({
      //   code: otpCode,
      //   lang: user.lang == "AR" ? "ar" : "en",
      // });
      // await sendSms({
      //   to: user.phone as string,
      //   text,
      //   lang: user.lang == "AR" ? "ar" : "en",
      // });

      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.phone_not_verified"),
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
        expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );
    const refreshToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.courier_refresh_token_expires_in || "7d") as any,
        jwtid: createOtp(settings.otp_length),
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
        // user: { ...result.user, courier: result.courier },
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
    const jwtid = createOtp(settings.otp_length);
    const accessToken = createJwt(newPayload, env.ACCESS_SEGNATURE as string, {
      expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
      jwtid,
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
        throw new Error("Invalid token structure");
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
      include: { courier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check if user has the correct role
    if (user.role_id !== 2) {
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
        expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );
    const refreshToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.courier_refresh_token_expires_in || "7d") as any,
        jwtid: createOtp(settings.otp_length),
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
        throw new Error("Invalid token structure");
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
      include: { courier: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.invalid_credentials"),
      );
    }

    // step: check if user has the correct role
    if (user.role_id !== 2) {
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
        expiresIn: (settings.courier_access_token_expires_in || "1h") as any,
        jwtid: createOtp(settings.otp_length),
      },
    );
    const refreshToken = createJwt(
      { userId: user.id, userPhone: user.phone },
      env.REFRESH_SEGNATURE as string,
      {
        expiresIn: (settings.courier_refresh_token_expires_in || "7d") as any,
        jwtid: createOtp(settings.otp_length),
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

    // step: reject accounts without a local password (e.g. Google/Apple)
    if (!user.password) {
      throw new AppError(
        HttpStatusCode.UNAUTHORIZED,
        res.__("errors.invalid_credentials"),
      );
    }

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

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst({
      select: { otp_length: true },
    });
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: check phone existence
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: find and delete UserVerify
    const userVerify = await prisma.userVerify.findFirst({
      where: { user_id: user.id, type: VerifyType.FORGET_PASSWORD, phone },
    });
    if (userVerify) {
      await prisma.userVerify.delete({
        where: { id: userVerify.id },
      });
    }

    // step: generate OTP
    const otpCode = createOtp(settings.otp_length);

    // step: create UserVerify record
    await prisma.userVerify.create({
      data: {
        user_id: user.id,
        code: otpCode,
        type: VerifyType.FORGET_PASSWORD,
        phone,
      },
    });

    // step: send otp via sms
    // TODO: un comment next line after Broadnet credentials are ready
    // const { text } = buildVerificationSms({
    //   code: otpCode,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });
    // await sendSms({
    //   to: user.phone as string,
    //   text,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });

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
      where: { user_id: user.id, type: VerifyType.FORGET_PASSWORD, phone },
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
    const settings = await prisma.applicationSetting.findFirst({
      select: { otp_validity_duration_minutes: true },
    });
    const otpValidityMs =
      (settings?.otp_validity_duration_minutes ?? 5) * 60 * 1000;
    const otpTime = userVerify.updated_at ?? userVerify.created_at;
    if (otpTime.getTime() + otpValidityMs < Date.now()) {
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

  // ============================ changePhone ============================
  changePhone = async (req: Request, res: Response, next: NextFunction) => {
    const { current_phone, new_phone }: changePhoneDTO = req.body;

    // step: fetch application settings
    const settings = await prisma.applicationSetting.findFirst({
      select: { otp_length: true },
    });
    if (!settings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.settings_not_found"),
      );
    }

    // step: check phone existence
    const user = await prisma.user.findUnique({
      where: { phone: current_phone },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    // step: ensure the new phone is not already used by another account
    const phoneTaken = await prisma.user.findUnique({
      where: { phone: new_phone },
    });
    if (phoneTaken) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.user_already_exists"),
      );
    }

    // step: delete any previous change-phone OTP records (both phones) to avoid stale matches
    await prisma.userVerify.deleteMany({
      where: { user_id: user.id, type: VerifyType.CHANGE_PHONE },
    });

    // step: generate OTP
    const otpCode = createOtp(settings.otp_length);
    const otpCode2 = createOtp(settings.otp_length);

    // step: create UserVerify record
    await prisma.userVerify.create({
      data: {
        user_id: user.id,
        code: otpCode,
        type: VerifyType.CHANGE_PHONE,
        phone: current_phone,
      },
    });
    await prisma.userVerify.create({
      data: {
        user_id: user.id,
        code: otpCode2,
        type: VerifyType.CHANGE_PHONE,
        phone: new_phone,
      },
    });

    // step: send otp via sms
    // TODO: un comment next line after Broadnet credentials are ready
    // const { text } = buildVerificationSms({
    //   code: otpCode,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });
    // await sendSms({
    //   to: current_phone as string,
    //   text,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });
    // const { text: text2 } = buildVerificationSms({
    //   code: otpCode2,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });
    // await sendSms({
    //   to: new_phone as string,
    //   text: text2,
    //   lang: user.lang == "AR" ? "ar" : "en",
    // });

    return responseHandler({
      res,
      message: res.__("messages.otp_sent_reset"),
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

  // ============================ availableVehicles ============================
  availableVehicles = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;

    // step: get available vehicles
    const vehicles = await prisma.vehicle.findMany();

    return responseHandler({
      res,
      data: { vehicles },
    });
  };

  // ============================ saveReferralCode ============================
  saveReferralCode = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { userId } = req.params;
    const { referral_code }: referralCodeDTO = req.body;

    // step: validate userId is a positive integer
    const id = Number(userId);
    if (!Number.isInteger(id) || id <= 0) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_user_id"),
      );
    }

    // step: check if user exists
    const user = await prisma.user.findUnique({
      where: { id },
      include: { role: true },
    });
    if (!user) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );
    }

    //step: save referrel code
    await prisma.user.update({
      where: { id },
      data: { referral_code },
    });

    return responseHandler({
      res,
      message: res.__("messages.save_referral_code"),
    });
  };
}
