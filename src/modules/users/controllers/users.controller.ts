import type { Request, Response } from "express";
import { uploadSingleFile } from "@/lib/cloudinary/cloudinary.service";
import { HttpError } from "@/lib/httpError";
import {
  createUserSchema,
  updateUserSchema,
  userIdParamSchema,
  deleteUsersSchema,
  deleteUserSchema,
} from "../schemas/users.schema";
import {
  createUserService,
  listUsersService,
  getUserByIdService,
  updateUserService,
  deleteUsersService,
  deleteUserService,
  getOnlineCouriersService,
  listSuppliersService,
  listSuppliersByLocationService,
  getSupplierByIdService,
  approveSupplierService,
  rejectSupplierService,
  updateSupplierService,
  getSupplierCategoriesService,
  getSupplierProductsService,
  createSupplierAddressService,
  updateSupplierAddressService,
} from "../services/users.service";
import FeatureApi from "@/lib/featureApi";
import { customerLocationSchema } from "@/lib/catalogLocation";
import { logger } from "@/config/logger";
import { AuthedRequest } from "@/types/authedRequest";

export async function createUser(req: Request, res: Response) {
  const parsed = createUserSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }
  const file = req.file;

  const user = await createUserService(parsed.data, file);

  return res
    .status(201)
    .json({ message: req.t("users:messages.user_created"), user });
}

export async function listUsers(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter() // always enforce
    .sort("-created_at") // default sort if query.sort missing
    .limit(10) // default limit if query.limit missing
    .skip(0)
    .includes()
    .keyword(["full_name", "email", "phone", "role.name"], "OR")
    .fields().data;

  const result = await listUsersService(data);

  return res.status(200).json(result);
}

export async function deleteUsers(req: Request, res: Response) {
  const parsed = deleteUsersSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await deleteUsersService(parsed.data);

  return res.status(200).json({
    message: result.archived
      ? req.t("users:messages.users_archived")
      : req.t("users:messages.users_deleted"),
    count: result.count,
  });
}

// by id
export async function getUser(req: Request, res: Response) {
  const params = userIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "users:errors.user_id_invalid");

  const data = new FeatureApi(req)
    .filter({ id: params.data.id }, { allowKeys: [] })
    .includes()
    .fields().data;

  const user = await getUserByIdService(data);

  return res.status(200).json({ user });
}

export async function updateUser(req: Request, res: Response) {
  const params = userIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "users:errors.user_id_invalid");

  const parsed = updateUserSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }
  const file = req.file;

  // TEMP DEBUG — trace is_active / deleteImage through the update flow. Remove when verified.
  console.log("[UserUpdate][BE] id:", params.data.id, {
    rawIsActive: (req.sanitized.body as any)?.is_active,
    rawDeleteImage: (req.sanitized.body as any)?.deleteImage,
    parsedIsActive: parsed.data.is_active,
    parsedDeleteImage: parsed.data.deleteImage,
    file: req.file?.originalname ?? "none",
  });

  const user = await updateUserService(
    {
      id: params.data.id,
      data: parsed.data,
    },
    file,
  );

  return res
    .status(200)
    .json({ message: req.t("users:messages.user_updated"), user });
}

export async function deleteUser(req: Request, res: Response) {
  const params = userIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "users:errors.user_id_invalid");
  const parsed = deleteUserSchema.safeParse({
    ...req.sanitized.body,
    id: params.data.id,
  });
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }
  if (!parsed.success) throw new HttpError(400, "users:errors.user_id_invalid");

  const result = await deleteUserService({ ...parsed.data });

  return res.status(200).json({
    message: result.archived
      ? req.t("users:messages.user_archived")
      : req.t("users:messages.user_deleted"),
  });
}

export async function listSuppliers(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter();
  } else {
    api.filter({
      deleted_at: null,
      is_approved: true,
      user: {
        deleted_at: null,
        is_active: true,
      },
    });
  }

  const data = api
    .fields()
    .skip()
    .sort("-created_at")
    .limit()
    .includes()
    .keyword(["user.phone", "user.email", "user.full_name"], "OR").data;

  const result = await listSuppliersService(data);
  return res.status(200).json({ result });
}

