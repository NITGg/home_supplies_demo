import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";

export async function listLogsService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalLogs, logs] = await prisma.$transaction([
    prisma.log.count({ where: data.where as any }),
    prisma.log.findMany(data as any),
  ]);

  return {
    totalLogs,
    totalPages: Math.ceil(totalLogs / take),
    logs,
  };
}

export async function getLogByIdService(id: number) {
  const log = await prisma.log.findUnique({
    where: { id },
    include: { user: true },
  });

  if (!log) throw new HttpError(404, "logs:errors.not_found");
  return log;
}

/**
 * Deletes all logs where created_at is older than 1 month
 */
export async function deleteOldLogsService() {
  const oneMonthAgo = new Date();
  oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);

  const result = await prisma.log.deleteMany({
    where: {
      created_at: {
        lt: oneMonthAgo,
      },
    },
  });

  return { count: result.count };
}
