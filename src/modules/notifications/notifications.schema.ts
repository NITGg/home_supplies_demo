import { z } from "zod";

const recipientTypeEnum = z.enum(["all", "users", "role"]);
const roleEnum = z.enum(["admin", "customer", "courier"]);

const notificationDataSchema = z
  .record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()]))
  .optional();

const localizedTextSchema = z.object({
  en: z.string().min(1),
  ar: z.string().min(1),
});

const notificationContentSchema = z.union([
  z.object({
    titleKey: z.string().min(1),
    bodyKey: z.string().min(1),
    titleParams: z.record(z.string(), z.unknown()).optional(),
    bodyParams: z.record(z.string(), z.unknown()).optional(),
  }),
  z.object({
    title: localizedTextSchema,
    body: localizedTextSchema,
  }),
]);

export const sendNotificationSchema = z
  .object({
    recipientType: recipientTypeEnum,

    userIds: z.array(z.coerce.number().int().positive()).optional(),

    roles: z.array(roleEnum).min(1).optional(),

    content: notificationContentSchema,

    data: notificationDataSchema,
  })
  .superRefine((value, ctx) => {
    if (value.recipientType === "users") {
      if (!value.userIds || value.userIds.length === 0) {
        ctx.addIssue({
          code: "custom",
          path: ["userIds"],
          message: "notification:validation.user_ids_required",
        });
      }
    }

    if (value.recipientType === "role") {
      if (!value.roles || value.roles.length === 0) {
        ctx.addIssue({
          code: "custom",
          path: ["roles"],
          message: "notification:validation.roles_required",
        });
      }
    }
  });

export type SendNotificationInput = z.infer<typeof sendNotificationSchema>;
export type RecipientRole = z.infer<typeof roleEnum>;
export type RecipientType = z.infer<typeof recipientTypeEnum>;
