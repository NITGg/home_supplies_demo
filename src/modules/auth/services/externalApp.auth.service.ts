import bcrypt from "bcrypt";
import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { EXTERNAL_APP_EXPIRES_IN, signExternalAppToken } from "@/lib/jwt";

export async function issueExternalAppToken(
  clientId: string,
  clientSecret: string,
) {
  const app = await prisma.externalApp.findUnique({
    where: { client_id: clientId },
    select: {
      id: true,
      client_secret: true,
      is_active: true,
      environment: true,
      partner_id: true,
      contracts: {
        where: {
          is_active: true,
          start_date: { lte: new Date() },
          end_date: { gte: new Date() },
        },
        select: { id: true },
        take: 1,
      },
    },
  });

  if (!app)
    throw new HttpError(401, "external_apps:errors.invalid_credentials");

  const secretMatch = await bcrypt.compare(clientSecret, app.client_secret);
  if (!secretMatch)
    throw new HttpError(401, "external_apps:errors.invalid_credentials");

  if (!app.is_active || app.contracts.length === 0)
    throw new HttpError(403, "external_apps:errors.inactive");

  const access_token = signExternalAppToken({
    id: app.id,
    env: app.environment,
    partner_id: app.partner_id,
  });

  return {
    access_token,
    token_type: "Bearer",
    expires_in: EXTERNAL_APP_EXPIRES_IN,
  };
}
