import type { Request, Response } from "express";
import { HttpError } from "@/lib/httpError";
import FeatureApi from "@/lib/featureApi";
import {
  createRoleSchema,
  updateRoleSchema,
  roleIdParamSchema,
  deleteRolesSchema,
  deleteRoleSchema,
} from "./roles.schema";
import {
  createRoleService,
  listRolesService,
  getRoleByIdService,
  updateRoleService,
  deleteRolesService,
  deleteRoleService,
} from "./roles.service";

export async function createRole(req: Request, res: Response) {
  const parsed = createRoleSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res.status(400).json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const role = await createRoleService(parsed.data);
  return res.status(201).json({ message: req.t("roles:messages.role_created"), role });
}

export async function listRoles(req: Request, res: Response) {
  const data = new FeatureApi(req)
    .filter()          // no forced deleted_at here
    .sort("name")      // default
    .limit(50)
    .skip(0)
    .includes()
    .fields().data;

  const result = await listRolesService(data);
  return res.status(200).json(result);
}

export async function getRole(req: Request, res: Response) {
  const params = roleIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "roles:errors.role_id_invalid");

  const role = await getRoleByIdService({ id: params.data.id });
  return res.status(200).json({ role });
}

export async function updateRole(req: Request, res: Response) {
  const params = roleIdParamSchema.safeParse(req.sanitized.params);
  if (!params.success) throw new HttpError(400, "roles:errors.role_id_invalid");

  const parsed = updateRoleSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res.status(400).json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const role = await updateRoleService({ id: params.data.id, data: parsed.data });
  return res.status(200).json({ message: req.t("roles:messages.role_updated"), role });
}

export async function deleteRoles(req: Request, res: Response) {
  const parsed = deleteRolesSchema.safeParse(req.sanitized.body);
  if (!parsed.success) {
    const key = parsed.error.issues[0]?.message ?? "errors.validation";
    return res.status(400).json({ message: req.t(key), field: parsed.error.issues[0].path[0] });
  }

  const result = await deleteRolesService(parsed.data);
  return res.status(200).json({ message: req.t("roles:messages.roles_deleted"), count: result.count });
}

export async function deleteRole(req: Request, res: Response) {
  const parsed = deleteRoleSchema.safeParse(req.sanitized.params);
  if (!parsed.success) throw new HttpError(400, "roles:errors.role_id_invalid");

  await deleteRoleService({ id: parsed.data.id });
  return res.status(200).json({ message: req.t("roles:messages.role_deleted") });
}
