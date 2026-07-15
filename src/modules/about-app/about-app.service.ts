import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type { UpsertAboutAppInput } from "./about-app.schema";

async function findLatestAboutApp() {
  return prisma.aboutApp.findUnique({
    where: {
      id: 1,
    },
  });
}

export async function getAboutAppService() {
  const aboutApp = await findLatestAboutApp();
  if (!aboutApp) throw new HttpError(404, "about-app:errors.not_found");
  return aboutApp;
}

export async function upsertAboutAppService(data: UpsertAboutAppInput) {
  if (!data || Object.keys(data).length === 0) {
    throw new HttpError(400, "about-app:errors.empty_payload");
  }

  const existing = await findLatestAboutApp();
  if (existing) {
    return prisma.aboutApp.update({
      where: { id: existing.id },
      data,
    });
  }

  return prisma.aboutApp.create({
    data: {
      id: 1,
      ...data,
    },
  });
}
