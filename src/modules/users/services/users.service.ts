import bcrypt from "bcrypt";
import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type {
  CreateUserInput,
  DeleteUserInput,
  DeleteUsersInput,
  UpdateUserInput,
} from "../schemas/users.schema";
import FeatureApi from "@/lib/featureApi";
import {
  getCatalogLocationSettings,
  processCatalogByLocation,
  type CustomerLocation,
} from "@/lib/catalogLocation";
import { getOnlineUserIds } from "@/socket/status";
import { OrderStatus, Prisma, WalletOwnerType } from "@prisma/client";
import { getRoadDistanceM } from "@/lib/distance";
import { logger } from "@/config/logger";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
  destroyManyFiles,
} from "@/lib/cloudinary/cloudinary.service";
import http from "node:http";
import https from "node:https";

const COURIER_API_BASE =
  process.env.COURIER_API_BASE_URL ?? "http://localhost:3003";

function getCourierSocketUserIds(): Promise<number[]> {
  return new Promise((resolve) => {
    const url = `${COURIER_API_BASE}/api/v1/courier/internal/online-users`;
    const client = url.startsWith("https") ? https : http;
    const req = client.get(url, { timeout: 5000 }, (res) => {
      let body = "";
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => {
        try {
          const data = JSON.parse(body) as { userIds?: number[] };
          resolve(data.userIds ?? []);
        } catch {
          resolve([]);
        }
      });
    });
    req.on("error", () => resolve([]));
    req.on("timeout", () => {
      req.destroy();
      resolve([]);
    });
  });
}

async function getRoleOrThrow(role_id: number) {
  const role = await prisma.userRole.findUnique({
    where: { id: role_id },
    select: { id: true, name: true },
  });
  if (!role) throw new HttpError(400, "users:errors.role_not_found");
  return role;
}

async function getBadgeOrThrow(badge_id: number) {
  const badge = await prisma.userBadge.findUnique({
    where: { id: badge_id },
    select: { id: true, role_id: true },
  });
  if (!badge) throw new HttpError(400, "users:errors.badge_not_found");
  return badge;
}

async function getMinBadgeForRole(role_id: number) {
  const badge = await prisma.userBadge.findFirst({
    where: { role_id },
    orderBy: { min_count: "asc" },
    select: { id: true },
  });
  if (!badge) throw new HttpError(400, "users:errors.badge_not_found");
  return badge.id;
}

export async function createUserService(
  input: CreateUserInput,
  file?: Express.Multer.File,
) {
  if (input.email) {
    const exists = await prisma.user.findUnique({
      where: { email: input.email },
    });
    if (exists) throw new HttpError(409, "users:errors.email_exists");
  }

  if (input.phone) {
    const exists = await prisma.user.findUnique({
      where: { phone: input.phone },
    });
    if (exists) throw new HttpError(409, "users:errors.phone_exists");
  }
  const role = await getRoleOrThrow(input.role_id);

  // badge logic
  let badge_id: number | null = input.badge_id ?? null;

  // If role is Customer and badge not provided => min badge
  if (!badge_id && role.name.toLowerCase() === "customer") {
    badge_id = await getMinBadgeForRole(role.id);
  }

  // If badge provided, verify and ensure it belongs to role
  if (badge_id) {
    const badge = await getBadgeOrThrow(badge_id);
    if (badge.role_id !== role.id)
      throw new HttpError(400, "users:errors.badge_role_mismatch");
  }

  const hashedPassword = input.password
    ? await bcrypt.hash(input.password, 10)
    : null;

  let personal_photo: string | null = null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: `users/${role.name}`,
    });
    personal_photo = secure_url;
  }

  return prisma.user.create({
    data: {
      ...input,
      password: hashedPassword,
      badge_id,
      personal_photo,
      is_phone_verified: true,
      is_email_verified: !!input.email,
      wallet: {
        create: {
          owner_type: role.name === "Courier" ? "COURIER" : "CUSTOMER",
        },
      },
    },
  });
}

export async function listUsersService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  // 1. Clone the where clause to avoid mutating original data unexpectedly
  const whereClause = { ...(data.where ?? {}) };

  // 2. Intercept and extract 'is_settled' if it exists in the top-level filters
  if ("is_settled" in whereClause) {
    const isSettledValue = whereClause.is_settled;

    // Remove it from the root 'where' object so Prisma doesn't crash looking for user.is_settled
    delete whereClause.is_settled;

    // 3. Inject the filter deeply into the wallet -> walletEntries relation
    // This filters down to users who have AT LEAST ONE wallet entry matching that status
    whereClause.wallet = {
      walletEntries: {
        some: {
          is_settled: isSettledValue === true || isSettledValue === "true",
        },
      },
    };
  }

  // 4. Run the transaction with the updated where clause
  const [totalUsers, users] = await prisma.$transaction([
    prisma.user.count({ where: whereClause }),
    prisma.user.findMany({
      ...data,
      where: whereClause,
    } as any),
  ]);

  return {
    totalUsers,
    totalPages: Math.ceil(totalUsers / take),
    users,
  };
}

