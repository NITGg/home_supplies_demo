import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  faqIdParamSchema,
  createFaqSchema,
  updateFaqSchema,
  deleteFaqSchema,
  deleteManyFaqsSchema,
} from "./faqs.schema";
import {
  listFaqsService,
  getFaqByIdService,
  createFaqService,
  updateFaqService,
  deleteFaqService,
  deleteManyFaqsService,
} from "./faqs.service";

export async function adminListFaqs(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("sort_id")
    .limit(20)
    .skip()
    .includes()
    .keyword(["question", "answer"], "OR")
    .fields().data;

  const result = await listFaqsService(data);
  return res.json(result);
}

export async function listPublicFaqs(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter({ is_active: true }, { allowKeys: ["language", "target_user"] })
    .sort("sort_id")
    .limit(20)
    .skip()
    .includes()
    .keyword(["question", "answer"], "OR")
    .fields().data;

  const result = await listFaqsService(data);
  return res.json(result);
}

export async function adminGetFaq(req: AuthedRequest, res: Response) {
  const { id } = faqIdParamSchema.parse(req.sanitized.params);
  const faq = await getFaqByIdService({ id });
  return res.json({ faq });
}

export async function adminCreateFaq(req: AuthedRequest, res: Response) {
  const data = createFaqSchema.parse(req.sanitized.body);
  const faq = await createFaqService(data);
  return res.status(201).json({
    message: req.t?.("faqs:messages.created") ?? "FAQ created",
    faq,
  });
}

export async function adminUpdateFaq(req: AuthedRequest, res: Response) {
  const { id } = faqIdParamSchema.parse(req.sanitized.params);
  const data = updateFaqSchema.parse(req.sanitized.body);
  const faq = await updateFaqService({ id, data });
  return res.json({
    message: req.t?.("faqs:messages.updated") ?? "FAQ updated",
    faq,
  });
}

export async function deleteManyFaqs(req: AuthedRequest, res: Response) {
  const data = deleteManyFaqsSchema.parse(req.sanitized.body);
  const result = await deleteManyFaqsService(data);
  return res.json({
    message: req.t?.("faqs:messages.deleted") ?? "FAQs deleted",
    ...result,
  });
}

export async function adminDeleteFaq(req: AuthedRequest, res: Response) {
  const { id } = deleteFaqSchema.parse(req.sanitized.params);
  await deleteFaqService({ id });
  return res.json({
    message: req.t?.("faqs:messages.deleted") ?? "FAQ deleted",
  });
}
