import { useEffect, useState } from "react";
import { getCourierSocket } from "@/lib/socket";
import { orderService } from "@/services/orderService";
import { CourierLocation } from "@/types/order";

export function useCourierTracking(orderId: number | null | undefined) {
  const [location, setLocation] = useState<CourierLocation | null>(null);
  const [isLoadingInitial, setIsLoadingInitial] = useState(false);
  const [orderCollectedAt, setOrderCollectedAt] = useState<string | null>(null);

  // ── 1. Fetch last known location on mount ────────────────────────────────
  useEffect(() => {
    if (!orderId) return;
    let mounted = true;

    const fetchInitial = async () => {
      try {
        setIsLoadingInitial(true);
        const data = await orderService.fetchCourierLocation(orderId);
        if (mounted && data) setLocation(data);
      } catch {
        // no location yet — socket will populate when courier moves
      } finally {
        if (mounted) setIsLoadingInitial(false);
      }
    };

    fetchInitial();
    return () => {
      mounted = false;
    };
  }, [orderId]);

  // ── 2. Join order room + listen for live updates ─────────────────────────
  useEffect(() => {
    if (!orderId) return;

    const socket = getCourierSocket();
    if (!socket) return;

    const joinRoom = () => socket.emit("join:order", { orderId });

    if (socket.connected) {
      joinRoom();
    } else {
      socket.once("connect", joinRoom);
    }

    // courier location update
    const onLocation = (data: CourierLocation) => {
      if (data.orderId === orderId) setLocation(data);
    };

    // order collected — courier picked up the package
    const onCollected = (data: { orderId: number; courierId: number }) => {
      if (data.orderId === orderId) {
        setOrderCollectedAt(new Date().toISOString());
      }
    };

    socket.on("order:courier_location", onLocation);
    socket.on("order:collected", onCollected);

    return () => {
      socket.off("order:courier_location", onLocation);
      socket.off("order:collected", onCollected);
      socket.off("connect", joinRoom);
      socket.emit("leave:order", { orderId });
    };
  }, [orderId]);

  return { location, isLoadingInitial, orderCollectedAt, setOrderCollectedAt };
}