export async function getUserByIdService(data: FeatureApi["data"]) {
  const user = await prisma.user.findUnique(data as any);
  if (!user) throw new HttpError(404, "users:errors.user_not_found");
  return user;
}

function resolveWalletOwnerType(
  roleName: string | undefined,
  fallback: WalletOwnerType,
): WalletOwnerType {
  if (roleName === "Courier") return WalletOwnerType.COURIER;
  if (roleName === "Supplier") return WalletOwnerType.SUPPLIER;
  if (roleName === "Customer") return WalletOwnerType.CUSTOMER;
  return fallback;
}

function buildWalletUpsert(
  userId: number,
  exists: { role_id: number },
  newRole: { id: number; name: string } | undefined,
  walletData: NonNullable<UpdateUserInput["wallet"]>,
) {
  const roleChanged = newRole !== undefined && newRole.id !== exists.role_id;
  const ownerType = roleChanged
    ? resolveWalletOwnerType(
        newRole!.name,
        walletData.owner_type ?? WalletOwnerType.CUSTOMER,
      )
    : (walletData.owner_type ?? WalletOwnerType.CUSTOMER);

  return {
    upsert: {
      where: { user_id: userId },
      create: { owner_type: ownerType, ...walletData },
      update: walletData,
    },
  };
}

async function resolveRestoredCredentials(exists: {
  id: number;
  email: string | null;
  phone: string | null;
  google_id: string | null;
  apple_id: string | null;
}) {
  const candidateEmail = restoreField(exists.email);
  const candidatePhone = restoreField(exists.phone);
  const candidateGoogleId = restoreField(exists.google_id);
  const candidateAppleId = restoreField(exists.apple_id);

  const [emailOwner, phoneOwner, googleOwner, appleOwner] = await Promise.all([
    candidateEmail
      ? prisma.user.findFirst({
          where: { email: candidateEmail, id: { not: exists.id } },
          select: { id: true },
        })
      : null,
    candidatePhone
      ? prisma.user.findFirst({
          where: { phone: candidatePhone, id: { not: exists.id } },
          select: { id: true },
        })
      : null,
    candidateGoogleId
      ? prisma.user.findFirst({
          where: { google_id: candidateGoogleId, id: { not: exists.id } },
          select: { id: true },
        })
      : null,
    candidateAppleId
      ? prisma.user.findFirst({
          where: { apple_id: candidateAppleId, id: { not: exists.id } },
          select: { id: true },
        })
      : null,
  ]);

  return {
    email: emailOwner ? undefined : candidateEmail,
    phone: phoneOwner ? undefined : candidatePhone,
    google_id: googleOwner ? undefined : candidateGoogleId,
    apple_id: appleOwner ? undefined : candidateAppleId,
  };
}

async function resolvePersonalPhoto(
  exists: { personal_photo: string | null },
  deleteImage_flag: boolean,
  file: Express.Multer.File | undefined,
  roleName: string,
): Promise<string | null | undefined> {
  const hasNewFile = !!file;
  // TEMP DEBUG — remove when verified.
  console.log(
    "[UserUpdate][BE][photo] deleteImage:",
    deleteImage_flag,
    "| hasNewFile:",
    hasNewFile,
    "| current:",
    exists.personal_photo,
  );
  if ((deleteImage_flag || hasNewFile) && exists.personal_photo) {
    const publicId = extractPublicIdFromUrl(exists.personal_photo);
    if (publicId) {
      await destroySingleFile({ public_id: publicId }).catch((err) =>
        console.warn("Failed to delete image:", err),
      );
    }
  }
  if (deleteImage_flag) return null;
  if (hasNewFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file!.path, // .path or .buffer
      storagePathOnCloudinary: `users/${roleName}`,
    });
    return secure_url;
  }
  return undefined;
}

async function validateUniqueCredentials(
  userId: number,
  data: Pick<UpdateUserInput, "email" | "phone">,
) {
  const [emailOwner, phoneOwner] = await Promise.all([
    data.email
      ? prisma.user.findUnique({
          where: { email: data.email },
          select: { id: true },
        })
      : null,
    data.phone
      ? prisma.user.findUnique({
          where: { phone: data.phone },
          select: { id: true },
        })
      : null,
  ]);

  if (emailOwner && emailOwner.id !== userId)
    throw new HttpError(409, "users:errors.email_exists");
  if (phoneOwner && phoneOwner.id !== userId)
    throw new HttpError(409, "users:errors.phone_exists");
}

