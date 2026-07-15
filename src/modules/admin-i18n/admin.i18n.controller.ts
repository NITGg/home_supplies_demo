import { Router, Request, Response } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { validation } from "@/middlewares/validation.middleware";
import {
  i18nAppParamSchema,
  i18nNamespaceParamSchema,
  updateI18nNamespaceSchema,
} from "./admin.i18n.validation";
import {
  listApps,
  listNamespaces,
  getNamespaceContent,
  updateNamespaceContent,
} from "./admin.i18n.service";

const router = Router();

router.get(
  "/apps",
  requireAuth,
  requireRole("Admin"),
  (req: Request, res: Response) => {
    return res.json({
      message: req.t("admin-i18n:messages.ok"),
      data: { apps: listApps() },
    });
  },
);

router.get(
  "/:app/namespaces",
  requireAuth,
  requireRole("Admin"),
  validation(i18nAppParamSchema),
  (req: Request, res: Response) => {
    const { app } = res.locals.validatedData;
    return res.json({
      message: req.t("admin-i18n:messages.ok"),
      data: { namespaces: listNamespaces(app) },
    });
  },
);

router.get(
  "/:app/:namespace",
  requireAuth,
  requireRole("Admin"),
  validation(i18nNamespaceParamSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const { app, namespace } = res.locals.validatedData;
    const data = await getNamespaceContent(app, namespace);
    return res.json({ message: req.t("admin-i18n:messages.ok"), data });
  }),
);

router.put(
  "/:app/:namespace",
  requireAuth,
  requireRole("Admin"),
  validation(updateI18nNamespaceSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const data = await updateNamespaceContent(res.locals.validatedData);
    return res.json({ message: req.t("admin-i18n:messages.updated"), data });
  }),
);

export default router;
