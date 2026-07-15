import { useEffect, useState } from "react";
import { getToken, onMessage } from "firebase/messaging";
import { getFirebaseMessaging } from "../firebase/firebase.config";
import axiosInstance from "@/lib/axios";
import { toast } from "sonner";

const VAPID_KEY = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;

export type ForegroundMessage = {
  title: string;
  body: string;
  icon?: string;
};

/**
 * useFirebaseMessaging
 *
 * - Requests notification permission
 * - Gets the FCM registration token (send this to your backend to target this device)
 * - Listens for foreground messages and exposes the latest one
 */
export function useFirebaseMessaging() {
  const [token, setToken] = useState<string | null>(null);
  const [permissionStatus, setPermissionStatus] =
    useState<NotificationPermission>("default");
  const [foregroundMessage, setForegroundMessage] =
    useState<ForegroundMessage | null>(null);
  const [error, setError] = useState<string | null>(null);

  const requestPermissionAndGetToken = async () => {
    try {
      const permission = await Notification.requestPermission();
      setPermissionStatus(permission);

      if (permission !== "granted") {
        setError("Notification permission denied.");
        return;
      }

      const messaging = await getFirebaseMessaging();
      if (!messaging) {
        setError("Firebase Messaging is not supported in this browser.");
        return;
      }

      const fcmToken = await getToken(messaging, {
        vapidKey: VAPID_KEY,
        serviceWorkerRegistration: await navigator.serviceWorker.ready,
      });

      if (fcmToken) {
        setToken(fcmToken);
        console.log("[FCM] Token:", fcmToken);
        await axiosInstance.post("/profile/fcm-token", { fcmToken });
      } else {
        setError(
          "Failed to get FCM token. Check VAPID key and service worker.",
        );
      }
    } catch (err) {
      console.error("[FCM] Error:", err);
      setError(String(err));
    }
  };

  useEffect(() => {
    // Check current permission state on mount
    setPermissionStatus(Notification.permission);

    let unsubscribe: (() => void) | undefined;

    const setupForegroundListener = async () => {
      const messaging = await getFirebaseMessaging();
      if (!messaging) return;

      // Listen for messages when the app is in the FOREGROUND
      unsubscribe = onMessage(messaging, (payload) => {
        console.log("[FCM] Foreground message received:", payload);
        const message = {
          title: payload.notification?.title ?? "New Notification",
          body: payload.notification?.body ?? "",
          icon: payload.notification?.icon || "/favicon.ico",
        };

        setForegroundMessage(message);
        toast.info(message.title); // ✅ correct
      });
    };

    setupForegroundListener();

    return () => {
      unsubscribe?.();
    };
  }, []);

  return {
    token,
    permissionStatus,
    foregroundMessage,
    error,
    requestPermissionAndGetToken,
  };
}
