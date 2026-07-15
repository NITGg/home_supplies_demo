import z from "zod";
import { updateSettingsSchema } from "./notification.validation";

export type UpdateSettingsDTO = z.infer<typeof updateSettingsSchema>;
