import { cloudMessaging } from "@/config/firebase";
import env from "@/config/env";

export type FcmData = Record<string, string>;

export type SendFcmInput = {
  token: string;
  title: string;
  body: string;
  data?: FcmData;
};

export async function sendFcmMessage({
  token,
  title,
  body,
  data,
}: SendFcmInput) {
  return cloudMessaging.send({
    token,
    notification: {
      imageUrl: env.DASHBOARD_URL
        ? `${env.DASHBOARD_URL}/favicon.ico`
        : "/favicon.ico",
      title,
      body,
    },
    data,
    webpush: {
      notification: {
        icon: env.DASHBOARD_URL
          ? `${env.DASHBOARD_URL}/favicon.ico`
          : "/favicon.ico",
        badge: env.DASHBOARD_URL
          ? `${env.DASHBOARD_URL}/favicon.ico`
          : "/favicon.ico",
        vibrate: [100, 50, 100], // vibration pattern: vibrate, pause, vibrate
      },
    },
  });
}

// export async function sendFcmMessage({
//   token,
//   title,
//   body,
//   data,
// }: SendFcmInput) {
//   const page = data?.page || "/";
//   const icon = `${env.DASHBOARD_URL}/favicon.ico`;

//   return cloudMessaging.send({
//     token,

//     // ─── Web (PWA / browser) ────────────────────────────────────────────────
//     // NO top-level `notification` field for web tokens.
//     // When `notification` is present the browser auto-displays it and
//     // bypasses onBackgroundMessage entirely, so data.page is never read.
//     // We use data-only + webpush.notification instead, which lets the SW
//     // control display and keep full access to payload.data.
//     webpush: {
//       // data fields for the SW — all values must be strings for FCM data payloads
//       data: {
//         title,
//         body,
//         page,
//         icon,
//         ...Object.fromEntries(
//           Object.entries(data ?? {}).map(([k, v]) => [k, String(v)])
//         ),
//       },
//       notification: {
//         title,
//         body,
//         icon,
//         badge: icon,
//         vibrate: [100, 50, 100],
//         // This is the URL FCM opens when user clicks the native browser notif.
//         // It acts as a fallback if the SW notificationclick handler doesn't fire.
//       },
//       fcmOptions: {
//         link: page, // deep-link for browser-managed clicks (fallback)
//       },
//     },

//     // ─── Android ────────────────────────────────────────────────────────────
//     android: {
//       notification: {
//         title,
//         body,
//         icon: "ic_notification", // drawable resource name in the Android app
//         sound: "default",
//         clickAction: "FLUTTER_NOTIFICATION_CLICK", // adjust to your app's action
//       },
//       data: {
//         page,
//         ...Object.fromEntries(
//           Object.entries(data ?? {}).map(([k, v]) => [k, String(v)])
//         ),
//       },
//     },

//     // ─── iOS (APNs) ─────────────────────────────────────────────────────────
//     apns: {
//       payload: {
//         aps: {
//           alert: { title, body },
//           sound: "default",
//           contentAvailable: true,
//           // Pass page in the custom payload so the iOS app can read it
//           page,
//         },
//       },
//     },
//   });
// }

export function isInvalidFcmTokenError(error: unknown): boolean {
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof (error as { code?: string }).code === "string"
  ) {
    const code = (error as { code: string }).code;
    return (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    );
  }

  if (
    typeof error === "object" &&
    error !== null &&
    "message" in error &&
    typeof (error as { message?: string }).message === "string"
  ) {
    const message = (error as { message: string }).message;
    return message.includes("not a valid FCM registration token");
  }

  return false;
}
