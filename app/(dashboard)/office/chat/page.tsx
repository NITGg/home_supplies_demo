"use client";
import { useQuery } from "@tanstack/react-query";
import { useState, useCallback } from "react";
import ChatLayout, { Avatar, createOrGetChat } from "@/components/chat/ChatLayout";
import { fetchOnlineCouriers, courierName, courierPhone, courierPhoto } from "@/lib/couriers";
import { MessageSquare, Phone, Truck } from "lucide-react";
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

// ─── Right panel: my couriers ─────────────────────────────────────────────────

function OfficeCouriersPanel() {
  const [opening, setOpening] = useState(false);

  const { data: couriersData } = useQuery({
    queryKey: ["office-couriers-panel"],
    queryFn: () => fetchOnlineCouriers({ take: 50 }),
    refetchInterval: 30_000,
    staleTime: 20_000,
  });

  const couriers = couriersData?.couriers ?? [];

  const startChatWith = useCallback(
    async (userId: number) => {
      if (opening) return;
      setOpening(true);
      try {
        await createOrGetChat(userId);
        window.location.href = `/office/chat?userId=${userId}`;
      } finally {
        setOpening(false);
      }
    },
    [opening],
  );

  return (
    <div className="px-3 pt-3 pb-3">
      <div className="flex items-center gap-2 mb-2">
        <Truck size={13} className="text-blue-500" />
        <span className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">
          My Couriers ({couriers.length})
        </span>
      </div>
      {couriers.length === 0 && (
        <p className="text-xs text-gray-400 px-1">No online couriers</p>
      )}
      {couriers.map((c) => (
        <ContactCard
          key={c.id}
          name={courierName(c)}
          phone={courierPhone(c)}
          photo={courierPhoto(c)}
          label="Courier"
          labelColor="bg-blue-100 text-blue-700"
          onChat={() => startChatWith(c.user_id)}
        />
      ))}
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function OfficeChatPage() {
  return (
    <ChatLayout
      queryKey="office-chats"
      allowNewChat={true}
      newChatLabel="New Chat"
      rightPanel={<OfficeCouriersPanel />}
    />
  );
}
