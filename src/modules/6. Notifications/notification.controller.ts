import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { validation } from "../../core/middlewares/validation.middleware";
import { NotificationService } from "./notification.service";
import { updateSettingsSchema } from "./notification.validation";

const router = Router();
const notificationService = new NotificationService();

router.get("/get-settings", auth, notificationService.getSettings);
router.patch("/update-settings",auth,validation(updateSettingsSchema),notificationService.updateSettings);

export default router;
