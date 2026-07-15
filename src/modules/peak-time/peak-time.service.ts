import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type { CreatePeakTimeInput, UpdatePeakTimeInput } from "./peak-time.schema";

export async function listPeakTimesService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalPeakTimes, peakTimes] = await prisma.$transaction([
    prisma.peakTime.count({ where: data.where as any }),
    prisma.peakTime.findMany(data as any),
  ]);

  return {
    totalPeakTimes,
    totalPages: Math.ceil(totalPeakTimes / take),
    peakTimes,
  };
}

export async function getPeakTimeByIdService(input: { id: number }) {
  const peakTime = await prisma.peakTime.findUnique({
    where: { id: input.id },
  });
  if (!peakTime) throw new HttpError(404, "peak-time:errors.not_found");
  return peakTime;
}

export async function createPeakTimeService(data: CreatePeakTimeInput) {
  return prisma.peakTime.create({ data });
}

export async function updatePeakTimeService(input: {
  id: number;
  data: UpdatePeakTimeInput;
}) {
  const exists = await prisma.peakTime.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "peak-time:errors.not_found");

  return prisma.peakTime.update({
    where: { id: input.id },
    data: input.data,
  });
}

export async function deletePeakTimeService(input: { id: number }) {
  const exists = await prisma.peakTime.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "peak-time:errors.not_found");

  await prisma.peakTime.delete({ where: { id: input.id } });
  return { ok: true as const };
}
