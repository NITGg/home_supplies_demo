import CryptoJS from "crypto-js";
import { env } from "../config/env";

export const encrypt = (plainText: string) => {
  return CryptoJS.AES.encrypt(
    plainText,
    env.PRIVATE_KEY as string
  ).toString();
};
export const decrypt = (cyphertext: string) => {
  return CryptoJS.AES.decrypt(
    cyphertext,
    env.PRIVATE_KEY as string
  ).toString(CryptoJS.enc.Utf8);
};
