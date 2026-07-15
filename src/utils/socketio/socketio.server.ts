import { Server, Socket } from "socket.io";
import { Server as HttpServer } from "node:http";
import { decodeToken } from "../decodeToken";
import logger from "../../config/logger.config";
import { registerChatEvents } from "./chat.events";

// ======================= socketIOServer =======================
let ioServer: Server | null = null;
export let connectedSockets = new Map<number, string[]>();
export interface AuthSocket extends Socket {
  userId?: number;
}

const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

export const socketIOServer = (httpServer: HttpServer) => {
  ioServer = new Server(httpServer, {
    cors: {
      origin: allowedOrigins.length > 0
        ? (origin, callback) => {
            if (!origin || allowedOrigins.includes(origin)) callback(null, true);
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
    disconnect(socket);
    getOnlineUsers(socket);
    getUserStatus(socket);
    registerChatEvents(socket);
  });

  logger.info("[socketIOServer] initialized");
};

// ======================= getSocketIOServer =======================
export const getSocketIOServer = (): Server => {
  if (!ioServer)
    throw new Error(
      "SocketIOServer not initialized — call socketIOServer first",
    );
  return ioServer;
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
    next();
  } catch (err) {
    next(err as Error);
  }
}

// ======================= connect =======================
function connect(socket: AuthSocket) {
  const userId = socket.userId as number; // Get socket data

  const userSockets = connectedSockets.get(userId) || []; // Get existing socket ids for this user
  userSockets.push(socket.id); // Add new socket id
  connectedSockets.set(userId, userSockets); // Update socket ids for this user

  // Broadcast online status only on first connection
  if (userSockets.length === 1) {
    socket.broadcast.emit("user:online", { userId });
    logger.info(`[socketIOClient] User ${userId} is now ONLINE`);
  }

  logger.info(
    `[socketIOClient] connected: ${socket.id} (userId: ${userId}) — active sockets: ${userSockets.length}`,
  );
}

// ======================= disconnect =======================
function disconnect(socket: AuthSocket) {
  socket.on("disconnect", () => {
    const userId = socket.userId as number; // Get socket data

    const userSockets = connectedSockets.get(userId) || []; // Get existing socket ids for this user
    const newUserSockets = userSockets.filter((id) => id !== socket.id); // Remove current socket id
    // Update socket ids for this user
    if (newUserSockets.length > 0) {
      // User still has other active connections — keep them online
      connectedSockets.set(userId, newUserSockets);
    } else {
      // Last socket closed — user is fully offline
      connectedSockets.delete(userId);
      getSocketIOServer().emit("user:offline", { userId });
      logger.info(`[socketIOClient] User ${userId} is now OFFLINE`);
    }

    logger.info(
      `[socketIOClient] Client disconnected: ${socket.id} (userId: ${userId}) — newUserSockets: ${newUserSockets.length}`,
    );
  });
}

// ======================= getOnlineUsers =======================
function getOnlineUsers(socket: AuthSocket) {
  socket.on("users:get_online_users", (callback: Function) => {
    if (typeof callback !== "function") return;
    callback({ users: Array.from(connectedSockets.keys()) });
  });
}

// ======================= getUserStatus =======================
function getUserStatus(socket: AuthSocket) {
  socket.on(
    "user:get_user_status",
    (data: { userId: number }, callback: Function) => {
      if (typeof callback !== "function") return;

      if (!data?.userId) {
        return callback({ error: "userId is required" });
      }

      const sockets = connectedSockets.get(data.userId);
      callback({
        userId: data.userId,
        online: !!sockets && sockets.length > 0,
      });
    },
  );
}
