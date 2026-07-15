"use client";
import { useState, useEffect } from "react";
import ChatLayout, { Avatar, NewChatModal, createOrGetChat } from "@/components/chat/ChatLayout";
import { searchUsers, type ChatUser } from "@/lib/chat";
import { Headphones, Search, MessageSquare } from "lucide-react";
import { cn } from "@/lib/utils";

// ─── Support search panel ─────────────────────────────────────────────────────

function SupportSearchPanel() {
  const [q, setQ] = useState("");
  const [results, setResults] = useState<ChatUser[]>([]);
  const [searching, setSearching] = useState(false);
  const [opening, setOpening] = useState(false);

  useEffect(() => {
    if (!q.trim()) {
      setResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setSearching(true);
      try {
        setResults(await searchUsers(q));
      } finally {
        setSearching(false);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [q]);

  const startChatWith = async (userId: number) => {
    if (opening) return;
    setOpening(true);
    try {
      await createOrGetChat(userId);
      window.location.href = `/supplier/chat?userId=${userId}`;
    } finally {
      setOpening(false);
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Banner */}
      <div className="px-4 py-4 border-b border-gray-100">
        <div className="flex items-center gap-2 mb-2">
          <Headphones size={15} className="text-indigo-500" />
          <span className="text-sm font-semibold text-gray-800">Contact Support</span>
        </div>
        <p className="text-xs text-gray-500 leading-relaxed">
          As a supplier, you can chat with our support team (admin and seller staff). Search by
          name below to find and start a conversation.
        </p>
      </div>

      {/* Search */}
      <div className="px-4 py-3 border-b border-gray-100">
        <div className="relative">
          <Search
            size={13}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            type="text"
            placeholder="Search support staff…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="w-full pl-8 pr-3 py-1.5 text-xs border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-300 text-[#0f1f3d] bg-white placeholder-gray-400"
          />
        </div>
      </div>

      {/* Results */}
      <div className="flex-1 overflow-y-auto">
        {searching && (
          <p className="text-xs text-gray-400 text-center py-6">Searching…</p>
        )}
        {!searching && q.trim() && results.length === 0 && (
          <p className="text-xs text-gray-400 text-center py-6">No staff found</p>
        )}
        {!q.trim() && (
          <div className="flex flex-col items-center justify-center py-10 gap-2 text-gray-400">
            <MessageSquare size={28} className="opacity-20" />
            <p className="text-xs text-center px-4">
              Type a name to find support staff
            </p>
          </div>
        )}
        {results.map((u) => (
          <button
            key={u.id}
            onClick={() => startChatWith(u.id)}
            disabled={opening}
            className="w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-50 transition-colors text-left border-b border-gray-50 disabled:opacity-60"
          >
            <Avatar user={u} size="sm" />
            <div className="flex-1 min-w-0">
              <p className="text-xs font-medium text-gray-800 truncate">{u.full_name}</p>
              {u.phone && <p className="text-[10px] text-gray-500">{u.phone}</p>}
            </div>
            <MessageSquare size={13} className="text-indigo-500 flex-shrink-0" />
          </button>
        ))}
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function SupplierChatPage() {
  return (
    <ChatLayout
      queryKey="supplier-chats"
      allowNewChat={false}
      rightPanel={<SupportSearchPanel />}
    />
  );
}
