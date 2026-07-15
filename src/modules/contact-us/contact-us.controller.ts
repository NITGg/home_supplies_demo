import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  contactUsIdParamSchema,
  createContactUsSchema,
  updateContactUsSchema,
  deleteContactUsSchema,
  deleteManyContactUsSchema,
} from "./contact-us.schema";
import {
  createContactUsService,
  listContactUsService,
  getContactUsByIdService,
  updateContactUsService,
  deleteContactUsService,
  deleteManyContactUsService,
} from "./contact-us.service";

export async function createContactUs(req: Request, res: Response) {
  const data = createContactUsSchema.parse(req.sanitized.body);
  const message = await createContactUsService(data);
  return res.status(201).json({
    message: req.t?.("contact-us:messages.created") ?? "Message sent",
    message_data: message,
  });
}

export async function adminListContactUs(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(["name", "email", "message", "response"], "OR")
    .fields().data;

  const result = await listContactUsService(data);
  return res.json(result);
}

export async function adminGetContactUs(req: AuthedRequest, res: Response) {
  const { id } = contactUsIdParamSchema.parse(req.sanitized.params);
  const message = await getContactUsByIdService({ id });
  return res.json({ message });
}

export async function adminUpdateContactUs(req: AuthedRequest, res: Response) {
  const { id } = contactUsIdParamSchema.parse(req.sanitized.params);
  const data = updateContactUsSchema.parse(req.sanitized.body);
  const message = await updateContactUsService({ id, data });

  return res.json({
    message: req.t?.("contact-us:messages.updated") ?? "Message updated",
    message_data: message,
  });
}

export async function deleteManyContactUs(req: AuthedRequest, res: Response) {
  const data = deleteManyContactUsSchema.parse(req.sanitized.body);
  const result = await deleteManyContactUsService(data);
  return res.json({
    message: req.t?.("contact-us:messages.deleted") ?? "Messages deleted",
    ...result,
  });
}

export async function adminDeleteContactUs(req: AuthedRequest, res: Response) {
  const { id } = deleteContactUsSchema.parse(req.sanitized.params);
  await deleteContactUsService({ id });
  return res.json({
    message: req.t?.("contact-us:messages.deleted") ?? "Message deleted",
  });
}
