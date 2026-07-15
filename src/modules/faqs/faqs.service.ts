import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateFaqInput,
  UpdateFaqInput,
  DeleteManyFaqsInput,
} from "./faqs.schema";

export async function listFaqsService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalFaqs, faqs] = await prisma.$transaction([
    prisma.faq.count({ where: data.where as any }),
    prisma.faq.findMany(data as any),
  ]);

  return {
    totalFaqs,
    totalPages: Math.ceil(totalFaqs / take),
    faqs,
  };
}

export async function getFaqByIdService(input: { id: number }) {
  const faq = await prisma.faq.findUnique({ where: { id: input.id } });
  if (!faq) throw new HttpError(404, "faqs:errors.not_found");
  return faq;
}

export async function createFaqService(data: CreateFaqInput) {
  return prisma.faq.create({ data });
}

export async function updateFaqService(input: {
  id: number;
  data: UpdateFaqInput;
}) {
  const exists = await prisma.faq.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "faqs:errors.not_found");

  return prisma.faq.update({
    where: { id: input.id },
    data: input.data,
  });
}

export async function deleteManyFaqsService(input: DeleteManyFaqsInput) {
  const result = await prisma.faq.deleteMany({
    where: { id: { in: input.ids } },
  });
  return { count: result.count };
}

export async function deleteFaqService(input: { id: number }) {
  const exists = await prisma.faq.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "faqs:errors.not_found");

  await prisma.faq.delete({ where: { id: input.id } });
  return { ok: true as const };
}
