import z from "zod";
import {
  appendCourierToOfficeSchema,
  courierOfficeSchema,
  createCourierOfficeSchema,
  updateCourierOfficeSchema,
} from "./admin.courier.office.validation";

export type createCourierOfficeDTO = z.infer<typeof createCourierOfficeSchema>;
export type updateCourierOfficeDTO = z.infer<typeof updateCourierOfficeSchema>;
export type courierOfficeDTO = z.infer<typeof courierOfficeSchema>;
export type appendCourierToOfficeDTO = z.infer<
  typeof appendCourierToOfficeSchema
>;
