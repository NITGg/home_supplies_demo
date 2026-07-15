import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type {
  CreateRoleInput,
  UpdateRoleInput,
  DeleteRolesInput,
  DeleteRoleInput,
} from "./roles.schema";
import type FeatureApi from "@/lib/featureApi";

export async function createRoleService(input: CreateRoleInput) {
  // unique(name) exists
  const exists = await prisma.userRole.findUnique({
    where: { name: input.name },
    select: { id: true },
  });
  if (exists) throw new HttpError(409, "roles:errors.name_exists");

  return prisma.userRole.create({
    data: input,
  });
}

export async function listRolesService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  const [totalRoles, roles] = await prisma.$transaction([
    prisma.userRole.count({ where: data.where }),
    prisma.userRole.findMany(data as any),
  ]);

  return {
    totalRoles,
    totalPages: Math.ceil(totalRoles / take),
    roles,
  };
}

export async function getRoleByIdService(input: { id: number }) {
  const role = await prisma.userRole.findUnique({ where: { id: input.id } });
  if (!role) throw new HttpError(404, "roles:errors.role_not_found");
  return role;
}

export async function updateRoleService(input: {
  id: number;
  data: UpdateRoleInput;
}) {
  const role = await prisma.userRole.findUnique({
    where: { id: input.id },
    select: { id: true, name: true },
  });
  if (!role) throw new HttpError(404, "roles:errors.role_not_found");

  // if name changed, check unique
  if (input.data.name && input.data.name !== role.name) {
    const exists = await prisma.userRole.findUnique({
      where: { name: input.data.name },
      select: { id: true },
    });
    if (exists) throw new HttpError(409, "roles:errors.name_exists");
  }

  return prisma.userRole.update({
    where: { id: input.id },
    data: {
      ...input.data,
      ...(input.data.description === undefined
        ? {}
        : { description: input.data.description }),
      ...(input.data.description_ar === undefined
        ? {}
        : { description_ar: input.data.description_ar }),
    },
  });
}

export async function deleteRolesService(input: DeleteRolesInput) {
  // NOTE: will fail if roles are referenced by users/badges
  const result = await prisma.userRole.deleteMany({
    where: { id: { in: input.ids } },
  });

  return { count: result.count };
}

export async function deleteRoleService(input: DeleteRoleInput) {
  const role = await prisma.userRole.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!role) throw new HttpError(404, "roles:errors.role_not_found");

  await prisma.userRole.delete({ where: { id: input.id } });
  return { ok: true as const };
}
