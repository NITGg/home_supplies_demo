export interface StatisticsData {
  totalOrders: number;
  statusCounts: {
    PENDING: number;
    IN_PROGRESS: number;
    DELIVERED: number;
    CANCELLED: number;
    SEARCHING_FAILED: number;
    EXPIRED: number;
  };
  paymentCounts: {
    CASH: number;
    WALLET: number;
    UNKNOWN: number;
  };
  adjustmentCounts: {
    NONE: number;
    PENDING: number;
    ACCEPTED: number;
    REJECTED: number;
    UNKNOWN: number;
  };
  totalBudget: number;
  totalPayable: number;
  totalFees: number;
  totalPlatformFees: number;
  totalCourierFees: number;
  proposalStatusCounts: {
    ACCEPTED: number;
    REJECTED: number;
    PENDING: number;
    UNKNOWN: number;
  };
  totalProposals: number;
  totalCouriers: number;
  assignedCouriers: number;
  freeCouriers: number;
  approvedCouriers: number;
  notApprovedCouriers: number;
  totalCustomers: number;
  totalSellers: number;
  pickupAreas: {
    name: string;
    count: number;
    areaId?: number;
    governorateId?: number;
    isUnknown?: boolean;
  }[];
  deliveryAreas: {
    name: string;
    count: number;
    areaId?: number;
    governorateId?: number;
    isUnknown?: boolean;
  }[];
  ordersWithProposals: number;
  ordersWithoutProposals: number;
  cancelledReasonCounts: Record<string, number>;
}
