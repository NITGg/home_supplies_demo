import type { Socket } from "socket.io";
import { getIo } from "./index";
import { logger } from "@/config/logger";

// ======================= connectedSockets =======================
// Map<userId, socketId[]> — supports multi-tab / multi-device
const connectedSockets = new Map<number, string[]>();

// ======================= isUserOnline =======================
export function isUserOnline(userId: number): boolean {
  const sockets = connectedSockets.get(userId);
  return !!sockets && sockets.length > 0;
}

// ======================= trackConnection =======================
export function trackConnection(socket: Socket) {
  const userId = socket.data.auth?.userId as number;
  const wasOffline = !isUserOnline(userId);

  const userSockets = connectedSockets.get(userId) || [];
  userSockets.push(socket.id);
  connectedSockets.set(userId, userSockets);

  // Broadcast online status only on first connection
  // (avoid duplicate events when the same user opens a second tab / reconnects quickly)
  if (wasOffline) {
    socket.broadcast.emit("user:online", { userId });
    logger.info(`[Socket.IO] User ${userId} is now ONLINE`);
  }

  logger.info(
    `[Socket.IO] Client connected: ${socket.id} (userId: ${userId}) — active sockets: ${userSockets.length}`,
  );
}

// ======================= trackDisconnection =======================
export function trackDisconnection(socket: Socket) {
  const userId = socket.data.auth?.userId as number;
  const userSockets = connectedSockets.get(userId) || [];
  const remaining = userSockets.filter((id) => id !== socket.id);
console.log("user disconnect:",userSockets);

  if (remaining.length > 0) {
    // User still has other active connections — keep them online
    connectedSockets.set(userId, remaining);
  } else {
    // Last socket closed — user is fully offline
    connectedSockets.delete(userId);
    getIo().emit("user:offline", { userId });
    logger.info(`[Socket.IO] User ${userId} is now OFFLINE`);
  }

  logger.info(
    `[Socket.IO] Client disconnected: ${socket.id} (userId: ${userId}) — remaining sockets: ${remaining.length}`,
  );
}

// ======================= registerStatusEvents =======================
export function registerStatusEvents(socket: Socket) {
  // Allows any connected client to query whether a specific user is online
  socket.on(
    "user:get_status",
    (data: { userId: number }, callback: Function) => {
      if (typeof callback !== "function") return;

      if (!data?.userId) {
        return callback({ error: "userId is required" });
      }

      callback({
        userId: data.userId,
        online: isUserOnline(data.userId),
      });
    },
  );

  // Returns all currently online user IDs to the requesting client
  socket.on("users:get_online_users", (callback: Function) => {
    if (typeof callback !== "function") return;
    callback({ users: getOnlineUserIds() });
  });
}

// ======================= getOnlineUserIds =======================
export function getOnlineUserIds(): number[] {
  return Array.from(connectedSockets.keys());
}
