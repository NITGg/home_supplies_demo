"use client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef, useState, useCallback } from "react";
import {
  fetchMyChats, fetchChatMessages, createOrGetChat, sendMessage, searchUsers,
  chatDisplayName, chatDisplayPhoto,
  type Chat, type ChatMessage, type ChatUser, type MessagesResponse,
} from "@/lib/chat";
import { getCourierSocket } from "@/lib/socket";
import { getCurrentUserId } from "@/lib/auth";
import { type Order } from "@/lib/orders";
import {
  MessageSquare, Phone, Search, Send, X, Plus, User,
  ChevronLeft, ChevronRight,
} from "lucide-react";
import { cn } from "@/lib/utils";

const myId = typeof window !== "undefined" ? getCurrentUserId() : null;

// ─── Types ────────────────────────────────────────────────────────────────────

export interface ChatLayoutProps {
  queryKey: string;
  rightPanel?: React.ReactNode;
  allowNewChat?: boolean;
  newChatLabel?: string;
}

export type StartChatFn = (userId: number, order?: Order) => Promise<void>;

// ─── Avatar ───────────────────────────────────────────────────────────────────

export function Avatar({
  user,
  size = "md",
}: {
  user: { full_name: string; personal_photo?: string | null };
  size?: "sm" | "md" | "lg";
}) {
  const sz =
    size === "sm"
      ? "w-8 h-8 text-xs"
      : size === "lg"
      ? "w-12 h-12 text-base"
      : "w-10 h-10 text-sm";
  if (user.personal_photo) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={user.personal_photo}
        alt={user.full_name}
        className={cn(sz, "rounded-full object-cover flex-shrink-0")}
      />
    );
  }
  return (
    <div
      className={cn(
        sz,
        "rounded-full bg-indigo-100 text-indigo-700 font-bold flex items-center justify-center flex-shrink-0",
      )}
    >
      {user.full_name.charAt(0).toUpperCase()}
    </div>
  );
}

// ─── New-chat modal ───────────────────────────────────────────────────────────

