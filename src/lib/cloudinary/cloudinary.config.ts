import { v2 as cloudinary } from "cloudinary";
import env from "../../config/env";

export const cloudinaryConfig = () => {
  cloudinary.config({
    cloud_name: env.CLOUD_NAME as string,
    api_key: env.API_KEY as string,
    api_secret: env.API_SECRET as string,
    secure: true,
  });
  return cloudinary;
};
