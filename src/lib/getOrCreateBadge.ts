import { prisma } from "../config/prisma";
import { HttpError } from "./httpError";

export default async function getOrCreateBadge(input: {
  role_id: number;
  name: string;
  name_ar: string;
  image?: string;
  description?: string | null;
  description_ar?: string | null;
  min_count: number;
  max_count: number;
  ratio: number; // percent (0..100)
}) {
  return prisma.userBadge.upsert({
    where: {
      role_id_name: {
        role_id: input.role_id,
        name: input.name,
      },
    },
    update: {
      name_ar: input.name_ar,
      image: input.image ?? "default_badge.png",
      description: input.description ?? null,
      description_ar: input.description_ar ?? null,
      min_count: input.min_count,
      max_count: input.max_count,
      ratio: input.ratio,
    },
    create: {
      role_id: input.role_id,
      name: input.name,
      name_ar: input.name_ar,
      image: input.image ?? "default_badge.png",
      description: input.description ?? null,
      description_ar: input.description_ar ?? null,
      min_count: input.min_count,
      max_count: input.max_count,
      ratio: input.ratio,
    },
    select: { id: true, name: true, ratio: true, role_id: true },
  });
}

export async function getBadgeId(role_id: number, name: string) {
  const badge = await prisma.userBadge.findUnique({
    where: { role_id_name: { role_id, name } },
    select: { id: true },
  });
  // if (!badge) throw new HttpError(404, "badge:not_found");
  if (!badge) return null;
  return badge.id;
}