async function resolveRoleAndBadge(
  exists: { role_id: number },
  data: Pick<UpdateUserInput, "role_id" | "badge_id">,
): Promise<{
  newRole?: Awaited<ReturnType<typeof getRoleOrThrow>>;
  badge_id?: number;
}> {
  // No role change — just validate badge if provided
  if (!data.role_id) {
    if (data.badge_id != null) {
      const badge = await getBadgeOrThrow(data.badge_id);
      if (badge.role_id !== exists.role_id)
        throw new HttpError(400, "users:errors.badge_role_mismatch");
    }
    return {};
  }

  // Role is changing — fetch it once
  const newRole = await getRoleOrThrow(data.role_id);
  const roleChanged = newRole.id !== exists.role_id;

  if (data.badge_id != null) {
    // Badge explicitly provided — validate it belongs to the new role
    const badge = await getBadgeOrThrow(data.badge_id);
    if (badge.role_id !== newRole.id)
      throw new HttpError(400, "users:errors.badge_role_mismatch");
    return { newRole };
  }

  if (roleChanged) {
    // Role changed, no badge provided — assign lowest badge for new role
    const lowestBadge = await prisma.userBadge.findFirst({
      where: { role_id: newRole.id },
      orderBy: { min_count: "asc" },
      select: { id: true },
    });
    // If no badge exists for this role, create a default one
    const badge_id =
      lowestBadge?.id ??
      (
        await prisma.userBadge.create({
          data: {
            role_id: newRole.id,
            name: `${newRole.name} Default`,
            name_ar: "افتراضي",
            min_count: 0,
            max_count: 10,
            ratio: 1,
            image: "",
          },
          select: { id: true },
        })
      ).id;

    return { newRole, badge_id };
  }

  return { newRole };
}

export async function updateUserService(
  input: { id: number; data: UpdateUserInput },
  file?: Express.Multer.File,
) {
  const exists = await prisma.user.findUnique({
    where: { id: input.id },
    select: {
      id: true,
      personal_photo: true,
      role_id: true,
      role: { select: { name: true } },
      email: true,
      phone: true,
      google_id: true,
      apple_id: true,
      deleted_at: true,
      supplier: { select: { id: true, national_id_number: true } },
      courier: { select: { id: true, national_id_number: true } },
    },
  });
  if (!exists) throw new HttpError(404, "users:errors.user_not_found");

  await validateUniqueCredentials(input.id, input.data);
  const { newRole, badge_id } = await resolveRoleAndBadge(exists, input.data);

  const password = input.data.password
    ? await bcrypt.hash(input.data.password, 10)
    : undefined;
  const roleName = newRole?.name ?? exists.role.name;
  const personal_photo = await resolvePersonalPhoto(
    exists,
    input.data.deleteImage === true,
    file,
    roleName,
  );
  const isRestoring = !!exists.deleted_at && input.data.deleted_at === null;
  const restored = isRestoring ? await resolveRestoredCredentials(exists) : {};

  const { deleteImage: _del, wallet: walletData, ...rest } = input.data;

  // TEMP DEBUG — what actually gets written. Remove when verified.
  console.log("[UserUpdate][BE][service] final write →", {
    is_active: rest.is_active,
    personal_photo, // undefined = unchanged, null = cleared, string = new url
  });

  return prisma.$transaction(async (tx) => {
    const user = await tx.user.update({
      where: { id: input.id },
      data: {
        ...rest,
        ...(badge_id !== undefined ? { badge_id } : {}),
        ...(password ? { password, password_last_updated: new Date() } : {}),
        personal_photo,
        ...restored,
        ...(walletData
          ? { wallet: buildWalletUpsert(input.id, exists, newRole, walletData) }
          : {}),
      },
    });

    if (isRestoring) {
      if (exists.supplier)
        await tx.supplier.update({
          where: { id: exists.supplier.id },
          data: {
            deleted_at: null,
            national_id_number: restoreField(
              exists.supplier.national_id_number,
            ),
          },
        });
      if (exists.courier)
        await tx.courier.update({
          where: { id: exists.courier.id },
          data: {
            deleted_at: null,
            national_id_number: restoreField(exists.courier.national_id_number),
          },
        });
    }

    return user;
  });
}

const DELETED_PREFIX_RE = /^deleted:\d+:(.+)$/;

