import type { Response } from "express";
import { HttpError } from "@/lib/httpError";
import {
  listAddressesService,
  createAddressService,
  updateAddressService,
  adminDeleteAddressesService,
  adminDeleteAddressService,
} from "@/services/addresses.service";
import FeatureApi from "@/lib/featureApi";
import {
  createAddressSchema,
  userIdParamSchema,
  adminDeleteAddressesSchema,
  updateAdminAddressSchema,
  userAddressParamsSchema,
  adminDeleteAddressSchema,
} from "@/schemas/addresses.schema";
import type { AuthedRequest } from "@/types/authedRequest";

export async function listAddresses(req: AuthedRequest, res: Response) {
  const params = userIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "users:errors.user_id_invalid");
  const data = new FeatureApi(req)
    .fields()
    .includes()
    .limit()
    .sort()
    .skip()
    .keyword()
    .filter({
      customer_id: params.data.userId,
    }).data;

  const addresses = await listAddressesService(data);
  return res.status(200).json(addresses);
}

export async function createAddress(req: AuthedRequest, res: Response) {
  const params = userIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "users:errors.user_id_invalid");

  const parsed = createAddressSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const address = await createAddressService(params.data.userId, parsed.data);
  return res
    .status(201)
    .json({ message: req.t("profile:messages.address_created"), address });
}

export async function updateAddress(req: AuthedRequest, res: Response) {
  const params = userAddressParamsSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "profile:errors.address_id_invalid");

  const parsed = updateAdminAddressSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const address = await updateAddressService(
    params.data.userId,
    params.data.addressId,
    parsed.data,
    {
      allowArchived: true,
    },
  );
  return res
    .status(200)
    .json({ message: req.t("profile:messages.address_updated"), address });
}

export async function deleteAddresses(req: AuthedRequest, res: Response) {
  const params = userIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "users:errors.user_id_invalid");

  const parsed = adminDeleteAddressesSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0]?.path[0] });
  }

  const result = await adminDeleteAddressesService({
    userId: params.data.userId,
    addressIds: parsed.data.addressIds,
    archived: parsed.data.archived,
  });
  return res
    .status(200)
    .json({ message: req.t("profile:messages.address_deleted"), ...result });
}
export async function deleteAddress(req: AuthedRequest, res: Response) {
  const params = userAddressParamsSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "profile:errors.address_id_invalid");
  const parsed = adminDeleteAddressSchema.safeParse({
    ...req.sanitized.body,
    id: params.data.addressId,
  });
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res
      .status(400)
      .json({ message: req.t(key), field: parsed.error.issues[0]?.path[0] });
  }

  const result = await adminDeleteAddressService({
    userId: params.data.userId,
    addressId: params.data.addressId,
    archived: parsed.data.archived,
  });
  return res
    .status(200)
    .json({ message: req.t("profile:messages.address_deleted"), ...result });
}
