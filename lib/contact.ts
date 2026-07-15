import api from "./api";

export interface ContactMessage {
  id: number;
  name: string;
  email: string;
  message: string;
  response?: string | null;
  read: boolean;
  read_at?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}
export interface ContactMessagesResponse { totalMessages: number; totalPages: number; messages: ContactMessage[]; }

export async function fetchContactMessages(params?: Record<string, string | number>) {
  const { page = 1, limit = 20, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get<ContactMessagesResponse>("/contact-us", { params: { limit, skip, ...rest } });
  return res.data;
}
export async function updateContactMessage(id: number, data: { response?: string; read?: boolean }) {
  const res = await api.put(`/contact-us/${id}`, data);
  return res.data;
}
export async function deleteContactMessage(id: number) {
  const res = await api.delete(`/contact-us/${id}`);
  return res.data;
}
export async function bulkDeleteContactMessages(ids: number[]) {
  const res = await api.delete("/contact-us", { data: { ids } });
  return res.data;
}
