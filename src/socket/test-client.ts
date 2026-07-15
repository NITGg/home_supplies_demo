/**
 * 🧪 Socket.IO test client — LOCAL
 * Run: npx tsx src/socket/test-client.ts
 *
 * 1. Login locally:  POST http://localhost:3100/api/v1/auth/login
 * 2. Paste the access token below
 * 3. Run immediately (token expires in ~2min)
 */
import { io } from "socket.io-client";

// ⚠️ REPLACE with a fresh token (admin OR courier) from LOCAL login
const TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjUyLCJ1c2VyUGhvbmUiOiIrMjAxMTQ1ODYyMTMxIiwiaWF0IjoxNzc0Njk1Mzc0LCJleHAiOjE3NzQ2OTU0OTQsImp0aSI6IjMxMTc5MiJ9.HIxe-SHKrnhlETnOqa8ZL4FvCJUlFMyGbOWEEKSLt0w";

const socket = io("http://localhost:3100", {
  transports: ["websocket"],
  auth: { token: TOKEN },
});

// ======================= CONNECTION =======================

socket.on("connect", () => {
  console.log(`✅ Connected: ${socket.id}`);

  // Query all online users
  socket.emit("users:get_online_users", (response: { users: number[] }) => {
    console.log("📋 Online users:", response.users);
  });

  // Query specific user status
  socket.emit(
    "user:get_status",
    { userId: 1 },
    (response: { userId: number; online: boolean }) => {
      console.log("🔍 User 1 status:", response);
    },
  );
});

socket.on("connected", (data) => {
  console.log("✅ Server acknowledged:", data);
});

// ======================= STATUS EVENTS =======================

socket.on("user:online", (data: { userId: number }) => {
  console.log(`🟢 User ${data.userId} came online`);
});

socket.on("user:offline", (data: { userId: number }) => {
  console.log(`🔴 User ${data.userId} went offline`);
});

// ======================= AUTH EVENTS =======================

socket.on("auth:expired", (data) => {
  console.log("⏰ Token expired:", data);
  socket.disconnect();
  process.exit(0);
});

// ======================= ERRORS =======================

socket.on("connect_error", (err) => {
  console.error(`❌ Connection error: ${err.message}`);
});

socket.on("disconnect", (reason) => {
  console.log(`🔌 Disconnected: ${reason}`);
});
