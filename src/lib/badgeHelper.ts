import { Tx } from "@/types/prisma.types";

type Input =
  | { kind: "CUSTOMER"; userId: number }
  | { kind: "COURIER"; courierId: number };

type BadgeResult = {
  deliveredCount: number;
  userId: number;
  changed: boolean;
  previousBadge: {
    id: number | null;
    name: string | null;
    name_ar: string | null;
  } | null;
  currentBadge: {
    id: number | null;
    name: string | null;
    name_ar: string | null;
  } | null;
};

export async function updateBadgeFromDeliveredCount(
  tx: Tx,
  input: Input,
): Promise<BadgeResult | null> {
  let userId: number;
  let roleId: number;
  let currentBadgeId: number | null;
  let currentBadgeRange: { min_count: number; max_count: number } | null = null;

  let currentBadgeInfo: {
    id: number | null;
    name: string | null;
    name_ar: string | null;
  } | null = null;

  let deliveredCount: number;

  if (input.kind === "CUSTOMER") {
    const user = await tx.user.findUnique({
      where: { id: input.userId },
      select: {
        id: true,
        role_id: true,
        badge_id: true,
        badge: {
          select: {
            id: true,
            name: true,
            name_ar: true,
            min_count: true,
            max_count: true,
          },
        },
      },
    });
    if (!user) return null;

    userId = user.id;
    roleId = user.role_id;
    currentBadgeId = user.badge_id;
    currentBadgeRange = user.badge
      ? {
          min_count: Number(user.badge.min_count),
          max_count: Number(user.badge.max_count),
        }
      : null;

    currentBadgeInfo = user.badge
      ? {
          id: user.badge.id,
          name: user.badge.name,
          name_ar: user.badge.name_ar,
        }
      : null;

    deliveredCount = await tx.order.count({
      where: { customer_id: userId, status: "DELIVERED" },
    });
  } else {
    const courier = await tx.courier.findUnique({
      where: { id: input.courierId },
      select: {
        id: true,
        user: {
          select: {
            id: true,
            role_id: true,
            badge_id: true,
            badge: {
              select: {
                id: true,
                name: true,
                name_ar: true,
                min_count: true,
                max_count: true,
              },
            },
          },
        },
      },
    });
    if (!courier?.user) return null;

    userId = courier.user.id;
    roleId = courier.user.role_id;
    currentBadgeId = courier.user.badge_id;
    currentBadgeRange = courier.user.badge
      ? {
          min_count: Number(courier.user.badge.min_count),
          max_count: Number(courier.user.badge.max_count),
        }
      : null;

    currentBadgeInfo = courier.user.badge
      ? {
          id: courier.user.badge.id,
          name: courier.user.badge.name,
          name_ar: courier.user.badge.name_ar,
        }
      : null;

    deliveredCount = await tx.order.count({
      where: { courier_id: input.courierId, status: "DELIVERED" },
    });
  }

  const baseBadge = await tx.userBadge.findFirst({
    where: { role_id: roleId },
    orderBy: { min_count: "asc" },
    select: {
      id: true,
      name: true,
      name_ar: true,
      min_count: true,
      max_count: true,
    },
  });

  if (!baseBadge) return null;

  const previousBadge = currentBadgeInfo;

  if (!currentBadgeId) {
    await tx.user.update({
      where: { id: userId },
      data: { badge_id: baseBadge.id },
      select: { id: true },
    });

    currentBadgeId = baseBadge.id;
    currentBadgeRange = {
      min_count: Number(baseBadge.min_count),
      max_count: Number(baseBadge.max_count),
    };
    currentBadgeInfo = {
      id: baseBadge.id,
      name: baseBadge.name,
      name_ar: baseBadge.name_ar,
    };
  }

  const currentMax = currentBadgeRange?.max_count ?? -1;
  if (deliveredCount <= currentMax) {
    return {
      deliveredCount,
      userId,
      changed: false,
      previousBadge,
      currentBadge: currentBadgeInfo,
    };
  }

  const matching = await tx.userBadge.findFirst({
    where: {
      role_id: roleId,
      min_count: { lte: deliveredCount },
      max_count: { gte: deliveredCount },
    },
    orderBy: { min_count: "desc" },
    select: {
      id: true,
      name: true,
      name_ar: true,
    },
  });

  if (matching && matching.id !== currentBadgeId) {
    await tx.user.update({
      where: { id: userId },
      data: { badge_id: matching.id },
      select: { id: true },
    });

    return {
      deliveredCount,
      userId,
      changed: true,
      previousBadge,
      currentBadge: {
        id: matching.id,
        name: matching.name,
        name_ar: matching.name_ar,
      },
    };
  }

  return {
    deliveredCount,
    userId,
    changed: false,
    previousBadge,
    currentBadge: currentBadgeInfo,
  };
}
