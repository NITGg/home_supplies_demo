import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateOnBoardingInput,
  UpdateOnBoardingInput,
  DeleteManyOnBoardingInput,
} from "./on-boarding.schema";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";

export async function listOnBoardingService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalItems, items] = await prisma.$transaction([
    prisma.onBoarding.count({ where: data.where as any }),
    prisma.onBoarding.findMany(data as any),
  ]);

  return {
    totalItems,
    totalPages: Math.ceil(totalItems / take),
    items,
  };
}

export async function getOnBoardingByIdService(input: { id: number }) {
  const item = await prisma.onBoarding.findUnique({
    where: { id: input.id },
  });
  if (!item) throw new HttpError(404, "on-boarding:errors.not_found");
  return item;
}

export async function createOnBoardingService(input: {
  data: CreateOnBoardingInput;
  file?: Express.Multer.File;
}) {
  const { data, file } = input;

  let image_url = data.image_url ?? null;

  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "onboarding",
    });
    image_url = secure_url;
  }

  return prisma.onBoarding.create({
    data: {
      ...data,
      image_url,
    },
  });
}

export async function updateOnBoardingService(input: {
  id: number;
  data: UpdateOnBoardingInput;
  file?: Express.Multer.File;
}) {
  const { id, data, file } = input;

  const current = await prisma.onBoarding.findUnique({
    where: { id },
    select: { id: true, image_url: true },
  });
  if (!current) throw new HttpError(404, "on-boarding:errors.not_found");

  let nextImageUrl: string | null | undefined = undefined;

  // If file uploaded => upload and replace image_url
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "onboarding",
    });
    nextImageUrl = secure_url;
    if (current.image_url) {
      const publicId = extractPublicIdFromUrl(current.image_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
  } else if (data.image_url !== undefined) {
    // allow body update to URL/null
    nextImageUrl = data.image_url ?? null;
  }

  return prisma.onBoarding.update({
    where: { id },
    data: {
      ...data,
      ...(nextImageUrl === undefined ? {} : { image_url: nextImageUrl }),
    },
  });
}

export async function deleteManyOnBoardingService(
  input: DeleteManyOnBoardingInput,
) {
  if (input.archived) {
    const result = await prisma.onBoarding.updateMany({
      where: { id: { in: input.ids } },
      data: { deleted_at: new Date() },
    });
    return { count: result.count };
  }

  const result = await prisma.onBoarding.deleteMany({
    where: { id: { in: input.ids } },
  });
  return { count: result.count };
}

export async function deleteOnBoardingService(input: {
  id: number;
  archived?: boolean;
}) {
  const exists = await prisma.onBoarding.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "on-boarding:errors.not_found");

  if (input.archived) {
    await prisma.onBoarding.update({
      where: { id: input.id },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const };
  }

  await prisma.onBoarding.delete({ where: { id: input.id } });
  return { ok: true as const };
}
