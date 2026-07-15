import { cloudMessaging } from "./firebase";

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
      title,
      body,
    },
    ...(data !== undefined && { data }),
  });
}

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