// Location-aware supplier listing. Takes the customer's lat/lng from the body
// and applies the global radius + same-governorate controls (nearest first).
export async function listNearbySuppliers(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter();
  } else {
    api.filter({
      deleted_at: null,
      is_approved: true,
      user: {
        deleted_at: null,
        is_active: true,
      },
    });
  }

  const data = api
    .fields()
    .skip()
    .sort("-created_at")
    .limit()
    .includes()
    .keyword(["user.phone", "user.email", "user.full_name"], "OR").data;

  // current customer location from body (radius / governorate behaviour is
  // controlled globally via ApplicationSetting).
  const locationOptions = customerLocationSchema.parse(
    req.sanitized.body ?? {},
  );

  const result = await listSuppliersByLocationService(data, locationOptions);
  return res.status(200).json({ result });
}

export async function getSupplierCategories(req: Request, res: Response) {
  const supplierId = Number(req.params.id);
  const categories = await getSupplierCategoriesService(supplierId);
  return res.status(200).json({ categories });
}

export async function getSupplierProducts(req: Request, res: Response) {
  const supplierId = Number(req.params.id);
  const products = await getSupplierProductsService(supplierId);
  return res.status(200).json({ products });
}

export async function getSupplier(req: Request, res: Response) {
  const supplierId = Number(req.params.id);
  const supplier = await getSupplierByIdService(supplierId);
  return res.status(200).json({ supplier });
}

export async function approveSupplier(req: Request, res: Response) {
  const supplierId = Number(req.params.id);
  const supplier = await approveSupplierService(supplierId);
  return res.status(200).json({ message: "Supplier approved", supplier });
}

export async function rejectSupplier(req: Request, res: Response) {
  const supplierId = Number(req.params.id);
  const supplier = await rejectSupplierService(supplierId);
  return res.status(200).json({ message: "Supplier rejected", supplier });
}

export async function updateSupplier(req: Request, res: Response) {
  const supplierId = Number(req.params.id);
  const files = req.files as Record<string, Express.Multer.File[]> | undefined;

  const data: Record<string, string> = { ...req.body };

  if (files?.personal_photo?.[0]) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: files.personal_photo[0].path, // .path or .buffer
      storagePathOnCloudinary: "users/Supplier",
    });
    data.personal_photo = secure_url;
  }
  if (files?.tax_card?.[0]) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: files.tax_card[0].path, // .path or .buffer
      storagePathOnCloudinary: "users/Supplier",
    });
    data.tax_card = secure_url;
  }
  if (files?.commercial_register?.[0]) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: files.commercial_register[0].path, // .path or .buffer
      storagePathOnCloudinary: "users/Supplier",
    });
    data.commercial_register = secure_url;
  }

  const supplier = await updateSupplierService(supplierId, data);
  return res.status(200).json({ message: "Supplier updated", supplier });
}

export async function createSupplierAddressHandler(
  req: Request,
  res: Response,
) {
  const supplierId = Number(req.params.id);
  const address = await createSupplierAddressService(supplierId, req.body);
  return res.status(201).json({ message: "Address created", address });
}

export async function updateSupplierAddressHandler(
  req: Request,
  res: Response,
) {
  const supplierId = Number(req.params.id);
  const addressId = Number(req.params.addressId);
  const address = await updateSupplierAddressService(
    supplierId,
    addressId,
    req.body,
  );
  return res.status(200).json({ message: "Address updated", address });
}

export async function getOnlineCouriers(req: Request, res: Response) {
  const { order_lat, order_lng, take = 10, skip = 0 } = req.sanitized.query;
  logger.debug(
    `getOnlineCouriers called with order_lat=${order_lat}, order_lng=${order_lng}, take=${take}, skip=${skip}`,
  );
  const result = await getOnlineCouriersService({
    order_lat: Number(order_lat),
    order_lng: Number(order_lng),
    take: Number(take),
    skip: Number(skip),
  });
  return res.status(200).json({ online_courier_ids: result });
}
