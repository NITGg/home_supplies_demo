import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { Prisma } from "@prisma/client";
import type { CreateUnavailableAreaRequestInput } from "./unavailable-area-request.schema";
import FeatureApi from "@/lib/featureApi";
import { log } from "node:console";

export async function createUnavailableAreaRequestService(
  customerId: number | null,
  input: CreateUnavailableAreaRequestInput,
) {
  return prisma.unavailableAreaRequest.create({
    data: {
      customer_id: customerId ?? null,
      request_type: input.request_type,
      lat: input.lat != null ? new Prisma.Decimal(input.lat) : null,
      long: input.long != null ? new Prisma.Decimal(input.long) : null,
      address: input.address,
      area: input.area,
      governorate: input.governorate,
    },
  });
}

export async function listUnavailableAreaRequestsService(
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;
  const [total, items] = await prisma.$transaction([
    prisma.unavailableAreaRequest.count({ where: data.where }),
    prisma.unavailableAreaRequest.findMany(data as any),
  ]);
  return {
    total,
    totalPages: Math.ceil(total / take),
    items,
  };
}

type GroupByResult<T extends string> = {
  _count: { id: number };
} & Record<T, string | null>;

// 🔒 Type-safe formatter
function formatGroup<T extends string>(data: GroupByResult<T>[], key: T) {
  return data.map((item) => ({
    name: item[key] ?? "Unknown",
    count: item._count.id,
  }));
}

export async function getUnavailableAreaRequestStatsService() {
  const [byArea, byGovernorate, byType, byGovArea] = await Promise.all([
    prisma.unavailableAreaRequest.groupBy({
      by: ["area"],
      _count: { id: true },
      orderBy: { _count: { id: "desc" } },
      take: 20,
    }),

    prisma.unavailableAreaRequest.groupBy({
      by: ["governorate"],
      _count: { id: true },
      orderBy: { _count: { id: "desc" } },
    }),

    prisma.unavailableAreaRequest.groupBy({
      by: ["request_type"],
      _count: { id: true },
    }),

    // 🔥 group by BOTH governorate + area
    prisma.unavailableAreaRequest.groupBy({
      by: ["governorate", "area"],
      _count: { id: true },
      orderBy: { _count: { id: "desc" } },
    }),
  ]);

  return {
    byArea: formatGroup(byArea, "area"),
    byGovernorate: formatGroup(byGovernorate, "governorate"),
    byType: formatGroup(byType, "request_type"),
    topAreasPerGovernorate: byGovArea.reduce(
      (acc, item) => {
        const gov = item.governorate ?? "Unknown";

        if (!acc[gov]) acc[gov] = [];

        acc[gov].push({
          name: item.area ?? "Unknown",
          count: item._count.id,
        });

        return acc;
      },
      {} as Record<string, { name: string; count: number }[]>,
    ),
  };
}

export async function deleteUnavailableAreaRequestService(id: number) {
  const exists = await prisma.unavailableAreaRequest.findUnique({
    where: { id },
    select: { id: true },
  });
  if (!exists) {
    throw new HttpError(404, "unavailable-area-request:errors.not_found");
  }

  await prisma.unavailableAreaRequest.delete({ where: { id } });
}
