import type { Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  listLogsService,
  getLogByIdService,
  deleteOldLogsService,
} from "./logs.service";
import { logIdParamSchema } from "./logs.schema";

export async function adminListLogs(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(50)
    .skip()
    .includes("user=id-full_name-email-phone")
    .keyword(
      ["path", "method", "ip", "user.full_name", "user.email", "user.phone"],
      "OR",
    )
    .fields().data;

  const result = await listLogsService(data);
  return res.json(result);
}

export async function adminGetLog(req: AuthedRequest, res: Response) {
  const { id } = logIdParamSchema.parse(req.params);
  const log = await getLogByIdService(id);
  return res.json({ log });
}

export async function adminDeleteOldLogs(req: AuthedRequest, res: Response) {
  const result = await deleteOldLogsService();
  return res.json({
    message: req.t?.("logs:messages.cleaned") ?? "Old logs deleted",
    count: result.count,
  });
}
