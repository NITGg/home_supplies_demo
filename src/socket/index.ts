import http from "node:http";
import { Server } from "socket.io";
import { registerSocketAuth } from "./auth";
import env from "@/config/env";

let _io: Server;

export const getIo = (): Server => {
  if (!_io) {
    throw new Error(
      "Socket.io has not been initialized. Please call initSocket(server) first.",
    );
  }
  return _io;
};

const allowedOrigins = new Set(
  env.ALLOWED_ORIGINS.split(",").map((o) => o.trim()),
);

export function initSocket(server: http.Server) {
  _io = new Server(server, {
    path: env.PROD ? "/admin_apis/socket.io" : undefined,
    cors: {
      origin: env.PROD
        ? (origin, callback) => {
            if (!origin || allowedOrigins.has(origin)) callback(null, true);
            else callback(new Error(`CORS: origin ${origin} not allowed`));
          }
        : true,
      methods: ["GET", "POST"],
    },
    pingTimeout: 5000, // Server waits 5s for response
    pingInterval: 10000, // Server checks every 10s
  });

  // ✅ auth middleware + connection handler
  registerSocketAuth(_io);

  return _io;
}
