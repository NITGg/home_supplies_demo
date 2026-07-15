import { prisma } from "@/config/prisma";
import {
  notifyUsers,
  notifyUsersStream,
} from "@/services/notification.service";
import { SendNotificationInput } from "./notifications.schema";

function uniqueIds(ids: number[]) {
  return [...new Set(ids)];
}

async function getUsersByRecipient(input: SendNotificationInput) {
  const baseWhere = {
    is_active: true,
    deleted_at: null,
  } as const;

  if (input.recipientType === "all") {
    return prisma.user.findMany({
      where: baseWhere,
      select: {
        id: true,
        lang: true,
        fcm_token: true,
      },
    });
  }

  if (input.recipientType === "users") {
    return prisma.user.findMany({
      where: {
        ...baseWhere,
        id: {
          in: uniqueIds(input.userIds ?? []),
        },
      },
      select: {
        id: true,
        lang: true,
        fcm_token: true,
      },
    });
  }

  return prisma.user.findMany({
    where: {
      ...baseWhere,
      role: {
        name: {
          in: input.roles,
        },
      },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });
}

export async function sendAdminNotificationService(
  input: SendNotificationInput,
) {
  const users = await getUsersByRecipient(input);

  if (users.length === 0) {
    return {
      totalUsers: 0,
      successCount: 0,
      failCount: 0,
      deliveredCount: 0,
      storedOnlyCount: 0,
    };
  }

  const results = await notifyUsers({
    users,
    content: input.content,
    data: input.data,
  });

  let successCount = 0;
  let failCount = 0;
  let deliveredCount = 0;
  let storedOnlyCount = 0;

  for (const result of results) {
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

  return {
    totalUsers: users.length,
    successCount,
    failCount,
    deliveredCount,
    storedOnlyCount,
  };
}

export async function sendAdminNotificationStreamService(
  input: SendNotificationInput,
  onProgress?: (progress: {
    processed: number;
    total: number;
    successCount: number;
    failCount: number;
    deliveredCount: number;
    storedOnlyCount: number;
  }) => Promise<void> | void,
) {
  const users = await getUsersByRecipient(input);

  if (users.length === 0) {
    const emptyResult = {
      totalUsers: 0,
      processed: 0,
      successCount: 0,
      failCount: 0,
      deliveredCount: 0,
      storedOnlyCount: 0,
    };

    await onProgress?.({
      processed: 0,
      total: 0,
      successCount: 0,
      failCount: 0,
      deliveredCount: 0,
      storedOnlyCount: 0,
    });

    return emptyResult;
  }

  return notifyUsersStream({
    users,
    content: input.content,
    data: input.data,
    chunkSize: 50,
    onProgress,
  });
}
