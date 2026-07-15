import { getSocketIOServer } from "./socketio.server";

export class OrderSocketioService {
  // ======================= offer:new =======================
  static emitOfferNew(orderId: number): void {
    getSocketIOServer().to(`order:${orderId}`).emit("offer:new", { orderId });
  }

  // ======================= order:price_report =======================
  static emitPriceReport(orderId: number, newPrice: number): void {
    getSocketIOServer()
      .to(`order:${orderId}`)
      .emit("order:price_report", { orderId, newPrice });
  }

  // ======================= order:cancelledUnavailable =======================
  static emitOrderCancelledUnavailable(orderId: number): void {
    getSocketIOServer()
      .to(`order:${orderId}`)
      .emit("order:cancelledUnavailable", { orderId });
  }

  // ======================= order:cancelledOther =======================
  static emitOrderCancelledOther(orderId: number): void {
    getSocketIOServer()
      .to(`order:${orderId}`)
      .emit("order:cancelledOther", { orderId });
  }

  // ======================= order:assingnedOrderAccepted =======================
  static emitAssignedOrderAccepted(orderId: number): void {
    getSocketIOServer().emit("order:assingnedOrderAccepted", { orderId });
  }

  // ======================= order:assingnedOrderRejected =======================
  static emitAssignedOrderRejected(orderId: number): void {
    getSocketIOServer().emit("order:assingnedOrderRejected", { orderId });
  }

  // ======================= order:collected =======================
  static emitOrderCollected(
    orderId: number,
    courierId: number,
    userId: number,
  ): void {
    getSocketIOServer()
      .to(`order:${orderId}`)
      .emit("order:collected", { orderId, courierId, userId });
  }

  static emitCourierLocationUpdate({
    courierId,
    orderId,
    lat,
    lng,
    customerId,
    timestamp,
  }: {
    courierId: number;
    orderId: number;
    lat: number;
    lng: number;
    customerId: number;
    timestamp: string;
  }) {
    // dashboard
    getSocketIOServer()
      .to(`order:${orderId}`)
      .emit("courier:location_updated", {
        courierId,
        orderId,
        lat,
        lng,
        timestamp,
      });

    // customer
    getSocketIOServer().to(`order:${orderId}`).emit("order:courier_location", {
      courierId,
      orderId,
      lat,
      lng,
      timestamp,
    });
  }
}