export function NewChatModal({
  onClose,
  onStart,
  title = "New Chat",
  placeholder = "Search by name or phone…",
}: {
  onClose: () => void;
  onStart: (userId: number) => void;
  title?: string;
  placeholder?: string;
}) {
  const [q, setQ] = useState("");
  const [results, setResults] = useState<ChatUser[]>([]);
  const [searching, setSearching] = useState(false);

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

  return (
    <div
      className="fixed inset-0 bg-black/40 flex items-center justify-center z-50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
          <h2 className="font-semibold text-gray-800">{title}</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X size={18} />
          </button>
        </div>
        <div className="p-4">
          <div className="relative">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              autoFocus
              type="text"
              placeholder={placeholder}
              value={q}
              onChange={(e) => setQ(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-300 text-[#0f1f3d] bg-white placeholder-gray-400"
            />
          </div>
        </div>
        <div className="max-h-72 overflow-y-auto divide-y divide-gray-50">
          {searching && (
            <p className="text-sm text-gray-400 text-center py-6">Searching…</p>
          )}
          {!searching && q.trim() && results.length === 0 && (
            <p className="text-sm text-gray-400 text-center py-6">No users found</p>
          )}
          {results.map((u) => (
            <button
              key={u.id}
              onClick={() => {
                onStart(u.id);
                onClose();
              }}
              className="w-full flex items-center gap-3 px-5 py-3 hover:bg-gray-50 transition-colors text-left"
            >
              <Avatar user={u} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-800 truncate">{u.full_name}</p>
                {u.phone && <p className="text-xs text-gray-500">{u.phone}</p>}
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Message bubble ───────────────────────────────────────────────────────────

function MessageBubble({ msg }: { msg: ChatMessage }) {
  const isMine = msg.sender.id === myId;
  const time = new Date(msg.created_at).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
  return (
    <div className={cn("flex gap-2 items-end", isMine ? "flex-row-reverse" : "flex-row")}>
      {!isMine && <Avatar user={msg.sender} size="sm" />}
      <div
        className={cn(
          "max-w-[70%] flex flex-col gap-0.5",
          isMine ? "items-end" : "items-start",
        )}
      >
        {!isMine && (
          <span className="text-xs text-gray-500 px-1">{msg.sender.full_name}</span>
        )}
        <div
          className={cn(
            "px-4 py-2.5 rounded-2xl text-sm leading-relaxed",
            isMine
              ? "bg-indigo-600 text-white rounded-br-sm"
              : "bg-gray-100 text-gray-800 rounded-bl-sm",
          )}
        >
          {msg.content}
        </div>
        <div
          className={cn(
            "flex items-center gap-1 px-1",
            isMine ? "flex-row-reverse" : "flex-row",
          )}
        >
          <span className="text-[10px] text-gray-400">{time}</span>
          {isMine && (
            <span
              className={cn(
                "text-[10px] font-medium",
                msg.is_read ? "text-indigo-400" : "text-gray-300",
              )}
              title={msg.is_read ? "Seen" : "Sent"}
            >
              {msg.is_read ? "✓✓" : "✓"}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Message thread ───────────────────────────────────────────────────────────

function MessageThread({
  chat,
  queryKey,
  onClose,
}: {
  chat: Chat;
  queryKey: string;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [input, setInput] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);
  const other = chat.otherParticipants?.[0];
  const messagesQueryKey = [queryKey + "-messages", chat.id];

  const { data, isLoading } = useQuery({
    queryKey: messagesQueryKey,
    queryFn: () => fetchChatMessages(chat.id),
    refetchInterval: 10_000,
    staleTime: 8_000,
  });

  const messages = data?.messages ?? [];

  // ── Real-time: join socket room and listen for new messages ──
  useEffect(() => {
    let socket: ReturnType<typeof getCourierSocket> = null;
    let cancelled = false;

    const setup = async () => {
      if (cancelled) return;
      socket = getCourierSocket();
      if (!socket) return;

      const joinRoom = () => {
        socket!.emit("chat:join", { chatId: chat.id }, (res: any) => {
          console.log("[ChatLayout] chat:join response", res);
        });
      };

      if (socket.connected) {
        joinRoom();
      } else {
        socket.once("connect", joinRoom);
      }

      const handleNewMessage = ({ message }: { message: ChatMessage }) => {
        qc.setQueryData(messagesQueryKey, (old: MessagesResponse | undefined) => {
          if (!old) return old;
          if (old.messages.some((m) => m.id === message.id)) return old;
          return { ...old, messages: [...old.messages, message] };
        });
        qc.invalidateQueries({ queryKey: [queryKey] });
      };

      socket.on("chat:new_message", handleNewMessage);

      return () => {
        socket!.off("connect", joinRoom);
        socket!.off("chat:new_message", handleNewMessage);
        socket!.emit("chat:leave", { chatId: chat.id });
      };
    };

    let cleanup: (() => void) | undefined;
    setup().then((fn) => {
      cleanup = fn;
    });

    return () => {
      cancelled = true;
      cleanup?.();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chat.id, queryKey]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  const sendMutation = useMutation({
    mutationFn: (content: string) => sendMessage(chat.id, content),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: messagesQueryKey });
      qc.invalidateQueries({ queryKey: [queryKey] });
      setInput("");
    },
  });

  const submit = () => {
    const text = input.trim();
    if (!text || sendMutation.isPending) return;
    sendMutation.mutate(text);
  };

  return (
    <div className="flex flex-col h-full">
      {/* Thread header */}
      <div className="flex items-center gap-3 px-5 py-4 border-b border-gray-100 bg-white flex-shrink-0">
        {other ? (
          <Avatar user={other} />
        ) : (
          <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center">
            <User size={18} className="text-gray-400" />
          </div>
        )}
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-gray-900 truncate">
            {chatDisplayName(chat, myId!)}
          </p>
          {other?.phone && <p className="text-xs text-gray-500">{other.phone}</p>}
        </div>
        {other?.phone && (
          <a
            href={`tel:${other.phone}`}
            className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-green-50 text-green-700 border border-green-200 rounded-lg hover:bg-green-100 transition-colors"
          >
            <Phone size={14} /> Call
          </a>
        )}
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4 bg-gray-50">
        {isLoading && (
          <p className="text-sm text-gray-400 text-center py-8">Loading…</p>
        )}
        {!isLoading && messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full gap-3 text-gray-400">
            <MessageSquare size={40} className="opacity-30" />
            <p className="text-sm">No messages yet. Say hello!</p>
          </div>
        )}
        {messages.map((msg) => (
          <MessageBubble key={msg.id} msg={msg} />
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-5 py-4 border-t border-gray-100 bg-white flex-shrink-0">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                submit();
              }
            }}
            placeholder="Type a message…"
            className="flex-1 px-4 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-300 text-[#0f1f3d] bg-white placeholder-gray-400"
          />
          <button
            onClick={submit}
            disabled={!input.trim() || sendMutation.isPending}
            className="px-4 py-2.5 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50 transition-colors"
          >
            <Send size={16} />
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── ChatLayout ───────────────────────────────────────────────────────────────

export default function ChatLayout({
  queryKey,
  rightPanel,
  allowNewChat = true,
  newChatLabel = "New Chat",
}: ChatLayoutProps) {
  const qc = useQueryClient();

  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);
  const [showNewChat, setShowNewChat] = useState(false);
  const [search, setSearch] = useState("");
  const [openingChat, setOpeningChat] = useState(false);
  const [openingError, setOpeningError] = useState<string | null>(null);
  const [leftOpen, setLeftOpen] = useState(true);
  const [rightOpen, setRightOpen] = useState(true);

  // ── Chat list ──
  const { data, isLoading, refetch: refetchChats } = useQuery({
    queryKey: [queryKey],
    queryFn: fetchMyChats,
    refetchInterval: 10_000,
    staleTime: 8_000,
  });

  // ── Auto-open chat from ?userId= ──
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const userId = Number(params.get("userId"));
    if (!userId) return;
    window.history.replaceState({}, "", window.location.pathname);
    setOpeningChat(true);
    setOpeningError(null);
    createOrGetChat(userId)
      .then(async ({ chat }) => {
        await refetchChats();
        setSelectedChatId(chat.id);
      })
      .catch((err: Error) => setOpeningError(err.message))
      .finally(() => setOpeningChat(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const chats = data?.chats ?? [];
  const filtered = search.trim()
    ? chats.filter((c) =>
        chatDisplayName(c, myId!).toLowerCase().includes(search.toLowerCase()),
      )
    : chats;

  const selectedChat = chats.find((c) => c.id === selectedChatId) ?? null;

  const startChat: StartChatFn = useCallback(
    async (userId: number) => {
      setOpeningChat(true);
      setOpeningError(null);
      try {
        const { chat } = await createOrGetChat(userId);
        await refetchChats();
        setSelectedChatId(chat.id);
      } catch (err: any) {
        setOpeningError(err.message);
      } finally {
        setOpeningChat(false);
      }
    },
    [refetchChats],
  );

  const hasRightPanel = rightPanel !== undefined && rightPanel !== null;

  return (
    <div className="flex h-screen bg-gray-50 overflow-hidden">
      {allowNewChat && showNewChat && (
        <NewChatModal
          onClose={() => setShowNewChat(false)}
          onStart={(uid) => startChat(uid)}
          title={newChatLabel}
        />
      )}

      {/* ── Left panel: conversation list ── */}
      <div
        className={cn(
          "flex-shrink-0 flex flex-col bg-white border-r border-gray-100 transition-all duration-200",
          leftOpen ? "w-72" : "w-10",
        )}
      >
        {leftOpen ? (
          <>
            <div className="px-4 py-4 border-b border-gray-100 flex-shrink-0">
              <div className="flex items-center justify-between mb-3">
                <h1 className="text-base font-bold text-gray-900 flex items-center gap-2">
                  <MessageSquare size={18} className="text-indigo-600" />
                  Messages
                  {chats.length > 0 && (
                    <span className="text-xs text-gray-400 font-normal">
                      ({chats.length})
                    </span>
                  )}
                </h1>
                <div className="flex items-center gap-1">
                  {allowNewChat && (
                    <button
                      onClick={() => setShowNewChat(true)}
                      title={newChatLabel}
                      className="w-7 h-7 flex items-center justify-center bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors"
                    >
                      <Plus size={14} />
                    </button>
                  )}
                  <button
                    onClick={() => setLeftOpen(false)}
                    className="w-7 h-7 flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                  >
                    <ChevronLeft size={14} />
                  </button>
                </div>
              </div>
              <div className="relative">
                <Search
                  size={13}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                />
                <input
                  type="text"
                  placeholder="Search conversations…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="w-full pl-8 pr-3 py-1.5 text-xs border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-300 text-[#0f1f3d] bg-white placeholder-gray-400"
                />
              </div>
            </div>
            <div className="flex-1 overflow-y-auto">
              {isLoading && (
                <p className="text-xs text-gray-400 text-center py-8">Loading…</p>
              )}
              {!isLoading && filtered.length === 0 && (
                <div className="flex flex-col items-center justify-center py-12 gap-2 text-gray-400">
                  <MessageSquare size={32} className="opacity-20" />
                  <p className="text-xs">No conversations yet</p>
                  {allowNewChat && (
                    <button
                      onClick={() => setShowNewChat(true)}
                      className="text-xs text-indigo-600 hover:underline"
                    >
                      Start a new chat
                    </button>
                  )}
                </div>
              )}
              {filtered.map((chat) => {
                const name = chatDisplayName(chat, myId!);
                const photo = chatDisplayPhoto(chat, myId!);
                const lastMsg = chat.lastMessage;
                const isSelected = chat.id === selectedChatId;
                const time = lastMsg
                  ? new Date(lastMsg.created_at).toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })
                  : "";
                return (
                  <button
                    key={chat.id}
                    onClick={() => setSelectedChatId(chat.id)}
                    className={cn(
                      "w-full flex items-start gap-2.5 px-4 py-3 transition-colors text-left border-b border-gray-50",
                      isSelected ? "bg-indigo-50" : "hover:bg-gray-50",
                    )}
                  >
                    <Avatar
                      user={{ full_name: name, personal_photo: photo }}
                      size="sm"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-1">
                        <span
                          className={cn(
                            "text-xs truncate",
                            isSelected
                              ? "font-semibold text-indigo-700"
                              : "font-medium text-gray-800",
                          )}
                        >
                          {name}
                        </span>
                        {time && (
                          <span className="text-[10px] text-gray-400 flex-shrink-0">
                            {time}
                          </span>
                        )}
                      </div>
                      {lastMsg && (
                        <p className="text-[11px] text-gray-500 truncate mt-0.5">
                          {lastMsg.sender.id === myId ? "You: " : ""}
                          {lastMsg.content}
                        </p>
                      )}
                    </div>
                    {chat.unreadCount > 0 && (
                      <span className="flex-shrink-0 min-w-[18px] h-[18px] flex items-center justify-center bg-indigo-600 text-white text-[10px] font-bold rounded-full px-1">
                        {chat.unreadCount}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </>
        ) : (
          <div className="flex flex-col items-center py-4 gap-3">
            <button
              onClick={() => setLeftOpen(true)}
              className="w-7 h-7 flex items-center justify-center text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
              title="Open conversations"
            >
              <ChevronRight size={14} />
            </button>
            <div className="relative">
              <MessageSquare size={16} className="text-gray-400" />
              {chats.some((c) => c.unreadCount > 0) && (
                <span className="absolute -top-1 -right-1 w-2 h-2 bg-indigo-600 rounded-full" />
              )}
            </div>
          </div>
        )}
      </div>

      {/* ── Center: message thread ── */}
      <div className="flex-1 min-w-0 flex flex-col">
        {selectedChat ? (
          <MessageThread
            chat={selectedChat}
            queryKey={queryKey}
            onClose={() => setSelectedChatId(null)}
          />
        ) : openingChat ? (
          <div className="flex-1 flex flex-col items-center justify-center gap-3 text-gray-400">
            <div className="w-10 h-10 border-2 border-indigo-300 border-t-indigo-600 rounded-full animate-spin" />
            <p className="text-sm text-gray-500">Opening conversation…</p>
          </div>
        ) : openingError ? (
          <div className="flex-1 flex flex-col items-center justify-center gap-3">
            <p className="text-sm font-medium text-red-600">Failed to open chat</p>
            <p className="text-xs text-gray-500 max-w-xs text-center">{openingError}</p>
            <button
              onClick={() => setOpeningError(null)}
              className="text-xs text-indigo-600 hover:underline"
            >
              Dismiss
            </button>
          </div>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center gap-4 text-gray-400">
            <MessageSquare size={56} className="opacity-20" />
            <div className="text-center">
              <p className="text-base font-medium text-gray-500">
                Select a conversation
              </p>
              {allowNewChat && (
                <p className="text-sm mt-1">or start a new chat from the panel</p>
              )}
            </div>
            {allowNewChat && (
              <button
                onClick={() => setShowNewChat(true)}
                className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white text-sm rounded-lg hover:bg-indigo-700 transition-colors"
              >
                <Plus size={16} /> {newChatLabel}
              </button>
            )}
          </div>
        )}
      </div>

      {/* ── Right panel ── */}
      {hasRightPanel && (
        <div
          className={cn(
            "flex-shrink-0 flex flex-col bg-white border-l border-gray-100 transition-all duration-200",
            rightOpen ? "w-64" : "w-10",
          )}
        >
          {rightOpen ? (
            <>
              <div className="px-4 py-4 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
                <h2 className="text-sm font-bold text-gray-900">Contacts</h2>
                <button
                  onClick={() => setRightOpen(false)}
                  className="w-7 h-7 flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                >
                  <ChevronRight size={14} />
                </button>
              </div>
              <div className="flex-1 overflow-y-auto">{rightPanel}</div>
            </>
          ) : (
            <div className="flex flex-col items-center py-4 gap-3">
              <button
                onClick={() => setRightOpen(true)}
                className="w-7 h-7 flex items-center justify-center text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                title="Open contacts"
              >
                <ChevronLeft size={14} />
              </button>
              <MessageSquare size={16} className="text-gray-400" />
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Export startChat factory (for callers building right panels) ──────────────

/**
 * Helper hook that callers can use to get a `startChat` function that references
 * the same refetch handle that ChatLayout uses internally.
 * Since ChatLayout manages its own state internally, callers instead pass
 * the right panel as ReactNode and use their own data — ChatLayout will call
 * createOrGetChat when the user clicks in its own panels. For external panels,
 * wrap the click in a Link to ?userId=N which ChatLayout auto-opens on mount.
 */
export { createOrGetChat } from "@/lib/chat";
