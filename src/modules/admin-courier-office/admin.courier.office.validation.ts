import z from "zod";

export const CommissionTypeEnum = z.enum(["FIXED_PER_ORDER", "PERCENTAGE"]);

export const createCourierOfficeSchema = z.object({
  name: z.string(),
  address: z.string().optional(),
  phone: z.string().optional(),
  email: z.string().optional(),
  website: z.string().optional(),
  description: z.string().optional(),
  commission_type: CommissionTypeEnum.optional(), // Defaults to FIXED_PER_ORDER in DB, but good to accept
  commission_value: z.coerce.number().min(0).optional(), // Value for the commission (e.g., "2.00" for 2 EGP or "10.00" for 10%)
});

export const updateCourierOfficeSchema = z.object({
  name: z.string().optional(),
  address: z.string().optional(),
  phone: z.string().optional(),
  email: z.string().optional(),
  website: z.string().optional(),
  description: z.string().optional(),
  commission_type: CommissionTypeEnum.optional(),
  commission_value: z.coerce.number().min(0).optional(),
});

export const courierOfficeSchema = z.object({
  courierOfficeId: z.string(),
});

export const appendCourierToOfficeSchema = z.object({
  courierId: z.string(),
  courierOfficeId: z.string().optional(),
});
