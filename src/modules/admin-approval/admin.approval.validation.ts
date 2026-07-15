import { TransactionStatus, TransactionType } from "@prisma/client";
import z from "zod";

// ========== allCouriersSchema ==========
export const allCouriersSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    id: z.string().regex(/^\d+$/).transform(Number).optional(),
    user_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    vehicle_type: z.string().optional(),
    vehicle_plate: z.string().optional(),
    is_approved: z
      .enum(["true", "false"])
      .transform((val) => val === "true")
      .optional(),
    created_atFrom: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    created_atTo: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    updated_atFrom: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    updated_atTo: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    deleted_atFrom: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    deleted_atTo: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    // from model User
    user_full_name: z.string().optional(),
    user_phone: z.string().optional(),
    user_email: z.string().optional(),
    user_is_active: z
      .enum(["true", "false"])
      .transform((val) => val === "true")
      .optional(),
    // from model Governorate
    governorate_id: z.string().regex(/^\d+$/).transform(Number).optional(),
    // from model Areas
    area_id: z.string().regex(/^\d+$/).transform(Number).optional(),
  })
  .strict();

// ========== courierDetailsSchema ==========
export const courierDetailsSchema = z
  .object({
    courierId: z.string().regex(/^\d+$/).transform(Number),
  })
  .strict();

// ========== approveCourierSchema ==========
export const approveCourierSchema = z
  .object({
    courierId: z.string().regex(/^\d+$/).transform(Number),
  })
  .strict();

// ========== rejectCourierSchema ==========
export const rejectCourierSchema = z
  .object({
    courierId: z.string().regex(/^\d+$/).transform(Number),
    reject_reason: z
      .string({ message: "Reject reason is required" })
      .min(1, "Reject reason is required")
      .max(255, "Reject reason cannot exceed 255 characters"),
  })
  .strict();

// ========== listProfileUpdateRequestsSchema ==========
export const listProfileUpdateRequestsSchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    status: z.enum(["PENDING", "APPROVED", "REJECTED"]).optional(),
    user_id: z.string().regex(/^\d+$/).transform(Number).optional(),
  })
  .strict();

// ========== profileUpdateRequestIdSchema ==========
export const profileUpdateRequestIdSchema = z
  .object({
    requestId: z.string().regex(/^\d+$/).transform(Number),
  })
  .strict();

// ========== rejectProfileUpdateRequestSchema ==========
export const rejectProfileUpdateRequestSchema = z
  .object({
    requestId: z.string().regex(/^\d+$/).transform(Number),
    reject_reason: z
      .string({ message: "Reject reason is required" })
      .min(1, "Reject reason is required")
      .max(255, "Reject reason cannot exceed 255 characters"),
  })
  .strict();
