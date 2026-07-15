import { prisma } from "../config/prisma";

const getAdminUsers = async () => {
  return prisma.user.findMany({
    where: {
      is_active: true,
      deleted_at: null,
      role: {
        name: "Admin",
      },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });
};

export default getAdminUsers;
