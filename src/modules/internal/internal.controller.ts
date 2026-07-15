import { Router, Request, Response } from "express";
import { connectedSockets } from "../../utils/socketio/socketio.server";

const router = Router();

// Internal-only endpoint — returns IDs of currently connected couriers.
// Used by the admin API to determine online status. No public auth needed
// since it's called server-to-server on localhost.
router.get("/online-users", (_req: Request, res: Response) => {
  const userIds = Array.from(connectedSockets.keys());
  res.json({ userIds });
});

export default router;
