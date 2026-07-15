"use client";
import { useQuery } from "@tanstack/react-query";
import { useState, useCallback } from "react";
import ChatLayout, { Avatar, createOrGetChat } from "@/components/chat/ChatLayout";
import { fetchOrders, type Order } from "@/lib/orders";
import { MessageSquare, Phone, ClipboardList } from "lucide-react";
import { cn } from "@/lib/utils";

// ─── Contact card ─────────────────────────────────────────────────────────────

function ContactCard({
  name,
  phone,
  photo,
  label,
  labelColor,
  onChat,
}: {
  name: string;
  phone?: string;
  photo?: string | null;
  label: string;
  labelColor: string;
  onChat: () => void;
}) {
  return (
    <div className="flex items-center gap-2 px-3 py-2.5 hover:bg-gray-50 transition-colors rounded-lg">
      <Avatar user={{ full_name: name, personal_photo: photo }} size="sm" />
      <div className="flex-1 min-w-0">
        <p className="text-xs font-medium text-gray-800 truncate">{name}</p>
        <span className={cn("text-[10px] px-1.5 py-0.5 rounded font-medium", labelColor)}>
          {label}
        </span>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0">
        {phone && (
          <a
            href={`tel:${phone}`}
            onClick={(e) => e.stopPropagation()}
            className="p-1 text-green-600 hover:bg-green-50 rounded"
            title={`Call ${name}`}
          >
            <Phone size={12} />
          </a>
        )}
        <button
          onClick={onChat}
          className="p-1 text-indigo-600 hover:bg-indigo-50 rounded"
          title={`Chat with ${name}`}
        >
          <MessageSquare size={12} />
        </button>
      </div>
    </div>
  );
}

// ─── Right panel: pending support orders ─────────────────────────────────────

function SupportRightPanel() {
  const [opening, setOpening] = useState(false);

  const { data: pendingData } = useQuery({
    queryKey: ["support-pending-orders-panel"],
    queryFn: () =>
      fetchOrders({ status: "PENDING", limit: 20, includes: "customer" }),
    refetchInterval: 30_000,
    staleTime: 20_000,
  });

  const { data: progressData } = useQuery({
    queryKey: ["support-progress-orders-panel"],
    queryFn: () =>
      fetchOrders({ status: "IN_PROGRESS", limit: 20, includes: "customer" }),
    refetchInterval: 30_000,
    staleTime: 20_000,
  });

  const allOrders = [
    ...(pendingData?.orders ?? []),
    ...(progressData?.orders ?? []),
  ];

  const customers = (() => {
    const seen = new Set<number>();
    const out: { order: Order; customer: NonNullable<Order["customer"]> }[] = [];
    for (const order of allOrders) {
      if (order.customer && !seen.has(order.customer.id)) {
        seen.add(order.customer.id);
        out.push({ order, customer: order.customer });
      }
    }
    return out;
  })();

  const startChatWith = useCallback(
    async (userId: number) => {
      if (opening) return;
      setOpening(true);
      try {
        await createOrGetChat(userId);
        window.location.href = `/support/chat?userId=${userId}`;
      } finally {
        setOpening(false);
      }
    },
    [opening],
  );

  return (
    <div className="px-3 pt-3 pb-3">
      <div className="flex items-center gap-2 mb-2">
        <ClipboardList size={13} className="text-amber-500" />
        <span className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">
          Pending Support ({customers.length})
        </span>
      </div>
      {customers.length === 0 && (
        <p className="text-xs text-gray-400 px-1">No pending orders</p>
      )}
      {customers.map(({ order, customer }) => (
        <ContactCard
          key={customer.id}
          name={customer.full_name}
          phone={customer.phone}
          photo={customer.personal_photo}
          label={`#${order.order_number} · ${order.status.replace("_", " ")}`}
          labelColor={
            order.status === "IN_PROGRESS"
              ? "bg-blue-100 text-blue-700"
              : "bg-amber-100 text-amber-700"
          }
          onChat={() => startChatWith(customer.id)}
        />
      ))}
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function SupportChatPage() {
  return (
    <ChatLayout
      queryKey="support-chats"
      allowNewChat={true}
      newChatLabel="New Chat"
      rightPanel={<SupportRightPanel />}
    />
  );
}
