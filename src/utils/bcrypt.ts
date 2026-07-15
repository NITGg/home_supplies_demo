import bcrypt from "bcrypt";
import { env } from "../config/env";

export const hash = async (plainText: string): Promise<string> => {
  return await bcrypt.hash(plainText, Number(env.SALAT));
};

export const compare = async (
  plainText: string,
  hashedText: string
): Promise<boolean> => {
  return await bcrypt.compare(plainText, hashedText);
};
