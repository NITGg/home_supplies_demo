import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";
import { deleteChatNotifications } from "@/services/notification.service";

/**
 * deleteOrderChatService
 *
 * step: claude: "9- delete order user chat notifications" — deletes the chat
 * that is linked to an order, along with ALL of its messages and participants
 * (cascade is set on both ChatMessage and ChatParticipant → Chat). Also fires a
 * socket event to every participant so their UI can clear the chat view
 * immediately without polling.
 *
 * "Notifications linked with it" — since the platform uses FCM push notifications
 * (no persistent DB notification records), in-device notifications that have
 * already been delivered cannot be recalled programmatically. What we CAN do is:
 *   1. Hard-delete the Chat + cascaded messages/participants from the DB.
 *   2. Emit `chat:deleted` over socket so the mobile client dismisses the chat
 *      screen and removes local notification badges for that conversation.
 *
 * @param orderId  – the order whose chat should be removed
 * @param actorId  – the admin/user requesting the deletion (for authorization)
 * @param isAdmin  – admins can delete any order's chat; customers/couriers only their own
 */
export async function deleteOrderChatService(
  orderId: number,
  actorId: number,
  isAdmin: boolean,
) {
  // Find the chat linked to this order, including its participants so we can
  // emit the socket event to each of them after deletion.
  const chat = await prisma.chat.findUnique({
    where: { order_id: orderId },
    select: {
      id: true,
      order_id: true,
      participants: {
        select: {
          user_id: true,
        },
      },
    },
  });

  if (!chat) {
    throw new HttpError(404, "orders:errors.order_chat_not_found");
  }

  // Authorization: non-admins may only delete chats for orders they are part of
  if (!isAdmin) {
    const isMember = chat.participants.some((p) => p.user_id === actorId);
    if (!isMember) {
      throw new HttpError(403, "orders:errors.chat_delete_forbidden");
    }
  }

  // Hard-delete the Chat record. ChatMessage and ChatParticipant rows cascade.
  await prisma.chat.delete({ where: { id: chat.id } });

  // Notify every former participant via socket so their client clears the chat
  // view and dismisses any local notification badge for this conversation.
  const io = getIo();
  for (const participant of chat.participants) {
    // We emit on the customer room; for couriers/suppliers the socket room is
    // keyed by user_id via customer() — the mobile client listens on its own
    // user room regardless of role.
    io.to(rooms.customer(participant.user_id)).emit("chat:deleted", {
      chatId: chat.id,
      orderId,
    });
  }

  return {
    deletedChatId: chat.id,
    orderId,
    participantCount: chat.participants.length,
  };
}

/**
 * deleteOrderChatOnCompletion
 *
 * System-triggered cleanup: when an order is delivered/completed, remove its
 * chat (messages + participants cascade) and any stored "new message"
 * notifications for that chat. No-op if the order has no chat.
 *
 * @param orderId – the order whose chat should be removed
 */
export async function deleteOrderChatOnCompletion(orderId: number) {
  const chat = await prisma.chat.findUnique({
    where: { order_id: orderId },
    select: {
      id: true,
      participants: { select: { user_id: true } },
    },
  });

  if (!chat) return null;

  await prisma.chat.delete({ where: { id: chat.id } });
  await deleteChatNotifications(chat.id);

  const io = getIo();
  for (const participant of chat.participants) {
    io.to(rooms.customer(participant.user_id)).emit("chat:deleted", {
      chatId: chat.id,
      orderId,
    });
  }

  return {
    deletedChatId: chat.id,
    orderId,
    participantCount: chat.participants.length,
  };
}

/**
 * deleteOrderChatByIdService
 *
 * Alternative: delete a specific chat directly by chat_id when the caller already
 * knows the chat id (e.g., admin chat management UI).
 */
export async function deleteOrderChatByIdService(
  chatId: number,
  actorId: number,
  isAdmin: boolean,
) {
  const chat = await prisma.chat.findUnique({
    where: { id: chatId },
    select: {
      id: true,
      order_id: true,
      participants: { select: { user_id: true } },
    },
  });

  if (!chat) {
    throw new HttpError(404, "orders:errors.order_chat_not_found");
  }

  if (!isAdmin) {
    const isMember = chat.participants.some((p) => p.user_id === actorId);
    if (!isMember) {
      throw new HttpError(403, "orders:errors.chat_delete_forbidden");
    }
  }

  await prisma.chat.delete({ where: { id: chatId } });

  const io = getIo();
  for (const participant of chat.participants) {
    io.to(rooms.customer(participant.user_id)).emit("chat:deleted", {
      chatId,
      orderId: chat.order_id,
    });
  }

  return {
    deletedChatId: chatId,
    orderId: chat.order_id,
    participantCount: chat.participants.length,
  };
}
