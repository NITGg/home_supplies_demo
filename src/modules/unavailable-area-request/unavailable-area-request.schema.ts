import { z } from "zod";

export const createUnavailableAreaRequestSchema = z.object({
  request_type: z.enum(["PICKUP", "DELIVERY"], {
    message: "unavailable-area-request:errors.invalid_request_type",
  }),
  lat: z.coerce.number().optional(),
  long: z.coerce.number().optional(),
  address: z
    .string()
    .max(255)
    .optional()
    .transform((val) => val?.toLocaleLowerCase() || null),
  area: z
    .string()
    .max(255, {
      message: "unavailable-area-request:errors.area_too_long",
    })
    .transform((val) => val.toLocaleLowerCase()),
  governorate: z
    .string()
    .max(255, {
      message: "unavailable-area-request:errors.governorate_too_long",
    })
    .transform((val) => val?.toLocaleLowerCase()),
});

export const unavailableAreaRequestIdParamSchema = z.object({
  id: z.coerce.number({
    message: "unavailable-area-request:errors.invalid_id",
  }),
});

export type CreateUnavailableAreaRequestInput = z.infer<
  typeof createUnavailableAreaRequestSchema
>;
