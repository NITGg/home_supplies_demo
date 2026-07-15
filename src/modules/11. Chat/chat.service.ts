import { NextFunction, Request, Response } from "express";
import { responseHandler } from "../../core/handlers/response.handler";
import { prisma } from "../../DB/lib/prisma";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { AppError } from "../../core/errors/app.error";
import { buildPaginationResponse } from "../../utils/filter";
import {
  createChatGroupDTO,
  addParticipantDTO,
  sendMessageDTO,
} from "./chat.dto";
import FeatureApi from "../../utils/featureApi";
import { getSocketIOServer } from "../../utils/socketio/socketio.server";
import { notifyOtherParticipants } from "../../utils/socketio/chat.events";
import logger from "../../config/logger.config";
import { uploadSingleFile } from "../../utils/cloudinary/cloudinary.service";
import fs from "fs/promises";
import {
  deleteChatNotifications,
  deleteMessageNotifications,
} from "../../utils/firebase-notification/notification.service";

export class ChatService {
  constructor() {}

  // ============================ getMyChats ============================
  getMyChats = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter({}, { allowKeys: ["is_group", "name"] }) //{}{allowKeys:[]}
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword(["reason_ar", "reason_en"]) // ?keyword=xxx&items=reason_ar,reason_en
      .fields().data; // ?fields=id,reason_ar,reason_en

    // Enforce: only return chats where current user is an active participant
    const userChatFilter = {
      participants: {
        some: {
          user_id: user.id,
          left_at: null,
        },
      },
    };

    const whereClause = queryOptions.where
      ? { AND: [queryOptions.where, userChatFilter] }
      : userChatFilter;

