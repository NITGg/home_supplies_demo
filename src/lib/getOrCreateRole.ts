import { prisma } from "../config/prisma";

export default async function getOrCreateRole(
  roleName: string,
  roleNameAr: string,
) {
  return prisma.userRole.upsert({
    where: { name: roleName },
    update: {},
    create: { name: roleName, name_ar: roleNameAr },
    select: { id: true, name: true },
  });
}
