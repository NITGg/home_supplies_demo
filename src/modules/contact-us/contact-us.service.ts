import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateContactUsInput,
  UpdateContactUsInput,
  DeleteManyContactUsInput,
} from "./contact-us.schema";

export async function createContactUsService(data: CreateContactUsInput) {
  return prisma.contactUs.create({ data });
}

export async function listContactUsService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalMessages, messages] = await prisma.$transaction([
    prisma.contactUs.count({ where: data.where as any }),
    prisma.contactUs.findMany(data as any),
  ]);

  return {
    totalMessages,
    totalPages: Math.ceil(totalMessages / take),
    messages,
  };
}

export async function getContactUsByIdService(input: { id: number }) {
  const message = await prisma.contactUs.findUnique({
    where: { id: input.id },
  });
  if (!message) throw new HttpError(404, "contact-us:errors.not_found");
  return message;
}

export async function updateContactUsService(input: {
  id: number;
  data: UpdateContactUsInput;
}) {
  const exists = await prisma.contactUs.findUnique({
    where: { id: input.id },
    select: { id: true, read: true },
  });
  if (!exists) throw new HttpError(404, "contact-us:errors.not_found");

  const nextData: UpdateContactUsInput & { read_at?: Date | null } = {
    ...input.data,
  };

  if (typeof input.data.read === "boolean") {
    if (input.data.read) {
      nextData.read_at =
        input.data.read_at ?? (exists.read ? undefined : new Date());
    } else {
      nextData.read_at = null;
    }
  }

  return prisma.contactUs.update({
    where: { id: input.id },
    data: nextData,
  });
}

export async function deleteManyContactUsService(
  input: DeleteManyContactUsInput,
) {
  const result = await prisma.contactUs.deleteMany({
    where: { id: { in: input.ids } },
  });
  return { count: result.count };
}

export async function deleteContactUsService(input: { id: number }) {
  const exists = await prisma.contactUs.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "contact-us:errors.not_found");

  await prisma.contactUs.delete({ where: { id: input.id } });
  return { ok: true as const };
}
