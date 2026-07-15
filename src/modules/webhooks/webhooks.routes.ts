import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { paymobWebhook, kashierWebhook, easykashWebhook } from "./webhooks.controller";

const router = Router();

// No auth — these are called by payment provider servers.
// Security is handled via HMAC/signature verification inside each handler.
router.post("/paymob",   asyncHandler(paymobWebhook));
router.post("/kashier",  asyncHandler(kashierWebhook));
router.get("/easykash",  asyncHandler(easykashWebhook));

export default router;