function archiveField(id: number, value: string | null | undefined) {
  if (!value || value.startsWith("deleted:")) return value ?? null;
  return `deleted:${id}:${value}`;
}

function restoreField(value: string | null | undefined) {
  if (!value) return null;
  const match = DELETED_PREFIX_RE.exec(value);
  return match ? match[1] : value;
}

// Cloudinary-backed image columns on the user and its related courier/supplier
// records. Selected so they can be purged when a user is permanently deleted.
const USER_IMAGE_SELECT = {
  personal_photo: true,
  courier: {
    select: {
      national_id_photo_front: true,
      national_id_photo_back: true,
      vehicle_license_front: true,
      vehicle_license_back: true,
      courier_license_front: true,
      courier_license_back: true,
      courier_criminal_record: true,
    },
  },
  supplier: {
    select: {
      national_id_photo_front: true,
      national_id_photo_back: true,
      supplier_criminal_record: true,
      tax_card: true,
      commercial_register: true,
    },
  },
} satisfies Prisma.UserSelect;

type UserImageRecord = Prisma.UserGetPayload<{
  select: typeof USER_IMAGE_SELECT;
}>;

/** Maps the image URLs on the given users to Cloudinary public_ids. */
function collectImagePublicIds(users: UserImageRecord[]): string[] {
  const ids: string[] = [];
  for (const u of users) {
    const urls = [
      u.personal_photo,
      u.courier?.national_id_photo_front,
      u.courier?.national_id_photo_back,
      u.courier?.vehicle_license_front,
      u.courier?.vehicle_license_back,
      u.courier?.courier_license_front,
      u.courier?.courier_license_back,
      u.courier?.courier_criminal_record,
      u.supplier?.national_id_photo_front,
      u.supplier?.national_id_photo_back,
      u.supplier?.supplier_criminal_record,
      u.supplier?.tax_card,
      u.supplier?.commercial_register,
    ];
    for (const url of urls) {
      if (!url) continue;
      const publicId = extractPublicIdFromUrl(url);
      if (publicId) ids.push(publicId);
    }
  }
  return ids;
}

/**
 * Best-effort Cloudinary purge. Deletes in batches of 100 (the
 * delete_resources limit) and never throws — a failed image cleanup must not
 * fail the user deletion that triggered it. Orphaned files beat a blocked DB op.
 */
async function purgeImages(publicIds: string[], context: string) {
  for (let i = 0; i < publicIds.length; i += 100) {
    await destroyManyFiles({ public_ids: publicIds.slice(i, i + 100) }).catch(
      (err) => console.warn(`[${context}] Cloudinary cleanup failed:`, err),
    );
  }
}

export async function deleteUserService(input: DeleteUserInput) {
  const user = await prisma.user.findUnique({
    where: { id: input.id },
    select: {
      id: true,
      email: true,
      phone: true,
      google_id: true,
      apple_id: true,
      supplier: { select: { id: true, national_id_number: true } },
      courier: { select: { id: true, national_id_number: true } },
    },
  });
  if (!user) throw new HttpError(404, "users:errors.user_not_found");

  if (input.archived) {
    await prisma.$transaction([
      prisma.user.update({
        where: { id: input.id },
        data: {
          deleted_at: new Date(),
          email: archiveField(input.id, user.email),
          phone: archiveField(input.id, user.phone),
          google_id: archiveField(input.id, user.google_id),
          apple_id: archiveField(input.id, user.apple_id),
        },
      }),
      ...(user.supplier
        ? [
            prisma.supplier.update({
              where: { id: user.supplier.id },
              data: {
                deleted_at: new Date(),
                national_id_number: archiveField(
                  input.id,
                  user.supplier.national_id_number,
                ),
              },
            }),
          ]
        : []),
      ...(user.courier
        ? [
            prisma.courier.update({
              where: { id: user.courier.id },
              data: {
                deleted_at: new Date(),
                national_id_number: archiveField(
                  input.id,
                  user.courier.national_id_number,
                ),
              },
            }),
          ]
        : []),
    ]);
    return { archived: true as const };
  }

  // ── Hard delete: purge related Cloudinary images, then remove the record ──
  // Read image URLs before deleting — the related courier/supplier rows are
  // removed by the cascade, so they can no longer be queried afterwards.
  const imageOwner = await prisma.user.findUnique({
    where: { id: input.id },
    select: USER_IMAGE_SELECT,
  });
  const publicIds = imageOwner ? collectImagePublicIds([imageOwner]) : [];

  await prisma.user.delete({ where: { id: input.id } });
  await purgeImages(publicIds, "deleteUserService");

  return { archived: false as const };
}

