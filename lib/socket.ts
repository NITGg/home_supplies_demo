import { io, Socket } from "socket.io-client";

type SocketConfig = {
  baseUrl: string;
  path: string;
};

/**
 * Retrieve the auth token from localStorage.
 * The codebase stores the token under two different keys depending on
 * the auth flow: "token" (lib/auth.ts login) and "auth_token" (AuthContext).
 * We check both so the socket works regardless of which flow was used.
 */
const getAuthToken = (): string | null => {
  const t1 = localStorage.getItem("token");
  const t2 = localStorage.getItem("auth_token");
  const token = t1 || t2 || null;
  console.log(
    "[Socket] getAuthToken:",
    token
      ? `found (${t1 ? '"token"' : '"auth_token"'}, ${token.slice(0, 20)}...)`
      : "NONE",
  );
  return token;
};

const buildSocketConfig = (socketUrl?: string): SocketConfig | null => {
  if (!socketUrl) {
    console.warn("[Socket] buildSocketConfig: socketUrl is empty/undefined");
    return null;
  }
  if (typeof window === "undefined") {
    console.warn("[Socket] buildSocketConfig: SSR environment, skipping");
    return null;
  }
  try {
    const resolved = new URL(socketUrl, window.location.origin);
    const config = { baseUrl: resolved.origin, path: resolved.pathname };
    console.log("[Socket] buildSocketConfig:", config);
    return config;
  } catch (err) {
    console.error("[Socket] buildSocketConfig: URL parse error:", err);
    return null;
  }
};

// ── Admin socket (admin_apis) ─────────────────────────────────────────────────
let adminSocket: Socket | null = null;

export const getAdminSocket = (): Socket | null => {
  if (typeof window === "undefined") return null;

  const envUrl = process.env.NEXT_PUBLIC_SOCKET_ADMIN_URL;
  console.log(
    "[Socket] getAdminSocket: NEXT_PUBLIC_SOCKET_ADMIN_URL =",
    envUrl,
  );

  const config = buildSocketConfig(envUrl);
  if (!config) {
    console.warn("[Socket] getAdminSocket: no config, returning null");
    return null;
  }

  if (adminSocket) {
    console.log(
      "[Socket] getAdminSocket: reusing existing socket, connected =",
      adminSocket.connected,
    );
    return adminSocket;
  }

  const token = getAuthToken();
  if (!token) {
    console.warn("[Socket] getAdminSocket: no token in localStorage");
    return null;
  }

  console.log(
    "[Socket] getAdminSocket: creating new connection to",
    config.baseUrl,
    "path:",
    config.path,
  );
  adminSocket = io(config.baseUrl, {
    path: config.path,
    transports: ["websocket"],
    auth: { token }, // admin_apis expects { token }
  });
  console.log("adminSocket2", adminSocket);

  adminSocket.on("connect", () => {
    console.log("🟢 [Socket] Admin socket CONNECTED, id:", adminSocket?.id);
  });
  adminSocket.on("connect_error", (err) => {
    console.error("🔴 [Socket] Admin socket CONNECT_ERROR:", err.message);
  });
  adminSocket.on("disconnect", (reason) => {
    console.warn("🟡 [Socket] Admin socket DISCONNECTED:", reason);
  });

  return adminSocket;
};

// ── Courier socket (courier_apis) ─────────────────────────────────────────────
let courierSocket: Socket | null = null;

/**
 * Returns the exchanged courier token from localStorage (cached by getCourierToken()).
 * Falls back to the admin token so the socket can at least attempt a connection.
 */
const getCourierAuthToken = (): string | null => {
  // Prefer the exchanged courier token (set by lib/auth.ts getCourierToken())
  const courierToken = localStorage.getItem("courierToken");
  if (courierToken) return courierToken;
  // Fallback to admin token (will likely be rejected, but logs a clearer error)
  return getAuthToken();
};

export const getCourierSocket = (): Socket | null => {
  if (typeof window === "undefined") return null;

  const envUrl = process.env.NEXT_PUBLIC_SOCKET_COURIER_URL;
  console.log(
    "[Socket] getCourierSocket: NEXT_PUBLIC_SOCKET_COURIER_URL =",
    envUrl,
  );

  const config = buildSocketConfig(envUrl);
  if (!config) {
    console.warn("[Socket] getCourierSocket: no config, returning null");
    return null;
  }

  if (courierSocket) {
    console.log(
      "[Socket] getCourierSocket: reusing existing socket, connected =",
      courierSocket.connected,
    );
    return courierSocket;
  }

  const token = getCourierAuthToken();
  if (!token) {
    console.warn("[Socket] getCourierSocket: no token in localStorage");
    return null;
  }

  console.log(
    "[Socket] getCourierSocket: creating new connection to",
    config.baseUrl,
    "path:",
    config.path,
  );
  const bearerPrefix = process.env.NEXT_PUBLIC_COURIER_BEARER_PREFIX ?? "Bearer";
  courierSocket = io(config.baseUrl, {
    path: config.path,
    transports: ["websocket"],
    auth: { accessToken: `${bearerPrefix} ${token}` },
  });

  courierSocket.on("connect", () => {
    console.log("🟢 [Socket] Courier socket CONNECTED, id:", courierSocket?.id);
  });
  courierSocket.on("connect_error", (err) => {
    console.error("🔴 [Socket] Courier socket CONNECT_ERROR:", err.message);
  });
  courierSocket.on("disconnect", (reason) => {
    console.warn("🟡 [Socket] Courier socket DISCONNECTED:", reason);
  });

  return courierSocket;
};

// ── Cleanup (call on logout) ──────────────────────────────────────────────────
export const disconnectSockets = () => {
  console.log("[Socket] disconnectSockets called");
  adminSocket?.disconnect();
  courierSocket?.disconnect();
  adminSocket = null;
  courierSocket = null;
};
