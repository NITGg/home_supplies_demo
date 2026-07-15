import axiosInstance from "@/lib/axios";

export type RecipientType = "all" | "role" | "users";

export interface NotificationContent {
  title: {
    en: string;
    ar: string;
  };
  body: {
    en: string;
    ar: string;
  };
}

export interface NotificationData {
  page?: string;
  navigate?: string;
  [key: string]: string | number | undefined;
}

export interface SendNotificationPayload {
  recipientType: RecipientType;
  roles?: ("courier" | "customer")[];
  userIds?: number[];
  content: NotificationContent;
  data?: NotificationData;
}

export interface StreamStats {
  totalUsers?: number;
  total?: number;
  processed: number;
  successCount: number;
  failCount: number;
  deliveredCount: number;
  storedOnlyCount: number;
}

export interface StreamMessage {
  type?: "started" | "progress" | "done";
  message?: string;
  data?: StreamStats;
}

export interface StreamLogEntry {
  type: "started" | "progress" | "done" | "error";
  raw: string;
  message?: string;
  keyValues?: Record<string, string | number>;
  timestamp: Date;
}

export interface StreamCallbacks {
  onLog: (entry: StreamLogEntry) => void;
  onProgress: (stats: StreamStats) => void;
  onError: (error: Error) => void;
  onComplete: () => void;
}

export const notificationService = {
  async sendNotificationStream(
    payload: SendNotificationPayload,
    callbacks: StreamCallbacks,
  ): Promise<void> {
    const token = localStorage.getItem("auth_token");
    const baseUrl = axiosInstance.defaults.baseURL || "/api";

    try {
      const response = await fetch(`${baseUrl}/notifications/send/stream`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: token ? `Bearer ${token}` : "",
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP error ${response.status}`);
      }

      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error("No response body");
      }

      const decoder = new TextDecoder();
      let buffer = "";
      let currentEventType: "started" | "progress" | "done" = "progress";

      const processLine = (line: string) => {
        const trimmed = line.trim();
        if (!trimmed) return;

        // Check for SSE event type line
        if (trimmed.startsWith("event:")) {
          const eventType = trimmed.replace("event:", "").trim();
          if (
            eventType === "started" ||
            eventType === "progress" ||
            eventType === "done"
          ) {
            currentEventType = eventType;
          }
          return;
        }

        // Check for SSE data line
        if (trimmed.startsWith("data:")) {
          const jsonStr = trimmed.replace("data:", "").trim();

          try {
            const parsed: Record<string, unknown> = JSON.parse(jsonStr);

            let message: string | undefined;
            let keyValues: Record<string, string | number> = {};
            // Extract message if exists
            if (typeof parsed.message === "string") {
              message = parsed.message;
            }

            // Extract key-values based on event type
            if (
              currentEventType === "done" &&
              parsed.data &&
              typeof parsed.data === "object"
            ) {
              // For "done" - extract from nested "data" field
              const data = parsed.data as Record<string, unknown>;
              keyValues = {};
              Object.entries(data).forEach(([key, value]) => {
                if (typeof value === "string" || typeof value === "number") {
                  keyValues[key] = value;
                }
              });
            } else if (currentEventType === "progress" && !parsed.data) {
              // For "progress" - extract directly from object
              keyValues = {};
              Object.entries(parsed).forEach(([key, value]) => {
                if (typeof value === "string" || typeof value === "number") {
                  keyValues[key] = value;
                }
              });
            } else if (parsed.data && typeof parsed.data === "object") {
              // Fallback - has nested data
              const data = parsed.data as Record<string, unknown>;
              keyValues = {};
              Object.entries(data).forEach(([key, value]) => {
                if (typeof value === "string" || typeof value === "number") {
                  keyValues[key] = value;
                }
              });
            }

            callbacks.onLog({
              type: currentEventType,
              raw: jsonStr,
              message,
              keyValues,
              timestamp: new Date(),
            });

            // Update progress stats
            if (parsed.data && typeof parsed.data === "object") {
              const data = parsed.data as StreamStats;
              if (data.processed !== undefined) {
                callbacks.onProgress(data);
              }
            } else if (
              typeof parsed.processed === "number" &&
              typeof parsed.total === "number"
            ) {
              callbacks.onProgress({
                processed: parsed.processed as number,
                total: parsed.total as number,
                successCount: (parsed.successCount as number) || 0,
                failCount: (parsed.failCount as number) || 0,
                deliveredCount: (parsed.deliveredCount as number) || 0,
                storedOnlyCount: (parsed.storedOnlyCount as number) || 0,
              });
            }
          } catch {
            // JSON parse failed, log raw
            callbacks.onLog({
              type: currentEventType,
              raw: jsonStr,
              timestamp: new Date(),
            });
          }
          return;
        }

        // Fallback for non-SSE format (direct JSON or event markers)
        if (
          trimmed === "started" ||
          trimmed === "progress" ||
          trimmed === "done"
        ) {
          currentEventType = trimmed;
          return;
        }

        // Try to parse as direct JSON
        try {
          const parsed: Record<string, unknown> = JSON.parse(trimmed);

          let eventType: "started" | "progress" | "done" = "progress";
          let message: string | undefined;
          let keyValues: Record<string, string | number> = {};
          if (typeof parsed.message === "string") {
            message = parsed.message;
            if (parsed.message.includes("stream_started")) {
              eventType = "started";
            } else if (parsed.message.includes("sent_successfully")) {
              eventType = "done";
            }
          }

          if (parsed.data && typeof parsed.data === "object") {
            const data = parsed.data as Record<string, unknown>;
            keyValues = {};
            Object.entries(data).forEach(([key, value]) => {
              if (typeof value === "string" || typeof value === "number") {
                keyValues[key] = value;
              }
            });
          } else {
            keyValues = {};
            Object.entries(parsed).forEach(([key, value]) => {
              if (typeof value === "string" || typeof value === "number") {
                keyValues[key] = value;
              }
            });
          }

          callbacks.onLog({
            type: eventType,
            raw: trimmed,
            message,
            keyValues,
            timestamp: new Date(),
          });

          if (parsed.data && typeof parsed.data === "object") {
            const data = parsed.data as StreamStats;
            if (data.processed !== undefined) {
              callbacks.onProgress(data);
            }
          }
        } catch {
          // Not JSON, skip
        }
      };

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });

        // Process complete lines
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          processLine(line);
        }
      }

      // Process any remaining buffer
      if (buffer.trim()) {
        processLine(buffer);
      }

      callbacks.onComplete();
    } catch (error) {
      callbacks.onError(
        error instanceof Error ? error : new Error(String(error)),
      );
    }
  },
};