// ─── DELETE MANY ──────────────────────────────────────────────────────────────

export async function deleteUsersService(input: DeleteUsersInput) {
  if (input.archived) {
    const users = await prisma.user.findMany({
      where: { id: { in: input.ids } },
      select: {
        id: true,
        email: true,
        phone: true,
        google_id: true,
        apple_id: true,
        supplier: { select: { id: true, national_id_number: true } },
        courier: { select: { id: true, national_id_number: true } },
      },
    });

    await prisma.$transaction(
      users.flatMap((u) => [
        prisma.user.update({
          where: { id: u.id },
          data: {
            deleted_at: new Date(),
            email: archiveField(u.id, u.email),
            phone: archiveField(u.id, u.phone),
            google_id: archiveField(u.id, u.google_id),
            apple_id: archiveField(u.id, u.apple_id),
          },
        }),
        ...(u.supplier
          ? [
              prisma.supplier.update({
                where: { id: u.supplier.id },
                data: {
                  deleted_at: new Date(),
                  national_id_number: archiveField(
                    u.id,
                    u.supplier.national_id_number,
                  ),
                },
              }),
            ]
          : []),
        ...(u.courier
          ? [
              prisma.courier.update({
                where: { id: u.courier.id },
                data: {
                  deleted_at: new Date(),
                  national_id_number: archiveField(
                    u.id,
                    u.courier.national_id_number,
                  ),
                },
              }),
            ]
          : []),
      ]),
    );

    return { archived: true as const, count: users.length };
  }

  // Hard delete: read image URLs before the cascade removes related rows.
  const imageOwners = await prisma.user.findMany({
    where: { id: { in: input.ids } },
    select: USER_IMAGE_SELECT,
  });
  const publicIds = collectImagePublicIds(imageOwners);

  const result = await prisma.user.deleteMany({
    where: { id: { in: input.ids } },
  });
  await purgeImages(publicIds, "deleteUsersService");

  return { archived: false as const, count: result.count };
}

type GetOnlineCouriersParams = {
  order_lat?: number;
  order_lng?: number;
  take?: number; // how many final results
  skip?: number; // how many from SQL before Google (default 10)
};

export async function getOnlineCouriersService(
  params: GetOnlineCouriersParams = {},
) {
  const { order_lat, order_lng, take = 10, skip = 0 } = params;

  // Source 1: couriers connected to admin socket
  const adminSocketUserIds = getOnlineUserIds();

  // Source 2: couriers connected to courier socket (3003)
  const courierSocketUserIds = await getCourierSocketUserIds();

  // Source 3: couriers who updated location recently.
  // Use 60 min as the normal window so couriers who have the app open but are
  // idle (no active order) still appear. When BOTH socket sources are empty
  // (e.g. right after a server restart), use 2 hours as a wider fallback.
  const socketSourcesEmpty =
    adminSocketUserIds.length === 0 && courierSocketUserIds.length === 0;
  const ONLINE_WINDOW_MS = socketSourcesEmpty
    ? 2 * 60 * 60 * 1000 // 2-hour fallback when sockets just reset
    : 60 * 60 * 1000; // 60-min normal window
  const recentlyActive = await prisma.courier.findMany({
    where: {
      last_location_update: { gte: new Date(Date.now() - ONLINE_WINDOW_MS) },
      deleted_at: null,
      is_approved: true,
    },
    select: { user_id: true },
  });
  const recentUserIds = recentlyActive.map((c) => c.user_id);

  // Union all three sources
  const onlineUserIds = Array.from(
    new Set([...adminSocketUserIds, ...courierSocketUserIds, ...recentUserIds]),
  );

  logger.debug(
    `Online user IDs (adminSocket: ${adminSocketUserIds.length}, courierSocket: ${courierSocketUserIds.length}, recent: ${recentUserIds.length}, total: ${onlineUserIds.length})`,
  );

  if (!onlineUserIds.length) {
    return { total: 0, couriers: [] };
  }

  // ✅ If no location → fallback normal query
  if (!order_lat || !order_lng) {
    const couriers = await prisma.courier.findMany({
      where: {
        user_id: { in: onlineUserIds },
        deleted_at: null,
        is_approved: true,
      },
      take,
      skip,
      include: {
        user: {
          select: {
            id: true,
            full_name: true,
            phone: true,
            personal_photo: true,
          },
        },
      },
    });

    return {
      total: couriers.length,
      couriers,
    };
  }

  // ✅ Step 1: Get nearest couriers using SQL (cheap distance)
  const nearestCouriers = await prisma.$queryRaw<
    {
      id: number;
      user_id: number;
      lat: number;
      lng: number;
      full_name: string;
      phone: string;
      personal_photo: string | null;
      distance: number; // meters
    }[]
  >(
    Prisma.sql`
      SELECT
        c.id,
        c.user_id,
        c.lat,
        c.lng,
        u.full_name,
        u.phone,
        u.personal_photo,

        ST_Distance_Sphere(
          POINT(c.lng, c.lat),
          POINT(${order_lng}, ${order_lat})
        ) AS distance

      FROM courier c
      JOIN user u ON u.id = c.user_id

      WHERE
        c.user_id IN (${Prisma.join(onlineUserIds)})
        AND c.deleted_at IS NULL
        AND c.is_approved = true
        AND c.lat IS NOT NULL
        AND c.lng IS NOT NULL

      ORDER BY distance ASC
      LIMIT ${take}
      OFFSET ${skip}
    `,
  );

  if (!nearestCouriers.length) {
    return { total: 0, couriers: [] };
  }

  // ✅ Step 2: Get REAL road distance (Google API)
  const withRealDistance = await Promise.all(
    nearestCouriers.map(async (c) => {
      // 1. Check for active order
      const activeOrder = await prisma.order.findFirst({
        where: {
          courier_id: c.id,
          status: OrderStatus.IN_PROGRESS, // Adjust statuses as needed
        },
        select: { id: true }, // Only select ID to minimize overhead
      });

      // 2. Fetch distance (existing logic)
      try {
        const realDistance = await getRoadDistanceM(
          { lat: c.lat, lng: c.lng },
          { lat: order_lat, lng: order_lng },
        );
        logger.debug(
          `Real distance for courier ${c.id} (user ${c.full_name}): ${realDistance.distance} m, duration: ${realDistance.duration} s`,
        );

        return {
          ...c,
          real_distance: realDistance.distance, // meters
          duration: realDistance.duration, // seconds
          has_active_order: !!activeOrder,
        };
      } catch {
        return {
          ...c,
          real_distance: null,
          duration: null,
          has_active_order: !!activeOrder, // Added field
        };
      }
    }),
  );

  // ✅ Step 3: Sort by real distance
  withRealDistance.sort(
    (a, b) => (a.real_distance ?? Infinity) - (b.real_distance ?? Infinity),
  );

  return {
    total: withRealDistance.length,
    couriers: withRealDistance,
  };
}

