import { z } from "zod";

export const cartItemCreateSchema = z.object({
  sp_id: z.coerce.number().int().positive(),
  quantity: z.coerce.number().int().positive(),
});

export const cartItemUpdateSchema = z.object({
  sp_id: z.coerce.number().int().positive(),
  action: z.enum(["increment", "decrement", "set"]),
  quantity: z.coerce.number().int().min(0),
});

export type CartItemCreateInput = z.infer<typeof cartItemCreateSchema>;
export type CartItemUpdateInput = z.infer<typeof cartItemUpdateSchema>;
