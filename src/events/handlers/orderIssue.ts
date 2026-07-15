import getAdminUsers from "@/lib/getAdminUsers";
import { notifyUsers } from "@/services/notification.service";
import { AppEvents } from "@/types/events";

type Payload = AppEvents["order.issue.created"];

export default async function onOrderIssueCreated(payload: Payload) {
  const { orderId, reason } = payload;
  const admins = await getAdminUsers();

  if (admins.length > 0) {
    // Map the reason to specific translation keys
    const reasonKey = reason.toLowerCase(); // e.g., "late_pickup"
    
    await notifyUsers({
      users: admins,
      content: {
        // Fallback to a generic key if a specific one isn't found
        titleKey: `orders:messages.order_issue.${reasonKey}.title`,
        bodyKey: `orders:messages.order_issue.${reasonKey}.body`,
      },
      data: {
        orderId,
        issueType: reason,
        page: `/admin/orders/${orderId}`,
        type: "ORDER_ISSUE_ADMIN",
      },
    });
  }
}