export async function getSupplierByIdService(supplierId: number) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId, deleted_at: null },
    select: {
      id: true,
      is_approved: true,
      national_id_number: true,
      synonyms: true,
      tax_card: true,
      commercial_register: true,
      national_id_photo_front: true,
      national_id_photo_back: true,
      supplier_criminal_record: true,
      created_at: true,
      updated_at: true,
      user: {
        select: {
          id: true,
          full_name: true,
          phone: true,
          email: true,
          personal_photo: true,
          is_active: true,
          gender: true,
          lang: true,
          created_at: true,
          last_login_at: true,
        },
      },
      type: { select: { id: true, name: true, description: true } },
      addresses: {
        select: {
          id: true,
          address_line_1: true,
          address_line_2: true,
          city: true,
          state: true,
          country: true,
          google_map_link: true,
          latitude: true,
          longitude: true,
          contact_name: true,
          contact_phone: true,
          working_hours: true,
        },
      },
      stats: {
        select: {
          total_customers: true,
          total_orders: true,
          total_delivered_orders: true,
          total_cancelled_orders: true,
          total_active_products: true,
          last_order_date: true,
        },
      },
      categories: {
        select: {
          category: { select: { id: true, name: true, name_ar: true } },
        },
      },
    },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");

  const [customerAgg, courierAgg] = await Promise.all([
    prisma.supplierReviewFromCustomer.aggregate({
      where: { supplier_id: supplierId },
      _avg: { rating: true },
      _count: { rating: true },
    }),
    prisma.supplierReviewFromCourier.aggregate({
      where: { supplier_id: supplierId },
      _avg: { rating: true },
      _count: { rating: true },
    }),
  ]);

  const customerAvg = customerAgg._avg.rating ?? 0;
  const courierAvg = courierAgg._avg.rating ?? 0;
  const customerCount = customerAgg._count.rating;
  const courierCount = courierAgg._count.rating;
  const totalCount = customerCount + courierCount;
  const avg_rating =
    totalCount > 0
      ? (customerAvg * customerCount + courierAvg * courierCount) / totalCount
      : 0;

  return {
    ...supplier,
    avg_customer_rating: customerAvg,
    avg_courier_rating: courierAvg,
    avg_rating,
  };
}

