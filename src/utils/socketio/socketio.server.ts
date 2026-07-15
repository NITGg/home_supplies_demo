import { Server, Socket } from "socket.io";
import { Server as HttpServer } from "node:http";
import { decodeToken } from "../decodeToken";
import logger from "../../config/logger.config";
import { registerChatEvents } from "./chat.events";
import { prisma } from "../../DB/lib/prisma";
import { env } from "../../config/env";

export interface AuthSocket extends Socket {
  userId?: number;
  user?: {
    id: number;
    role: string;
    courierId: number | undefined;
  };
}
export let connectedSockets = new Map<number, string[]>();

// ======================= socketIOServer =======================
let ioServer: Server | null = null;

const allowedOrigins = (env.ALLOWED_ORIGINS ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

export const socketIOServer = (httpServer: HttpServer) => {
  ioServer = new Server(httpServer, {
    cors: {
      origin:
        allowedOrigins.length > 0
          ? (origin, callback) => {
              if (!origin || allowedOrigins.includes(origin))
                callback(null, true);
              else callback(new Error(`CORS: origin ${origin} not allowed`));
            }
          : true,
    },
  });

  ioServer.use(async (socket: AuthSocket, next) => {
    authMiddleware(socket, next);
  });

  ioServer.on("connection", (socket: AuthSocket) => {
    connect(socket);
    joinOrder(socket);
    leaveOrder(socket);
    getUserStatus(socket);
    getOnlineUsers(socket);
    locationUpdate(socket);
    disconnect(socket);
    registerChatEvents(socket);
  });

  logger.info("[Socket.IO] Server initialized");
};

// ======================= getSocketIOServer =======================
export const getSocketIOServer = (): Server => {
  if (!ioServer)
    throw new Error(
      "SocketIOServer not initialized — call socketIOServer first",
    );
  return ioServer;
};

// ======================= isUserOnline =======================
export const isUserOnline = (userId: number): boolean => {
  const sockets = connectedSockets.get(userId);
  return !!sockets && sockets.length > 0;
};

// ======================= authMiddleware =======================
async function authMiddleware(socket: AuthSocket, next: any) {
  try {
    const token =
      socket.handshake.auth?.accessToken ||
      socket.handshake.headers?.authorization;
    if (!token) return next(new Error("Authentication required"));

    const { user } = await decodeToken({ authorization: token });
    socket.userId = user.id;
    socket.user = {
      id: user.id,
      role: user.role.name,
      courierId: user.courier?.id,
    };
    next();
  } catch (err) {
    next(err as Error);
  }
}

// ======================= connect =======================
function connect(socket: AuthSocket) {
  const userId = socket.userId as number;
  const wasOffline = !isUserOnline(userId);

  const userSockets = connectedSockets.get(userId) || [];
  userSockets.push(socket.id);
  connectedSockets.set(userId, userSockets);

  // Auto-join personal room
  socket.join(`customer:${userId}`);

  if (socket.user?.role === "Admin") {
    socket.join("dashboard");
    logger.info(`[Socket.IO] Admin ${userId} joined dashboard room`);
  }

  // Broadcast online status only on first connection (avoid duplicate events
  // when the same user opens a second tab / reconnects quickly)
  if (wasOffline) {
    socket.broadcast.emit("user:online", { userId });
    logger.info(`[Socket.IO] User ${userId} is now ONLINE`);
  }

  logger.info(
    `[Socket.IO] Client connected: ${socket.id} (userId: ${userId}) — active sockets: ${userSockets.length}`,
  );
}

// ======================= joinOrder =======================
function joinOrder(socket: AuthSocket) {
  socket.on("join:order", (data: { orderId: number }) => {
    if (data?.orderId) {
      socket.join(`order:${data.orderId}`);
      logger.info(`[Socket.IO] ${socket.id} joined room order:${data.orderId}`);
    }
  });
}

// ======================= leaveOrder =======================
function leaveOrder(socket: AuthSocket) {
  socket.on("leave:order", (data: { orderId: number }) => {
    if (data?.orderId) {
      socket.leave(`order:${data.orderId}`);
      logger.info(`[Socket.IO] ${socket.id} left room order:${data.orderId}`);
    }
  });
}

// ======================= getUserStatus =======================
// Allows any connected client to query whether a specific user is online
function getUserStatus(socket: AuthSocket) {
  socket.on(
    "user:get_status",
    (data: { userId: number }, callback: Function) => {
      if (typeof callback !== "function") return;

      if (!data?.userId) {
        return callback({ error: "userId is required" });
      }

      callback({ userId: data.userId, online: isUserOnline(data.userId) });
    },
  );
}

// ======================= getOnlineUsers =======================
// Returns all currently online user IDs to the requesting client
function getOnlineUsers(socket: AuthSocket) {
  socket.on("users:get_online_users", (callback: Function) => {
    if (typeof callback !== "function") return;
    callback({ users: Array.from(connectedSockets.keys()) });
  });
}

// ======================= locationUpdate =======================
// Allows courier apps to report background location without an active order.
// Updates lat/lng + last_location_update so the admin map stays current.
function locationUpdate(socket: AuthSocket) {
  socket.on("location:update", async (data: { lat: number; lng: number }) => {
    if (typeof data?.lat !== "number" || typeof data?.lng !== "number") return;
    const userId = socket.userId as number;
    try {
      await prisma.courier.updateMany({
        where: { user_id: userId, deleted_at: null },
        data: {
          lat: data.lat,
          lng: data.lng,
          last_location_update: new Date(),
        },
      });
      logger.debug(
        `[Socket.IO] location:update userId=${userId} lat=${data.lat} lng=${data.lng}`,
      );
    } catch {
      // not a courier (e.g. admin user connecting) — ignore silently
    }
  });
}

// ======================= disconnect =======================
function disconnect(socket: AuthSocket) {
  socket.on("disconnect", () => {
    const userId = socket.userId as number;
    const userSockets = connectedSockets.get(userId) || [];
    const newUserSockets = userSockets.filter((id) => id !== socket.id);

    if (newUserSockets.length > 0) {
      // User still has other active connections — keep them online
      connectedSockets.set(userId, newUserSockets);
    } else {
      // Last socket closed — user is fully offline
      connectedSockets.delete(userId);
      getSocketIOServer().emit("user:offline", { userId });
      logger.info(`[Socket.IO] User ${userId} is now OFFLINE`);
    }

    logger.info(
      `[Socket.IO] Client disconnected: ${socket.id} (userId: ${userId}) — newUserSockets: ${newUserSockets.length}`,
    );
  });
}
