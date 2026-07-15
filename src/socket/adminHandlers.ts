import { Server, Socket } from "socket.io";
import { rooms } from "./rooms";
import { z } from "zod";

// 1. Define the Schema for an array of numbers
const RequestLocationSchema = z.object({
  courierIds: z.array(z.number().int().positive()),
  // Ensures it's an array of positive integers
});

export function registerAdminHandlers(io: Server, socket: Socket) {
  socket.on("courier:request_location", (data) => {
    // Check Authentication & Role
    if (socket.data.auth?.role !== "Admin") {
      console.warn(`⚠️ Unauthorized location request by socket: ${socket.id}`);
      return;
    }

    // 2. Validate the incoming data
    const validation = RequestLocationSchema.safeParse(data);

    if (!validation.success) {
      console.error("❌ Invalid courierIds received:", validation.error.issues);
      return;
    }

    const { courierIds } = validation.data;
    console.log("courierIds", courierIds);

    // 3. Emit to each courier's room
    courierIds.forEach((courierId) => {
      // Logic: Send request to the specific room for that courier
      io.to(rooms.courier(courierId)).emit("courier:get_location", {
        requestedAt: new Date(),
      });
    });

    console.log(
      `📡 Admin requested location for ${courierIds.length} couriers.`,
    );
  });
}
