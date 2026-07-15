import { prisma } from "../../DB/lib/prisma";
import logger from "../../config/logger.config";
import { AuthSocket } from "./socketio.server";
import { notifyUsers } from "../firebase-notification/notification.service";

// ======================= registerChatEvents =======================
export function registerChatEvents(socket: AuthSocket) {
  const userId = socket.userId as number;

  joinChat(socket, userId);
  leaveChat(socket, userId);
  typing(socket, userId);
  stopTyping(socket, userId);
  readMessages(socket, userId);
}

// ======================= joinChat =======================
// Client emits: { chatId: number }
// Server joins socket to room "chat:{chatId}"
function joinChat(socket: AuthSocket, userId: number) {
  socket.on(
    "chat:join",
    async (data: { chatId: number }, callback?: Function) => {
      try {
        if (!data?.chatId) return callback?.({ error: "chatId is required" });

        const participant = await prisma.chatParticipant.findFirst({
          where: { chat_id: data.chatId, user_id: userId, left_at: null },
        });
        if (!participant)
          return callback?.({ error: "You are not a member of this chat" });

        const room = `chat:${data.chatId}`;
        socket.join(room);
        logger.info(`[chat:join] User ${userId} joined room ${room}`);
        callback?.({ success: true, room });
      } catch (err) {
        logger.error(`[chat:join] error: ${err}`);
        callback?.({ error: "Failed to join chat" });
      }
    },
  );
}

// ======================= leaveChat =======================
// Client emits: { chatId: number }
function leaveChat(socket: AuthSocket, userId: number) {
  socket.on("chat:leave", (data: { chatId: number }) => {
    if (!data?.chatId) return;
    const room = `chat:${data.chatId}`;
    socket.leave(room);
    logger.info(`[chat:leave] User ${userId} left room ${room}`);
  });
}

// ======================= typing =======================
// Client emits: { chatId: number }
// Server emits to room: chat:user_typing
function typing(socket: AuthSocket, userId: number) {
  socket.on("chat:typing", (data: { chatId: number }) => {
    if (!data?.chatId) return;
    const room = `chat:${data.chatId}`;
    socket.to(room).emit("chat:user_typing", { userId, chatId: data.chatId });
  });
}

// ======================= stopTyping =======================
// Client emits: { chatId: number }
// Server emits to room: chat:user_stopped_typing
function stopTyping(socket: AuthSocket, userId: number) {
  socket.on("chat:stop_typing", (data: { chatId: number }) => {
    if (!data?.chatId) return;
    const room = `chat:${data.chatId}`;
    socket
      .to(room)
      .emit("chat:user_stopped_typing", { userId, chatId: data.chatId });
  });
}

// ======================= readMessages =======================
// Client emits: { chatId: number }
// Marks all unread messages in the chat (not from current user) as read
// Server emits to room: chat:message_read
function readMessages(socket: AuthSocket, userId: number) {
  socket.on(
    "chat:read_messages",
    async (data: { chatId: number }, callback?: Function) => {
      try {
        if (!data?.chatId) return callback?.({ error: "chatId is required" });

        const now = new Date();

        await prisma.chatMessage.updateMany({
          where: {
            chat_id: data.chatId,
            is_read: false,
            deleted_at: null,
            sender_id: { not: userId },
          },
          data: { is_read: true, read_at: now },
        });

        const room = `chat:${data.chatId}`;
        socket.to(room).emit("chat:message_read", {
          chatId: data.chatId,
          readBy: userId,
          read_at: now,
        });

        logger.debug("[chat:message_read] socket is emmitted");

        callback?.({ success: true });
      } catch (err) {
        logger.error(`[chat:read_messages] error: ${err}`);
        callback?.({ error: "Failed to mark messages as read" });
      }
    },
  );
}

// ======================= notifyOtherParticipants =======================
// Sends FCM push notifications to all active chat participants except the sender
export async function notifyOtherParticipants(
  chatId: number,
  senderId: number,
  message: {
    id: number;
    content: string;
    type: string;
    sender: { full_name: string };
  },
  orderId?: number | null,
) {
  // fetch other active participants with their FCM tokens and language
  const participants = await prisma.chatParticipant.findMany({
    where: {
      chat_id: chatId,
      user_id: { not: senderId },
      left_at: null,
    },
    select: {
      user: {
        select: {
          id: true,
          lang: true,
          fcm_token: true,
        },
      },
    },
  });

  const users = participants.map((p) => p.user);
  if (users.length === 0) return;

  // build notification body preview
  let bodyPreview: { en: string; ar: string };
  switch (message.type) {
    case "IMAGE":
      bodyPreview = { en: "📷 Sent a photo", ar: "📷 أرسل صورة" };
      break;
    case "FILE":
      bodyPreview = { en: "📎 Sent a file", ar: "📎 أرسل ملف" };
      break;
    case "VOICE":
      bodyPreview = {
        en: "🎤 Sent a voice message",
        ar: "🎤 أرسل رسالة صوتية",
      };
      break;
    default:
      bodyPreview = {
        en:
          message.content.length > 100
            ? message.content.slice(0, 100) + "…"
            : message.content,
        ar:
          message.content.length > 100
            ? message.content.slice(0, 100) + "…"
            : message.content,
      };
  }

  await notifyUsers({
    users,
    content: {
      title: { en: message.sender.full_name, ar: message.sender.full_name },
      body: bodyPreview,
    },
    data: {
      page: "chat",
      navigate: "chat",
      chatId: String(chatId),
      messageId: String(message.id),
      type: "NEW_MESSAGE",
      ...(orderId && {
        orderId: String(orderId),
      }),
    },
  });

  logger.info(
    `[chat:notify] Notified ${users.length} participant(s) for message ${message.id} in chat ${chatId}`,
  );
}
