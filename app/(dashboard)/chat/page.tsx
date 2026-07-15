"use client";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useState, useCallback } from "react";
import ChatLayout, { Avatar, NewChatModal, createOrGetChat } from "@/components/chat/ChatLayout";
import { chatDisplayName, chatDisplayPhoto, fetchMyChats, type Chat } from "@/lib/chat";
import { fetchOnlineCouriers, courierName, courierPhone, courierPhoto } from "@/lib/couriers";
import { fetchOrders, type Order } from "@/lib/orders";
import { getCurrentUserId } from "@/lib/auth";
import { MessageSquare, Phone, Truck, ShoppingBag } from "lucide-react";
import { cn } from "@/lib/utils";

const myId = typeof window !== "undefined" ? getCurrentUserId() : null;

// ─── Contact card ─────────────────────────────────────────────────────────────

function ContactCard({
  name,
  phone,
  photo,
  label,
  labelColor,
  onChat,
  onCall,
}: {
  name: string;
  phone?: string;
  photo?: string | null;
  label: string;
  labelColor: string;
  onChat: () => void;
  onCall?: () => void;
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

// ─── Right panel ──────────────────────────────────────────────────────────────

function AdminRightPanel() {
  const [openingChat, setOpeningChat] = useState(false);
  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);

  const { data: couriersData } = useQuery({
    queryKey: ["online-couriers-panel"],
    queryFn: () => fetchOnlineCouriers({ take: 30 }),
    refetchInterval: 30_000,
    staleTime: 20_000,
  });

  const { data: activeOrdersData } = useQuery({
    queryKey: ["active-orders-panel"],
    queryFn: () => fetchOrders({ status: "IN_PROGRESS", limit: 30, includes: "customer" }),
    refetchInterval: 30_000,
    staleTime: 20_000,
  });

  const onlineCouriers = couriersData?.couriers ?? [];

  const activeCustomers = (() => {
    const seen = new Set<number>();
    const out: { order: Order; customer: NonNullable<Order["customer"]> }[] = [];
    for (const order of activeOrdersData?.orders ?? []) {
      if (order.customer && !seen.has(order.customer.id)) {
        seen.add(order.customer.id);
        out.push({ order, customer: order.customer });
      }
    }
    return out;
  })();

  const startChatWith = useCallback(async (userId: number) => {
    if (openingChat) return;
    setOpeningChat(true);
    try {
      await createOrGetChat(userId);
      // Navigate to chat page with userId param so ChatLayout auto-opens it
      window.location.href = `/chat?userId=${userId}`;
    } finally {
      setOpeningChat(false);
    }
  }, [openingChat]);

  return (
    <>
      {/* Online couriers */}
      <div className="px-3 pt-3 pb-1">
        <div className="flex items-center gap-2 mb-2">
          <Truck size={13} className="text-indigo-500" />
          <span className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">
            Online Couriers ({onlineCouriers.length})
          </span>
        </div>
        {onlineCouriers.length === 0 && (
          <p className="text-xs text-gray-400 px-1 pb-2">No online couriers</p>
        )}
        {onlineCouriers.map((c) => (
          <ContactCard
            key={c.id}
            name={courierName(c)}
            phone={courierPhone(c)}
            photo={courierPhoto(c)}
            label="Courier"
            labelColor="bg-indigo-100 text-indigo-700"
            onChat={() => startChatWith(c.user_id)}
          />
        ))}
      </div>

      <div className="mx-3 my-2 border-t border-gray-100" />

      {/* Active order customers */}
      <div className="px-3 pb-3">
        <div className="flex items-center gap-2 mb-2">
          <ShoppingBag size={13} className="text-amber-500" />
          <span className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">
            Active Orders ({activeCustomers.length})
          </span>
        </div>
        {activeCustomers.length === 0 && (
          <p className="text-xs text-gray-400 px-1">No active orders</p>
        )}
        {activeCustomers.map(({ order, customer }) => (
          <ContactCard
            key={customer.id}
            name={customer.full_name}
            phone={customer.phone}
            photo={customer.personal_photo}
            label={`#${order.order_number}`}
            labelColor="bg-amber-100 text-amber-700"
            onChat={() => startChatWith(customer.id)}
            onCall={() => {}}
          />
        ))}
      </div>
    </>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function ChatPage() {
  return (
    <ChatLayout
      queryKey="my-chats"
      allowNewChat={true}
      newChatLabel="New Chat"
      rightPanel={<AdminRightPanel />}
    />
  );
}
