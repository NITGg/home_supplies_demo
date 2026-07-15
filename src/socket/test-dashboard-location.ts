import { io } from "socket.io-client";

// npx tsx ./socket/test-dashboard-location.ts

const token =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjEsImlhdCI6MTc3NTM5MTk0MCwiZXhwIjoxNzc1OTk2NzQwfQ.Uzrykbezbl5ZYfG1Kwbrev_P9HfdxiQ3OUbQR4BtCk8";

// const socket = io("http://127.0.0.1:3100", {
const socket = io("https://tawreedat.nitg-eg.com", {
  path: "/admin_apis/socket.io",
  transports: ["websocket"],
  auth: { token },
});

socket.on("connect", () => {
  console.log("🧑‍💻 Dashboard connected:", socket.id);

  // 🔥 Trigger request after connect
  setTimeout(() => {
    console.log("📡 Requesting courier location...");

    socket.emit("courier:request_location", {
      courierIds: [81], // 👈 change to your courierId
    });
  }, 2000);
});

socket.on("connected", (msg) => {
  console.log("✅ server connected event:", msg);
});

// 🔥 Listen for courier responses
socket.on("courier:location_updated", (data) => {
  console.log("📍 Courier location received:", data);
});

socket.on("connect_error", (err) => {
  console.log("❌ connect_error:", err.message);
});
