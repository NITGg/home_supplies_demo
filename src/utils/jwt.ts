import { JwtPayload, Secret, sign, SignOptions, verify } from "jsonwebtoken";

export interface MyJwtPayload {
  userId: number;
  userPhone: string;
  iat: number;
  exp: number;
  jti: string;
}

export const createJwt = (
  payload: string | object,
  privateKey: Secret,
  options?: SignOptions,
) => {
  const token = sign(payload, privateKey, options);
  return token;
};

export const verifyJwt = ({
  token,
  privateKey,
}: {
  token: string;
  privateKey: Secret;
}): MyJwtPayload => {
  const payload = verify(token, privateKey, {
    algorithms: ["HS256"],
  }) as MyJwtPayload; // result || error
  return payload;
};
