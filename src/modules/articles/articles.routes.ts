import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import upload from "@/middlewares/upload";

import {
  adminCreateArticle,
  adminDeleteArticle,
  adminGetArticle,
  adminListArticles,
  adminUpdateArticle,
  deleteArticles,
  getPublicArticleBySlug,
  listPublicArticles,
} from "./articles.controller";

export const articlesRouter = Router();
export const adminArticlesRouter = Router();

// Public
articlesRouter.get("/", asyncHandler(listPublicArticles));
articlesRouter.get("/:slug", asyncHandler(getPublicArticleBySlug));

// Admin
adminArticlesRouter.use(requireAuth);
adminArticlesRouter.use(requireRole("Admin"));

adminArticlesRouter.get("/", asyncHandler(adminListArticles));
adminArticlesRouter.get("/:id", asyncHandler(adminGetArticle));

adminArticlesRouter.post(
  "/",
  upload.single("cover_image"),
  asyncHandler(adminCreateArticle),
);
adminArticlesRouter.put(
  "/:id",
  upload.single("cover_image"),
  asyncHandler(adminUpdateArticle),
);

adminArticlesRouter.delete("/", asyncHandler(deleteArticles));
adminArticlesRouter.delete("/:id", asyncHandler(adminDeleteArticle));
