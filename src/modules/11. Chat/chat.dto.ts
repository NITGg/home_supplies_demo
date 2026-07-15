import z from "zod";
import {
  createChatSchema,
  createChatGroupSchema,
  addParticipantSchema,
  getChatSchema,
  sendMessageSchema,
} from "./chat.validation";

export type createChatDTO = z.infer<typeof createChatSchema>;
export type createChatGroupDTO = z.infer<typeof createChatGroupSchema>;
export type addParticipantDTO = z.infer<typeof addParticipantSchema>;
export type getChatDTO = z.infer<typeof getChatSchema>;
export type sendMessageDTO = z.infer<typeof sendMessageSchema>;
