import { cloudinaryConfig } from "./cloudinary.config";
import env from "../../config/env";

// ============================ uploadSingleFile ============================
export const uploadSingleFile = async ({
  fileLocation,
  storagePathOnCloudinary = `${env.APP_NAME}`,
}: {
  fileLocation: string;
  storagePathOnCloudinary: string;
}) => {
  const { public_id, secure_url } = await cloudinaryConfig().uploader.upload(
    fileLocation,
    {
      folder: `${env.APP_NAME}/${storagePathOnCloudinary}`,
      resource_type: "auto",
      // Shrinks image to max width if it's larger, leaving smaller images alone
      transformation: [
        { width: env.CLOUDINARY_MAX_IMAGE_WIDTH, crop: "limit" },
      ],
    },
  );

  return { public_id, secure_url };
};

// ============================ uploadSingleBuffer ============================
export const uploadSingleBuffer = async ({
  fileBuffer,
  storagePathOnCloudinary = `${env.APP_NAME}`,
}: {
  fileBuffer: Buffer;
  storagePathOnCloudinary: string;
}) => {
  return new Promise<{ public_id: string; secure_url: string }>(
    (resolve, reject) => {
      const uploadStream = cloudinaryConfig().uploader.upload_stream(
        {
          folder: `${env.APP_NAME}/${storagePathOnCloudinary}`,
          resource_type: "auto",
          // Shrinks image to max width if it's larger, leaving smaller images alone
          transformation: [
            { width: env.CLOUDINARY_MAX_IMAGE_WIDTH, crop: "limit" },
          ],
        },
        (error, result) => {
          if (error) return reject(error);
          if (result) {
            resolve({
              public_id: result.public_id,
              secure_url: result.secure_url,
            });
          }
        },
      );

      // End the stream with the buffer
      uploadStream.end(fileBuffer);
    },
  );
};

// ============================ uploadManyFiles ============================
export const uploadManyFiles = async ({
  fileLocationArr = [],
  storagePathOnCloudinary = `${env.APP_NAME}`,
}: {
  fileLocationArr: string[];
  storagePathOnCloudinary: string;
}) => {
  const images = [];
  for (const item of fileLocationArr) {
    const { public_id, secure_url } = await uploadSingleFile({
      fileLocation: item,
      storagePathOnCloudinary,
    });
    images.push({ public_id, secure_url });
  }
  return images;
};

// ============================ uploadManyBuffers ============================
export const uploadManyBuffers = async ({
  fileBufferArr = [],
  storagePathOnCloudinary = `${env.APP_NAME}`,
}: {
  fileBufferArr: Buffer[];
  storagePathOnCloudinary: string;
}) => {
  const images = [];
  for (const item of fileBufferArr) {
    const { public_id, secure_url } = await uploadSingleBuffer({
      fileBuffer: item,
      storagePathOnCloudinary,
    });
    images.push({ public_id, secure_url });
  }
  return images;
};

// ============================ destroySingleFile ============================
export const destroySingleFile = async ({
  public_id,
}: {
  public_id: string;
}) => {
  await cloudinaryConfig().uploader.destroy(public_id);
};

// ============================ destroyManyFiles ============================
export const destroyManyFiles = async ({
  public_ids = [],
}: {
  public_ids: string[];
}) => {
  await cloudinaryConfig().api.delete_resources(public_ids);
};

// ============================ deleteByPrefix ============================
export const deleteByPrefix = async ({
  storagePathOnCloudinary,
}: {
  storagePathOnCloudinary: string;
}) => {
  await cloudinaryConfig().api.delete_resources_by_prefix(
    `${env.APP_NAME}/${storagePathOnCloudinary}`,
  );
};

// ============================ deleteFolder ============================
export const deleteFolder = async ({
  storagePathOnCloudinary,
}: {
  storagePathOnCloudinary: string;
}) => {
  await cloudinaryConfig().api.delete_folder(
    `${env.APP_NAME}/${storagePathOnCloudinary}`,
  );
};

// ============================ extractPublicIdFromUrl ============================
export const extractPublicIdFromUrl = (secureUrl: string): string | null => {
  try {
    // Example URL: https://res.cloudinary.com/demo/image/upload/v1234567890/Tawreedat/suppliers/abc123xyz.jpg
    const parts = secureUrl.split("/upload/");
    if (parts.length !== 2 || !parts[1]) return null;

    // Remove the version number (v1234567890/) and the file extension (.jpg)
    const publicIdWithExtension = parts[1].replace(/^v\d+\//, ""); // Removes 'v1234567890/'
    const publicId = publicIdWithExtension.replace(/\.[^/.]+$/, ""); // Removes '.jpg' or '.png'

    return publicId; // Returns: "Tawreedat/suppliers/abc123xyz"
  } catch (error) {
    return null;
  }
};
