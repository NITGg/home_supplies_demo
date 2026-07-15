import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { OrderGroupService } from "./order.group.service";

const router = Router();
const orderGroupService = new OrderGroupService();

router.get("/test", auth, orderGroupService.test);

export default router;
