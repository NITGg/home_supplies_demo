import api from "./api";

export type RecipientType = "all" | "users" | "role";
export type NotificationRole = "admin" | "customer" | "courier";

/** Bilingual string — the API accepts either a plain string or {en, ar} object. */
type BilingualString = string | { en: string; ar: string };

export interface SendNotificationPayload {
  recipientType: RecipientType;
  userIds?: number[];
  roles?: NotificationRole[];
  content: {
    title?: BilingualString;
    body: BilingualString;
    titleKey?: string;
    bodyKey?: string;
  };
  data?: Record<string, unknown>;
}

export interface NotificationResult {
  totalUsers: number;
  successCount: number;
  failCount: number;
  deliveredCount: number;
  storedOnlyCount: number;
}

export async function sendNotification(payload: SendNotificationPayload): Promise<NotificationResult> {
  const res = await api.post<NotificationResult>("/notifications/send", payload);
  return res.data;
}

export interface NotificationProgress {
  totalUsers: number;
  processed: number;
  successCount: number;
  failCount: number;
  deliveredCount: number;
  storedOnlyCount: number;
}

/** Same token lookup the axios `api` instance uses. */
function getAuthToken(): string | null {
  if (typeof window === "undefined") return null;
  const ls = localStorage.getItem("token");
  if (ls) return ls;
  const match = document.cookie.match(/(?:^|;\s*)token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : null;
}

/**
 * Sends a notification via the SSE streaming endpoint and resolves with the
 * final delivery counts. The plain `/notifications/send` route does not return
 * per-recipient stats — only the stream's "done" event carries them.
 *
 * `onProgress` (optional) fires on every progress tick so the UI can render a
 * live progress bar.
 */
export async function sendNotificationStream(
  payload: SendNotificationPayload,
  onProgress?: (p: NotificationProgress) => void,
): Promise<NotificationResult> {
  const token = getAuthToken();
  const base = (api.defaults.baseURL ?? "").replace(/\/$/, "");
  const lang = (typeof window !== "undefined" && localStorage.getItem("admin_lang")) || "EN";

  const res = await fetch(`${base}/notifications/send/stream`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept-Language": lang.toLowerCase(),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok || !res.body) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as { message?: string }).message || `HTTP ${res.status}`);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let currentEvent = "";
  let latest: Partial<NotificationProgress> = {};

  const handle = (raw: string) => {
    const line = raw.trim();
    if (!line) return;
    if (line.startsWith("event:")) {
      currentEvent = line.slice(6).trim();
      return;
    }
    if (!line.startsWith("data:")) return;
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(line.slice(5).trim());
    } catch {
      return;
    }
    // Stats live either at the top level (progress) or under `data` (done).
    const stats = (parsed.data && typeof parsed.data === "object"
      ? (parsed.data as Record<string, unknown>)
      : parsed) as Partial<NotificationProgress>;
    if (typeof stats.successCount === "number" || typeof stats.processed === "number") {
      latest = { ...latest, ...stats };
      if (onProgress) {
        onProgress({
          totalUsers: latest.totalUsers ?? 0,
          processed: latest.processed ?? 0,
          successCount: latest.successCount ?? 0,
          failCount: latest.failCount ?? 0,
          deliveredCount: latest.deliveredCount ?? 0,
          storedOnlyCount: latest.storedOnlyCount ?? 0,
        });
      }
    }
  };

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const l of lines) handle(l);
  }
  if (buffer.trim()) handle(buffer);
  void currentEvent;

  return {
    totalUsers: latest.totalUsers ?? 0,
    successCount: latest.successCount ?? 0,
    failCount: latest.failCount ?? 0,
    deliveredCount: latest.deliveredCount ?? 0,
    storedOnlyCount: latest.storedOnlyCount ?? 0,
  };
}

/**
 * Sends a bilingual (EN + AR) push notification to a courier informing them
 * that their account has been approved. Fire-and-forget safe — caller should
 * .catch(() => {}) so a notification failure never blocks the UI.
 */
export async function sendCourierApprovalNotification(userId: number): Promise<NotificationResult> {
  return sendNotification({
    recipientType: "users",
    userIds: [userId],
    content: {
      title: {
        en: "You're Approved! 🎉",
        ar: "تم قبولك! 🎉",
      },
      body: {
        en: "Congratulations! You are now approved to work on Tawreedat. Start delivering today!",
        ar: "تهانينا! تم قبولك للعمل على توريدات. ابدأ التوصيل الآن!",
      },
    },
    data: { navigate: "home" },
  });
}
