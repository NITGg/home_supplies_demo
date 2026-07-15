import { firebaseDB } from "./firebase";
import logger from "../../config/logger.config";
import { prisma } from "../../DB/lib/prisma";
import { isInvalidFcmTokenError, sendFcmMessage } from "./sendFcmMessage";
import { i18n } from "../../bootstrap";

export type AppLang = "en" | "ar";

export type NotificationUser = {
  id: number;
  lang?: string | null;
  fcm_token?: string | null;
};

type LocalizedText = {
  en: string;
  ar: string;
};

type NotificationContentByKeys = {
  titleKey: string;
  bodyKey: string;
  titleParams?: Record<string, unknown>;
  bodyParams?: Record<string, unknown>;
};

type NotificationContentByText = {
  title: LocalizedText;
  body: LocalizedText;
};

export type NotificationContent =
  | NotificationContentByKeys
  | NotificationContentByText;

export type NotificationPayload = {
  page?: string;
  navigate?: string;
  [key: string]: string | number | boolean | undefined | null;
};

export type NotifyOneInput = {
  user: NotificationUser;
  content: NotificationContent;
  data?: NotificationPayload | undefined;
};

export type NotifyManyInput = {
  users: NotificationUser[];
  content: NotificationContent;
  data?: NotificationPayload | undefined;
};

function normalizeLang(lang?: string | null): AppLang {
  return String(lang).toLowerCase() === "en" ? "en" : "ar";
}

function t(lang: AppLang, key: string): string {
  return i18n.__({ phrase: key, locale: lang });
}

function toFcmData(data?: NotificationPayload): Record<string, string> {
  if (!data) return {};

  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)]),
  );
}

function isKeyBasedContent(
  content: NotificationContent,
): content is NotificationContentByKeys {
  return "titleKey" in content && "bodyKey" in content;
}

function resolveNotificationContent(content: NotificationContent) {
  if (isKeyBasedContent(content)) {
    return {
      titleEn: t("en", content.titleKey),
      titleAr: t("ar", content.titleKey),
      descEn: t("en", content.bodyKey),
      descAr: t("ar", content.bodyKey),
    };
  }

  return {
    titleEn: content.title.en,
    titleAr: content.title.ar,
    descEn: content.body.en,
    descAr: content.body.ar,
  };
}

async function createNotificationDoc(params: {
  userId: number;
  title: string;
  titleAr: string;
  desc: string;
  descAr: string;
  delivered: boolean;
  data?: NotificationPayload;
}) {
  const docRef = await firebaseDB.collection("Notifications").add({
    user_id: params.userId,
    title: params.title,
    title_ar: params.titleAr,
    desc: params.desc,
    desc_ar: params.descAr,
    is_read: false,
    delivered_at: params.delivered ? new Date() : null,
    created_at: new Date(),
    data: params.data ?? {},
  });

  return docRef;
}

async function markNotificationUndelivered(notificationId: string) {
  await firebaseDB.collection("Notifications").doc(notificationId).update({
    delivered_at: null,
  });
}

export async function notifyUser({
  user,
  content,
  data = {
    page: "/",
    navigate: "home",
  },
}: NotifyOneInput) {
  const userId = user.id;

  const { titleEn, titleAr, descEn, descAr } =
    resolveNotificationContent(content);

  const notificationRef = await createNotificationDoc({
    userId,
    title: titleEn,
    titleAr,
    desc: descEn,
    descAr,
    delivered: Boolean(user.fcm_token),
    data,
  });

  const payloadData = toFcmData({
    ...data,
    notificationId: notificationRef.id,
  });

  logger.info(user, `hi my id is ${user.id}`);
  if (!user.fcm_token) {
    return {
      success: true,
      delivered: false,
      notificationId: notificationRef.id,
    };
  }

  const lang = normalizeLang(user.lang);
  const title = lang === "en" ? titleEn : titleAr;
  const body = lang === "en" ? descEn : descAr;

  try {
    const fcm = await sendFcmMessage({
      token: user.fcm_token,
      title,
      body,
      data: payloadData,
    });
    logger.info(`fcm from user id ${user.id}: ${fcm}`);

    return {
      success: true,
      delivered: true,
      notificationId: notificationRef.id,
    };
  } catch (error) {
    console.log(error);

    if (isInvalidFcmTokenError(error)) {
      await Promise.allSettled([
        markNotificationUndelivered(notificationRef.id),
        prisma.user.update({
          where: { id: userId },
          data: { fcm_token: null },
        }),
      ]);
    }

    return {
      success: false,
      delivered: false,
      notificationId: notificationRef.id,
      error,
    };
  }
}

export async function notifyUsers({ users, content, data }: NotifyManyInput) {
  return Promise.allSettled(
    users.map((user) =>
      notifyUser({
        user,
        content,
        data,
      }),
    ),
  );
}

export async function notifyAdminsExcept(
  userIdsToSkip: number[],
  content: NotificationContent,
  data?: NotificationPayload,
) {
  const admins = await prisma.user.findMany({
    where: {
      role: { name: "admin" },
      id: { notIn: userIdsToSkip },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });

  return notifyUsers({
    users: admins,
    content,
    data,
  });
}

type NotifyProgress = {
  processed: number;
  total: number;
  successCount: number;
  failCount: number;
  deliveredCount: number;
  storedOnlyCount: number;
};

type NotifyUsersStreamInput = {
  users: NotificationUser[];
  content: NotificationContent;
  data?: NotificationPayload;
  chunkSize?: number;
  onProgress?: (progress: NotifyProgress) => Promise<void> | void;
};

export async function notifyUsersStream({
  users,
  content,
  data,
  chunkSize = 50,
  onProgress,
}: NotifyUsersStreamInput) {
  let processed = 0;
  let successCount = 0;
  let failCount = 0;
  let deliveredCount = 0;
  let storedOnlyCount = 0;

  for (let i = 0; i < users.length; i += chunkSize) {
    const chunk = users.slice(i, i + chunkSize);

    const results = await Promise.allSettled(
      chunk.map((user) =>
        notifyUser({
          user,
          content,
          data,
        }),
      ),
    );

    for (const result of results) {
      processed += 1;

      if (result.status === "fulfilled") {
        if (result.value.success) {
          successCount += 1;

          if (result.value.delivered) {
            deliveredCount += 1;
          } else {
            storedOnlyCount += 1;
          }
        } else {
          failCount += 1;
        }
      } else {
        failCount += 1;
      }
    }

    await onProgress?.({
      processed,
      total: users.length,
      successCount,
      failCount,
      deliveredCount,
      storedOnlyCount,
    });
  }

  return {
    totalUsers: users.length,
    processed,
    successCount,
    failCount,
    deliveredCount,
    storedOnlyCount,
  };
}
