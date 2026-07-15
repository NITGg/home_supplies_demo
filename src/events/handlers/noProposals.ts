import getAdminUsers from "@/lib/getAdminUsers";
import { notifyUsers } from "@/services/notification.service";
import { AppEvents } from "@/types/events";

type NoProposalOrderEvent = AppEvents["order.no_proposals"];

const onNoProposalOrders = async (payload: NoProposalOrderEvent) => {
  const { orderId } = payload;

  // 1. Fetch Admin Users and Customer details
  const adminUsers = await getAdminUsers();

  // 2. Notify Admins (Standard technical message)
  if (adminUsers.length > 0) {
    await notifyUsers({
      users: adminUsers,
      content: {
        titleKey: "orders:messages.no_proposals.title",
        bodyKey: "orders:messages.no_proposals.body",
        bodyParams: { title: orderId },
      },
      data: { orderId, page: `/orders/${orderId}`, type: "no_proposals_admin" },
    });
  }
};

export default onNoProposalOrders;
