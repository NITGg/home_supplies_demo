import { getCourierToken } from "./auth";

const COURIER_API = process.env.NEXT_PUBLIC_COURIER_API_URL!;

async function courierFetch<T>(
  path: string,
  options: RequestInit = {},
  retried = false,
): Promise<T> {
  const token = await getCourierToken();
  const res = await fetch(`${COURIER_API}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `${process.env.NEXT_PUBLIC_COURIER_BEARER_PREFIX ?? "Bearer"} ${token}`,
      ...(options.headers ?? {}),
    },
  });
  if (res.status === 401 && !retried) {
    // Stale token — force re-exchange and retry once
    localStorage.removeItem("courierToken");
    return courierFetch(path, options, true);
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body?.message ?? `Request failed: ${res.status}`);
  }
  return res.json();
}

export interface ChatUser {
  id: number;
  full_name: string;
  personal_photo?: string | null;
  phone?: string | null;
}

export interface ChatMessage {
  id: number;
  chat_id: number;
  content: string;
  type: "TEXT" | "IMAGE" | "FILE" | "VOICE";
  is_read: boolean;
  read_at?: string | null;
  created_at: string;
  sender: ChatUser;
}

export interface Chat {
  id: number;
  name?: string | null;
  is_group: boolean;
  updated_at: string;
  lastMessage?: ChatMessage | null;
  unreadCount: number;
  participants: ChatUser[];
  otherParticipants: ChatUser[];
}

export interface ChatsResponse {
  total: number;
  totalPages: number;
  chats: Chat[];
}

export interface MessagesResponse {
  total: number;
  totalPages: number;
  messages: ChatMessage[];
}

export async function fetchMyChats(): Promise<ChatsResponse> {
  const json = await courierFetch<{ data: ChatsResponse }>("/chat/get-my-chats-rich?limit=50");
  return json.data;
}

export async function fetchChatMessages(chatId: number, skip = 0): Promise<MessagesResponse> {
  const json = await courierFetch<{ data: { totalMessages: number; totalPages: number; messages: ChatMessage[] } }>(
    `/chat/get-chat/${chatId}?limit=50&skip=${skip}&sort=-created_at`,
  );
  return {
    total: json.data.totalMessages,
    totalPages: json.data.totalPages,
    messages: [...json.data.messages].reverse(),
  };
}

export async function createOrGetChat(targetUserId: number): Promise<{ chat: Chat; created: boolean }> {
  const json = await courierFetch<{ data: { chat: Chat; created: boolean } }>(
    `/chat/create-chat/${targetUserId}`,
    { method: "POST", body: "{}" },
  );
  return json.data;
}

export async function sendMessage(chatId: number, content: string): Promise<ChatMessage> {
  const json = await courierFetch<{ data: { message: ChatMessage } }>(
    `/chat/send-message/${chatId}`,
    { method: "POST", body: JSON.stringify({ content, type: "TEXT" }) },
  );
  return json.data.message;
}

export async function searchUsers(q: string): Promise<ChatUser[]> {
  const json = await courierFetch<{ data: { users: ChatUser[] } }>(
    `/chat/search-users?q=${encodeURIComponent(q)}`,
  );
  return json.data.users;
}

export function chatDisplayName(chat: Chat, myId: number): string {
  if (chat.is_group && chat.name) return chat.name;
  const other = chat.otherParticipants?.[0];
  return other?.full_name ?? `Chat #${chat.id}`;
}

export function chatDisplayPhoto(chat: Chat, _myId: number): string | null | undefined {
  return chat.otherParticipants?.[0]?.personal_photo;
}
