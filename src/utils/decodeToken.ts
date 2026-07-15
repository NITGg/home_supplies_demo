import { NextFunction } from "express";
import { MyJwtPayload, verifyJwt } from "./jwt";
import { AppError } from "../core/errors/app.error";
import { HttpStatusCode } from "../core/http/http.status.code";
import { prisma } from "../DB/lib/prisma";

export enum TokenTypesEnum {
  access = "access",
  refresh = "refresh",
}

export const decodeToken = async ({
  authorization,
  tokenType = TokenTypesEnum.access,
}: {
  authorization: string;
  tokenType?: TokenTypesEnum;
}) => {
  // step: bearer key
  if (!authorization.startsWith(process.env.BEARER_KEY as string)) {
    throw new AppError(HttpStatusCode.BAD_REQUEST, "Invalid bearer key");
  }
  // step: token validation
  let [bearer, token] = authorization.split(" ");

  // step: check authorization existence
  if (!token || token == null) {
    throw new AppError(HttpStatusCode.BAD_REQUEST, "Invalid authorization");
  }
  let privateKey = "";
  if (tokenType == TokenTypesEnum.access) {
    privateKey = process.env.ACCESS_SEGNATURE as string;
  } else if (tokenType == TokenTypesEnum.refresh) {
    privateKey = process.env.REFRESH_SEGNATURE as string;
  }
  let payload = verifyJwt({ token, privateKey }); // result || error

  // step: user existence (now using User table with courier include)
  const user = await prisma.user.findUnique({
    where: { id: payload.userId ?? (payload as any).id },
    include: { courier: true, role: true },
  });
  if (!user) {
    throw new AppError(HttpStatusCode.NOT_FOUND, "User not found");
  }

  // step: credentials changing
  if (user.password_last_updated) {
    if (user.password_last_updated.getTime() > payload.iat * 1000) {
      throw new AppError(HttpStatusCode.BAD_REQUEST, "You have to login");
    }
  }

  // step: return user & payload
  return { user, payload };
};
