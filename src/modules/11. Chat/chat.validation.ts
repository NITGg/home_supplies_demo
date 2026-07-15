import z from "zod";

// ============================ createChatSchema ============================
export const createChatSchema = z.object({
  userId: z.string().regex(/^\d+$/, "userId must be a number"),
  order_id: z.coerce.number().int().positive().optional(),
});

// ============================ createChatGroupSchema ============================
export const createChatGroupSchema = z.object({
  name: z.string().min(1).max(100),
  userIds: z
    .array(z.number().int().positive())
    .min(1, "At least one participant is required"),
});

// ============================ addParticipantSchema ============================
export const addParticipantSchema = z.object({
  userId: z.number().int().positive(),
});

// ============================ getChatSchema ============================
export const getChatSchema = z.object({
  chatId: z.string().regex(/^\d+$/, "chatId must be a number"),
});

// ============================ sendMessageSchema ============================
export const sendMessageSchema = z.object({
  content: z.string().optional(),
  type: z.enum(["TEXT", "IMAGE", "FILE", "VOICE"]).optional(),
});