// Always include user so full_name / phone / email are returned regardless of ?includes= param
function buildSupplierBaseInclude(data: FeatureApi["data"]) {
  return {
    ...(typeof data.include === "object" && data.include !== null
      ? (data.include as object)
      : {}),
    user: {
      select: {
        id: true,
        full_name: true,
        phone: true,
        email: true,
        personal_photo: true,
        is_active: true,
        created_at: true,
        last_login_at: true,
      },
    },
  };
}

// Attaches customer/courier rating aggregates to a page of suppliers.
async function attachSupplierRatings(suppliers: any[]) {
  const supplierIds = suppliers.map((s: any) => s.id);

  const [avgCustomerRatings, avgCourierRatings] = await Promise.all([
    prisma.supplierReviewFromCustomer.groupBy({
      by: ["supplier_id"],
      where: { supplier_id: { in: supplierIds } },
      _avg: { rating: true },
      _count: { rating: true },
    }),
    prisma.supplierReviewFromCourier.groupBy({
      by: ["supplier_id"],
      where: { supplier_id: { in: supplierIds } },
      _avg: { rating: true },
      _count: { rating: true },
    }),
  ]);

  const customerRatingMap = new Map(
    avgCustomerRatings.map((r) => [
      r.supplier_id,
      { avg: r._avg.rating ?? 0, count: r._count.rating ?? 0 },
    ]),
  );
  const courierRatingMap = new Map(
    avgCourierRatings.map((r) => [
      r.supplier_id,
      { avg: r._avg.rating ?? 0, count: r._count.rating ?? 0 },
    ]),
  );

  return suppliers.map((supplier: any) => {
    const customer = customerRatingMap.get(supplier.id) ?? { avg: 0, count: 0 };
    const courier = courierRatingMap.get(supplier.id) ?? { avg: 0, count: 0 };
    const totalCount = customer.count + courier.count;
    const avg_rating =
      totalCount > 0
        ? (customer.avg * customer.count + courier.avg * courier.count) /
          totalCount
        : 0;

    return {
      ...supplier,
      avg_customer_rating: customer.avg,
      avg_courier_rating: courier.avg,
      avg_rating,
    };
  });
}

export async function listSuppliersService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  const queryData: any = {
    ...data,
    include: buildSupplierBaseInclude(data),
  };

  const [totalSuppliers, suppliers] = await prisma.$transaction([
    prisma.supplier.count({ where: data.where }),
    prisma.supplier.findMany(queryData),
  ]);

  const suppliersWithRatings = await attachSupplierRatings(suppliers);

  return {
    totalSuppliers,
    totalPages: Math.ceil(totalSuppliers / take),
    suppliers: suppliersWithRatings,
  };
}

// Location-aware supplier listing (separate endpoint). Applies all three global
// ApplicationSetting controls (radius_km, same_governorate, cheapest_per_product)
// plus a nearest-first sort, using each supplier's first (oldest) store address.
export async function listSuppliersByLocationService(
  data: FeatureApi["data"],
  location?: CustomerLocation,
) {
  const take = data.take ?? 10;
  const skip = data.skip ?? 0;

  const settings = await getCatalogLocationSettings();

  const rows = await prisma.supplier.findMany({
    where: data.where,
    orderBy: data.orderBy,
    include: {
      ...buildSupplierBaseInclude(data),
      addresses: {
        orderBy: { created_at: "asc" },
        take: 1,
        select: {
          id: true,
          latitude: true,
          longitude: true,
          area: { select: { governorate_id: true } },
        },
      },
    },
  } as any);

  const processed = await processCatalogByLocation(
    rows,
    (s: any) => {
      const address = s.addresses?.[0] ?? null;
      return {
        lat: address?.latitude != null ? Number(address.latitude) : null,
        lng: address?.longitude != null ? Number(address.longitude) : null,
        governorateId: address?.area?.governorate_id ?? null,
      };
    },
    location,
    settings,
    // All three customer_home_products_* settings apply here. cheapest only
    // reorders duplicates that share a product_id; a supplier list has no
    // product dimension, so in practice it is a no-op for suppliers.
    { sortByDistance: true },
  );

  const totalSuppliers = processed.length;
  const page = processed.slice(skip, skip + take);
  const distanceById = new Map<number, number | null>(
    page.map(({ item, distanceKm }) => [(item as any).id, distanceKm]),
  );

  const suppliersWithRatings = await attachSupplierRatings(
    page.map((p) => p.item),
  );

  return {
    totalSuppliers,
    totalPages: Math.ceil(totalSuppliers / take),
    suppliers: suppliersWithRatings.map((s: any) => ({
      ...s,
      distance_km: distanceById.get(s.id) ?? null,
    })),
  };
}

