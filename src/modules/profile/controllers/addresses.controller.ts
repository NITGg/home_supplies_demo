import type { Response } from "express";
import { HttpError } from "@/lib/httpError";
import {
  addressIdParamSchema,
  createAddressSchema,
  updateAddressSchema,
} from "../../../schemas/addresses.schema";
import {
  listAddressesService,
  createAddressService,
  updateAddressService,
  deleteMyAddressService,
} from "@/services/addresses.service";
import FeatureApi from "@/lib/featureApi";
import { AuthedRequest } from "@/types/authedRequest";

export async function listMyAddresses(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .fields()
    .includes()
    .limit()
    .sort()
    .skip()
    .keyword()
    .filter(
      {
        customer_id: req.user.id,
        deleted_at: null,
      },
      { allowKeys: [] },
    ).data;

  const addresses = await listAddressesService(data);
  return res.status(200).json(addresses);
}

export async function createMyAddress(req: AuthedRequest, res: Response) {

  const parsed = createAddressSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res.status(400).json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const address = await createAddressService(req.user.id, parsed.data);
  return res
    .status(201)
    .json({ message: req.t("profile:messages.address_created"), address });
}

export async function updateMyAddress(req: AuthedRequest, res: Response) {

  const params = addressIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "profile:errors.address_id_invalid");

  const parsed = updateAddressSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res.status(400).json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const address = await updateAddressService(
    req.user.id,
    params.data.id,
    parsed.data,
  );
  return res
    .status(200)
    .json({ message: req.t("profile:messages.address_updated"), address });
}

export async function deleteMyAddress(req: AuthedRequest, res: Response) {
  const params = addressIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success)
    throw new HttpError(400, "profile:errors.address_id_invalid");

  await deleteMyAddressService(req.user.id, params.data.id);
  return res
    .status(200)
    .json({ message: req.t("profile:messages.address_deleted") });
}
