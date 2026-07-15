import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type {
  CreateAddressInput,
  UpdateAddressInput,
  UpdateAdminAddressInput,
} from "@/schemas/addresses.schema";
import FeatureApi from "@/lib/featureApi";

export async function listAddressesService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  const [totalAddresses, addresses] = await prisma.$transaction([
    prisma.customerAddress.count({
      where: { ...data.where },
    }),
    prisma.customerAddress.findMany({
      where: { ...data.where },
      ...(data as any),
    }),
  ]);
  return {
    addresses,
    totalAddresses,
    totalPages: Math.ceil(totalAddresses / take),
  };
}

export async function createAddressService(
  userId: number,
  input: CreateAddressInput,
) {
  const existingCount = await prisma.customerAddress.count({
    where: { customer_id: userId },
  });

  const shouldBeDefault = input.is_default === true || existingCount === 0;

  return await prisma.$transaction(async (tx) => {
    if (shouldBeDefault) {
      await tx.customerAddress.updateMany({
        where: { customer_id: userId, is_default: true },
        data: { is_default: false },
      });
    }

    return tx.customerAddress.create({
      data: {
        ...input,
        // address_lat: input.address_lat ?? null,
        // address_long: input.address_long ?? null,
        customer_id: userId,
        is_default: shouldBeDefault,
      },
    });
  });
}

export async function updateAddressService(
  userId: number,
  id: number,
  input: UpdateAddressInput | UpdateAdminAddressInput,
  opts?: { allowArchived?: boolean },
) {
  const exists = await prisma.customerAddress.findFirst({
    where: {
      id,
      customer_id: userId,
      ...(opts?.allowArchived ? {} : { deleted_at: null }),
    },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "profile:errors.address_not_found");

  return await prisma.$transaction(async (tx) => {
    if (input.is_default === true) {
      await tx.customerAddress.updateMany({
        where: { customer_id: userId, id: { not: id }, is_default: true },
        data: { is_default: false },
      });
    }

    return tx.customerAddress.update({
      where: { id },
      data: input,
    });
  });
}

export async function deleteMyAddressService(userId: number, id: number) {
  const exists = await prisma.customerAddress.findFirst({
    where: { id, customer_id: userId, deleted_at: null },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "profile:errors.address_not_found");

  await prisma.customerAddress.update({
    where: { id },
    data: { deleted_at: new Date() },
  });

  return { ok: true as const };
}

export async function adminDeleteAddressService(input: {
  userId: number;
  addressId: number;
  archived: boolean;
}) {
  const exists = await prisma.customerAddress.findFirst({
    where: { id: input.addressId, customer_id: input.userId },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "profile:errors.address_not_found");

  if (input.archived) {
    await prisma.customerAddress.update({
      where: { id: input.addressId },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const };
  }

  await prisma.customerAddress.delete({
    where: { id: input.addressId },
  });
  return { archived: false as const };
}

export async function adminDeleteAddressesService(input: {
  userId: number;
  addressIds: number[];
  archived: boolean;
}) {
  // ensure they belong to that user (avoid deleting someone else's addresses)
  const found = await prisma.customerAddress.findMany({
    where: {
      id: { in: input.addressIds },
      customer_id: input.userId,
    },
    select: { id: true },
  });

  if (found.length !== input.addressIds.length) {
    throw new HttpError(404, "profile:errors.address_not_found");
  }

  if (input.archived) {
    const result = await prisma.customerAddress.updateMany({
      where: {
        id: { in: input.addressIds },
        customer_id: input.userId,
      },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const, count: result.count };
  }

  const result = await prisma.customerAddress.deleteMany({
    where: {
      id: { in: input.addressIds },
      customer_id: input.userId,
    },
  });
  return { archived: false as const, count: result.count };
}
