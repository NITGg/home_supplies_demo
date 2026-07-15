import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { validation } from "../../core/middlewares/validation.middleware";
import { ChatService } from "./chat.service";
import {
  getChatSchema,
  createChatSchema,
  createChatGroupSchema,
  addParticipantSchema,
  sendMessageSchema,
} from "./chat.validation";
import upload, { cleanupTempUploads } from "../../core/middlewares/upload";

const router = Router();
const chatService = new ChatService();

router.get("/get-my-chats", auth, chatService.getMyChats);
router.get("/get-my-chats-rich", auth, chatService.getMyChatsRich);
router.get("/search-users", auth, chatService.searchUsersForChat);
router.get(
  "/get-chat/:chatId",
  auth,
  validation(getChatSchema),
  chatService.getChat,
);
router.post(
  "/create-chat/:userId",
  auth,
  validation(createChatSchema),
  chatService.createChat,
);
router.post(
  "/create-chat-group",
  auth,
  validation(createChatGroupSchema),
  chatService.createChatGroup,
);
router.post(
  "/add-participant/:chatId",
  auth,
  validation(addParticipantSchema),
  chatService.addGroupParticipant,
);
router.post(
  "/send-message/:chatId",
  auth,
  upload.single("file"),
  cleanupTempUploads,
  validation(sendMessageSchema),
  chatService.sendMessage,
);
router.delete("/leave-chat/:chatId", auth, chatService.leaveChat);
router.delete("/delete-message/:messageId", auth, chatService.deleteMessage);

export default router;
