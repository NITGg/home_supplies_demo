/**
 * registerServiceWorker
 *
 * Call this once in your app entry point (main.tsx or App.tsx).
 * It registers /firebase-messaging-sw.js so Firebase Messaging can
 * receive background push notifications.
 */
export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  if (!("serviceWorker" in navigator)) {
    console.warn("[SW] Service workers are not supported in this browser.");
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.register(
      "/firebase-messaging-sw.js",
      {
        scope: "/",
      },
    );

    console.log("[SW] Registered successfully:", registration.scope);
    return registration;
  } catch (err) {
    console.error("[SW] Registration failed:", err);
    return null;
  }
}
