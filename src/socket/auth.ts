import type { Server, Socket } from "socket.io";
import { rooms } from "./rooms";
import {
  trackConnection,
  trackDisconnection,
  registerStatusEvents,
} from "./status";
import { verifyAccessToken } from "@/lib/jwt";
import { prisma } from "@/config/prisma";
import { registerCourierHandlers } from "./courierHandlers";
import { registerAdminHandlers } from "./adminHandlers";

type SocketAuth = {
  userId: number;
  courierId?: number;
  role: string;
  exp: number;
};

function getToken(socket: Socket): string | null {
  const fromAuth = socket.handshake.auth?.token;
  if (typeof fromAuth === "string" && fromAuth.length > 0) return fromAuth;

  const header = socket.handshake.headers?.authorization;
  if (typeof header === "string") {
    const m = header.match(/^Bearer\s+(.+)$/i);
    if (m?.[1]) return m[1];
  }
  return null;
}

export function registerSocketAuth(io: Server) {
  io.use(async (socket, next) => {
    try {
      const token = getToken(socket);
      if (!token) return next(new Error("unauthorized1"));

      console.log("token:", token);

      const payload = verifyAccessToken(token);
      console.log({
        ...payload,
        iat: new Date((payload?.iat || 1) * 1000),
        exp: new Date((payload?.exp || 1) * 1000),
      });
      const userId =
        typeof payload?.userId === "number" ? payload.userId : null;
      const exp = typeof payload?.exp === "number" ? payload.exp : null;

      if (!userId || !exp) {
        return next(new Error("unauthorized2"));
      }

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          is_active: true,
          deleted_at: true,
          role: { select: { name: true } },
          courier: {
            select: {
              id: true,
              deleted_at: true,
              is_approved: true,
            },
          },
        },
      });

      if (!user || user.deleted_at) {
        return next(new Error("unauthorized3"));
      }

      if (!user.is_active) {
        return next(new Error("account_disabled"));
      }

      // Courier-specific validation (only if user has a courier record)
      let courierId: number | undefined;
      if (user.courier && !user.courier.deleted_at) {
        if (!user.courier.is_approved) {
          return next(new Error("courier_not_approved"));
        }
        courierId = user.courier.id;
      }

      socket.data.auth = {
        userId: user.id,
        courierId,
        role: user.role.name,
        exp,
      } satisfies SocketAuth;

      return next();
    } catch (err: any) {
      if (
        err?.name === "TokenExpiredError" ||
        err?.code === "ERR_JWT_EXPIRED"
      ) {
        return next(new Error("token_expired"));
      }

      return next(new Error("unauthorized4"));
    }
  });

  io.on("connection", async (socket) => {
    const auth = socket.data.auth as SocketAuth | undefined;
    if (!auth) {
      socket.disconnect(true);
      return;
    }

    const msUntilExpiry = auth.exp * 1000 - Date.now();

    if (msUntilExpiry <= 0) {
      socket.emit("auth:expired", { code: "TOKEN_EXPIRED" });
      socket.disconnect(true);
      return;
    }

    const expiryTimer = setTimeout(() => {
      socket.emit("auth:expired", { code: "TOKEN_EXPIRED" });
      socket.disconnect(true);
    }, msUntilExpiry);

    socket.on("disconnect", () => {
      clearTimeout(expiryTimer);
      console.log("!!! DISCONNECT DETECTED FOR USER:", auth.userId);
      trackDisconnection(socket);
    });

    // ── Courier rooms ─────────────────────────────────────────────
    let areaIds: number[] = [];
    if (auth.courierId) {
      socket.join(rooms.courier(auth.courierId));

      const selectedAreas = await prisma.courierSelectedArea.findMany({
        where: { courier_id: auth.courierId, deleted_at: null },
        select: { area_id: true },
      });

      for (const row of selectedAreas) {
        socket.join(rooms.area(row.area_id));
      }

      areaIds = selectedAreas.map((x) => x.area_id);
      console.log("COURIER rooms", [...socket.rooms]);
    }

    if (auth.role === "Customer") {
      socket.join(rooms.customer(auth.userId));
      console.log(`CUSTOMER joined room: ${rooms.customer(auth.userId)}`);
    }

    // ── Admin room ────────────────────────────────────────────────
    if (auth.role === "Admin") {
      console.log("admin joined", [...socket.rooms]);
      socket.join(rooms.dashboard());
    }

    // Register handlers
    registerCourierHandlers(io, socket);
    registerAdminHandlers(io, socket);

    // Track online status & register status query events
    trackConnection(socket);
    registerStatusEvents(socket);

    socket.emit("connected", {
      ok: true,
      userId: auth.userId,
      courierId: auth.courierId,
      role: auth.role,
      expiresAt: new Date(auth.exp * 1000).toISOString(),
      areaIds,
    });
  });
}