    const [totalMyChats, myChats] = await prisma.$transaction([
      prisma.chat.count({ where: whereClause }),
      prisma.chat.findMany({
        ...queryOptions,
        where: whereClause,
      } as any),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        totalMyChats,
        totalPages: Math.ceil(totalMyChats / (queryOptions.take ?? 10)),
        myChats,
      },
    });
  };

  // ============================ getChat ============================
  getChat = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const chatId = Number(req.params.chatId);

    // step: verify user is a participant
    const participant = await prisma.chatParticipant.findFirst({
      where: { chat_id: chatId, user_id: user.id, left_at: null },
    });
    if (!participant)
      throw new AppError(HttpStatusCode.FORBIDDEN, res.__("errors."));

    // step: mark all unread messages (not from current user) as read
    await prisma.chatMessage.updateMany({
      where: {
        chat_id: chatId,
        is_read: false,
        deleted_at: null,
        sender_id: { not: user.id },
      },
      data: { is_read: true, read_at: new Date() },
    });

    // step: fetch paginated messages — always include sender so the dashboard
    // can render message bubbles without a second query.
    const limit = Math.min(Number(req.query.limit) || 10, 100);
    const skip = Number(req.query.skip) || 0;
    const where = { chat_id: chatId, deleted_at: null };

    const [totalMessages, messages] = await prisma.$transaction([
      prisma.chatMessage.count({ where }),
      prisma.chatMessage.findMany({
        where,
        orderBy: { created_at: "desc" },
        take: limit,
        skip,
        select: {
          id: true,
          chat_id: true,
          content: true,
          type: true,
          is_read: true,
          read_at: true,
          created_at: true,
          sender: {
            select: {
              id: true,
              full_name: true,
              personal_photo: true,
              phone: true,
            },
          },
        },
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        totalMessages,
        totalPages: Math.ceil(totalMessages / limit),
        messages,
      },
    });
  };

  // ============================ createChat ============================
  // ============================ createChat ============================
  createChat = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    const { userId, order_id: orderId } = res.locals.validatedData;

    const otherUserId = Number(userId);
    const order_id = orderId ? Number(orderId) : undefined;

    if (otherUserId === user.id)
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.cannot_create_chat_with_self") ||
          "You cannot create a chat with yourself",
      );

    const targetUser = await prisma.user.findFirst({
      where: { id: otherUserId, deleted_at: null },
      select: { id: true, full_name: true, personal_photo: true },
    });

    if (!targetUser)
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );

    // if order chat -> return existing order chat
    if (order_id) {
      const existingOrderChat = await prisma.chat.findUnique({
        where: {
          order_id,
        },
        select: {
          id: true,
          name: true,
          is_group: true,
          created_at: true,
        },
      });

      if (existingOrderChat) {
        return responseHandler({
          res,
          status: 200,
          message: res.__("messages.done"),
          data: {
            chat: existingOrderChat,
            created: false,
          },
        });
      }
    }

    // private chat check
    const existingChat = await prisma.chat.findFirst({
      where: {
        is_group: false,
        deleted_at: null,

        ...(order_id && {
          order_id,
        }),

        participants: {
          some: {
            user_id: user.id,
            left_at: null,
          },
        },

        AND: [
          {
            participants: {
              some: {
                user_id: otherUserId,
                left_at: null,
              },
            },
          },
        ],
      },
      select: {
        id: true,
        name: true,
        is_group: true,
        created_at: true,
      },
    });

    if (existingChat)
      return responseHandler({
        res,
        status: 200,
        message: res.__("messages.done"),
        data: {
          chat: existingChat,
          created: false,
        },
      });

    const chat = await prisma.chat.create({
      data: {
        is_group: false,
        created_by: user.id,

        ...(order_id && {
          order_id,
        }),

        participants: {
          createMany: {
            data: [{ user_id: user.id }, { user_id: otherUserId }],
          },
        },
      },

      select: {
        id: true,
        name: true,
        is_group: true,
        created_at: true,

        participants: {
          select: {
            user: {
              select: {
                id: true,
                full_name: true,
                personal_photo: true,
              },
            },
          },
        },
      },
    });

    return responseHandler({
      res,
      status: HttpStatusCode.CREATED,
      message: res.__("messages.done"),

      data: {
        chat: {
          ...chat,
          participants: chat.participants.map((p) => p.user),
        },
        created: true,
      },
    });
  };

  // ============================ createChatGroup ============================
  createChatGroup = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { name, userIds }: createChatGroupDTO = req.body;

    // step: ensure creator is not duplicated in the list
    const uniqueUserIds = [...new Set([...userIds, user.id])];

    // step: verify all provided users exist
    const usersCount = await prisma.user.count({
      where: { id: { in: uniqueUserIds }, deleted_at: null },
    });
    if (usersCount !== uniqueUserIds.length)
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.user_not_found"),
      );

    // step: create group chat
    const chat = await prisma.chat.create({
      data: {
        name,
        is_group: true,
        created_by: user.id,
        participants: {
          createMany: {
            data: uniqueUserIds.map((uid) => ({ user_id: uid })),
          },
        },
      },
      select: {
        id: true,
        name: true,
        is_group: true,
        created_at: true,
        participants: {
          select: {
            user: {
              select: { id: true, full_name: true, personal_photo: true },
            },
          },
        },
      },
    });

    return responseHandler({
      res,
      status: HttpStatusCode.CREATED,
      message: res.__("messages.done"),
      data: {
        chat: { ...chat, participants: chat.participants.map((p) => p.user) },
      },
    });
  };

  // ============================ addGroupParticipant ============================
  addGroupParticipant = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const chatId = Number(req.params.chatId);
    const { userId }: addParticipantDTO = req.body;

    // step: verify chat is a group and user is a member
    const chat = await prisma.chat.findFirst({
      where: { id: chatId, is_group: true, deleted_at: null },
    });
    if (!chat)
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.chat_not_found") || "Group chat not found",
      );

    const isParticipant = await prisma.chatParticipant.findFirst({
      where: { chat_id: chatId, user_id: user.id, left_at: null },
    });
    if (!isParticipant)
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_chat_member") || "You are not a member of this chat",
      );

    // step: check if target user is already in the chat
    const existing = await prisma.chatParticipant.findFirst({
      where: { chat_id: chatId, user_id: userId },
    });

    if (existing && !existing.left_at)
      throw new AppError(
        HttpStatusCode.CONFLICT,
        res.__("errors.already_participant") || "User is already a participant",
      );

    // step: re-join if previously left, or create new
    if (existing) {
      await prisma.chatParticipant.update({
        where: { id: existing.id },
        data: { left_at: null, joined_at: new Date() },
      });
    } else {
      await prisma.chatParticipant.create({
        data: { chat_id: chatId, user_id: userId },
      });
    }

    return responseHandler({
      res,
      status: 200,
      message: res.__("messages.done"),
      data: {},
    });
  };

  // ============================ sendMessage ============================
  sendMessage = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const chatId = Number(req.params.chatId);
    let { content, type }: sendMessageDTO = req.body;

    if (!content && !req.file) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.message_content_required") ||
          "Message content or file is required",
      );
    }

    if (req.file) {
      const uploadResult = await uploadSingleFile({
        fileLocation: req.file.path, // .path or .buffer
        storagePathOnCloudinary: "users/Courier",
      });
      content = uploadResult.secure_url;

      // delete the temporary file generated by multer
      await fs.unlink(req.file.path).catch((err) => {
        logger.warn(`Failed to delete temp file: ${err.message}`);
      });
      if (!type) {
        // simple heuristic to guess the type if not provided
        if (
          req.file.mimetype.startsWith("audio/") ||
          req.file.mimetype.startsWith("video/")
        ) {
          type = "VOICE";
        } else if (req.file.mimetype.startsWith("image/")) {
          type = "IMAGE";
        } else {
          type = "FILE";
        }
      }
    }

    // step: find the participant record
    const participant = await prisma.chatParticipant.findFirst({
      where: { chat_id: chatId, user_id: user.id, left_at: null },
    });
    if (!participant)
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_chat_member"),
      );

    // get chat order id
    const chat = await prisma.chat.findUnique({
      where: {
        id: chatId,
      },
      select: {
        order_id: true,
      },
    });

    // step: create the message
    const message = await prisma.chatMessage.create({
      data: {
        chat_id: chatId,
        sender_id: user.id,
        content: content as string,
        type: type ?? "TEXT",
      },
      select: {
        id: true,
        chat_id: true,
        content: true,
        type: true,
        is_read: true,
        created_at: true,
        sender: {
          select: {
            id: true,
            full_name: true,
            personal_photo: true,
          },
        },
      },
    });

    // step: update chat's updated_at so it appears at top of list
    await prisma.chat.update({
      where: { id: chatId },
      data: { updated_at: new Date() },
    });

    // step: emit socket event
    const room = `chat:${chatId}`;
    getSocketIOServer().to(room).emit("chat:new_message", { message });

    // step: notify other participants via push notification (fire-and-forget)
    notifyOtherParticipants(
      chatId,
      user.id,
      message,
      chat?.order_id ?? null,
    ).catch((err) =>
      logger.error(`[chat:send_message] notification error: ${err}`),
    );

    return responseHandler({
      res,
      status: HttpStatusCode.CREATED,
      message: res.__("messages.done"),
      data: { message },
    });
  };

  // ============================ leaveChat ============================
  leaveChat = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const chatId = Number(req.params.chatId);

    // step: find the participant record
    const participant = await prisma.chatParticipant.findFirst({
      where: { chat_id: chatId, user_id: user.id, left_at: null },
    });
    if (!participant)
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_chat_member") || "You are not a member of this chat",
      );

    // step: mark as left
    await prisma.chatParticipant.update({
      where: { id: participant.id },
      data: { left_at: new Date() },
    });

    return responseHandler({
      res,
      status: 200,
      message: res.__("messages.done"),
      data: {},
    });
  };

  // ============================ deleteMessage ============================
  deleteMessage = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const messageId = Number(req.params.messageId);

    // step: find message and verify ownership
    const message = await prisma.chatMessage.findFirst({
      where: { id: messageId, deleted_at: null },
    });
    if (!message)
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.message_not_found") || "Message not found",
      );

    if (message.sender_id !== user.id)
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.cannot_delete_other_message") ||
          "You can only delete your own messages",
      );

    // step: soft delete
    await prisma.chatMessage.update({
      where: { id: messageId },
      data: { deleted_at: new Date() },
    });

    // step: remove the stored "new message" notification for this message
    await deleteMessageNotifications(messageId).catch((err) =>
      logger.error(`[chat:delete_message] notification cleanup error: ${err}`),
    );

    return responseHandler({
      res,
      status: 200,
      message: res.__("messages.done"),
      data: {},
    });
  };

  // ============================ getMyChatsRich (admin dashboard) ============================
  getMyChatsRich = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const limit = Math.min(Number(req.query.limit) || 50, 100);
    const skip = Number(req.query.skip) || 0;

    const whereClause = {
      deleted_at: null,
      participants: { some: { user_id: user.id, left_at: null } },
    };

    const [total, chats] = await prisma.$transaction([
      prisma.chat.count({ where: whereClause }),
      prisma.chat.findMany({
        where: whereClause,
        orderBy: { updated_at: "desc" },
        take: limit,
        skip,
        select: {
          id: true,
          name: true,
          is_group: true,
          updated_at: true,
          participants: {
            where: { left_at: null },
            select: {
              user: {
                select: {
                  id: true,
                  full_name: true,
                  personal_photo: true,
                  phone: true,
                },
              },
            },
          },
          messages: {
            where: { deleted_at: null },
            orderBy: { created_at: "desc" },
            take: 1,
            select: {
              id: true,
              content: true,
              type: true,
              is_read: true,
              created_at: true,
              sender: { select: { id: true, full_name: true } },
            },
          },
          _count: {
            select: {
              messages: {
                where: {
                  deleted_at: null,
                  is_read: false,
                  sender_id: { not: user.id },
                },
              },
            },
          },
        },
      }),
    ]);

    const enriched = chats.map((c) => ({
      id: c.id,
      name: c.name,
      is_group: c.is_group,
      updated_at: c.updated_at,
      participants: c.participants.map((p) => p.user),
      otherParticipants: c.participants
        .map((p) => p.user)
        .filter((u) => u.id !== user.id),
      lastMessage: c.messages[0] ?? null,
      unreadCount: c._count.messages,
    }));

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        total,
        totalPages: Math.ceil(total / limit),
        chats: enriched,
      },
    });
  };

  // ============================ searchUsers (admin dashboard) ============================
  searchUsersForChat = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const q = String(req.query.q ?? "").trim();
    if (!q) {
      return responseHandler({
        res,
        message: res.__("messages.done"),
        data: { users: [] },
      });
    }

    const users = await prisma.user.findMany({
      where: {
        deleted_at: null,
        is_active: true,
        OR: [{ full_name: { contains: q } }, { phone: { contains: q } }],
      },
      select: { id: true, full_name: true, personal_photo: true, phone: true },
      take: 20,
    });

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: { users },
    });
  };
}

// ============================ deleteOrderChatOnCompletion ============================
// System-triggered cleanup: when an order is delivered/cancelled, remove its
// chat (messages + participants cascade) and any stored "new message"
// notifications for that chat. No-op if the order has no chat.
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

  const io = getSocketIOServer();
  for (const participant of chat.participants) {
    io.to(`customer:${participant.user_id}`).emit("chat:deleted", {
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