export async function createSupplierAddressService(
  supplierId: number,
  data: Record<string, any>,
) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");
  return prisma.supplierStoreAddress.create({
    data: { supplier_id: supplierId, ...data },
  });
}

export async function updateSupplierAddressService(
  supplierId: number,
  addressId: number,
  data: Record<string, any>,
) {
  const address = await prisma.supplierStoreAddress.findFirst({
    where: { id: addressId, supplier_id: supplierId },
  });
  if (!address) throw new HttpError(404, "Address not found");
  return prisma.supplierStoreAddress.update({
    where: { id: addressId },
    data,
  });
}

export async function getSupplierCategoriesService(supplierId: number) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId, deleted_at: null },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");

  const rows = await prisma.supplierCategory.findMany({
    where: { supplier_id: supplierId, deleted_at: null },
    select: {
      category: {
        select: {
          id: true,
          name: true,
          name_ar: true,
          image_url: true,
          icon_url: true,
        },
      },
    },
    orderBy: { created_at: "asc" },
  });
  return rows.map((r) => r.category);
}

export async function getSupplierProductsService(supplierId: number) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId, deleted_at: null },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");

  return prisma.supplierProduct.findMany({
    where: { supplier_id: supplierId, deleted_at: null },
    select: {
      id: true,
      price: true,
      cost_price: true,
      stock: true,
      min_stock: true,
      is_active: true,
      is_featured: true,
      is_best_seller: true,
      pickup_ready_duration: true,
      created_at: true,
      product: {
        select: {
          id: true,
          name: true,
          name_ar: true,
          sku: true,
          images: true,
          category: { select: { id: true, name: true, name_ar: true } },
        },
      },
    },
    orderBy: { created_at: "desc" },
  });
}

export async function approveSupplierService(supplierId: number) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");
  return prisma.supplier.update({
    where: { id: supplierId },
    data: { is_approved: true },
    select: {
      id: true,
      is_approved: true,
      user: { select: { id: true, full_name: true } },
    },
  });
}

export async function rejectSupplierService(supplierId: number) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");
  return prisma.supplier.update({
    where: { id: supplierId },
    data: { is_approved: false },
    select: {
      id: true,
      is_approved: true,
      user: { select: { id: true, full_name: true } },
    },
  });
}

export async function updateSupplierService(
  supplierId: number,
  data: Record<string, string | undefined>,
) {
  const supplier = await prisma.supplier.findUnique({
    where: { id: supplierId },
    select: { id: true, user_id: true },
  });
  if (!supplier) throw new HttpError(404, "users:errors.supplier_not_found");

  const USER_FIELDS = new Set([
    "full_name",
    "email",
    "phone",
    "personal_photo",
  ]);
  // Fields that must be stored as Float in the DB
  const FLOAT_SUPPLIER_FIELDS = new Set(["markup_ratio"]);

  const userFields: Record<string, string> = {};
  const supplierFields: Record<string, any> = {};

  for (const [k, v] of Object.entries(data)) {
    if (v === undefined || v === "") continue; // skip empty — avoids P2002 on unique fields
    if (USER_FIELDS.has(k)) {
      userFields[k] = v;
    } else if (FLOAT_SUPPLIER_FIELDS.has(k)) {
      supplierFields[k] = Number.parseFloat(v);
    } else {
      supplierFields[k] = v;
    }
  }

  return prisma.$transaction(async (tx) => {
    if (Object.keys(userFields).length > 0) {
      await tx.user.update({
        where: { id: supplier.user_id },
        data: userFields,
      });
    }
    return tx.supplier.update({
      where: { id: supplierId },
      data: Object.keys(supplierFields).length > 0 ? supplierFields : {},
      select: {
        id: true,
        is_approved: true,
        national_id_number: true,
        synonyms: true,
        tax_card: true,
        commercial_register: true,
        markup_ratio: true,
        created_at: true,
        user: {
          select: {
            id: true,
            full_name: true,
            phone: true,
            email: true,
            personal_photo: true,
          },
        },
      },
    });
  });
}

export async function updateCourierLocation(
  courierId: number,
  lat: number,
  lng: number,
) {
  const courier = await prisma.courier.findUnique({
    where: { id: courierId },
    select: { id: true, deleted_at: true, is_approved: true },
  });

  if (!courier || courier.deleted_at) {
    throw new HttpError(404, "courier:errors.not_found");
  }

  if (!courier.is_approved) {
    throw new HttpError(403, "courier:errors.not_approved");
  }

  return prisma.courier.update({
    where: { id: courierId },
    data: {
      lat,
      lng,
      last_location_update: new Date(),
    },
  });
}
