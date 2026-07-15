import { v2 as cloudinary } from "cloudinary";
import sharp from "sharp";
import streamifier from "streamifier";

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

interface UploadedFile {
  path?: string;
  buffer?: Buffer;
  originalname: string;
  mimetype?: string;
}

/**
 * Upload an image to Cloudinary.
 * @param file    - Multer file object (buffer or path)
 * @param folder  - sub-folder inside "tawreedat_go" e.g. "categories", "brands"
 */
const uploadImage = async (
  file: UploadedFile,
  folder?: string,
): Promise<string> => {
  const cloudinaryFolder = folder
    ? `tawreedat_go/${folder.replace(/^\/+/, "")}`
    : "tawreedat_go/uploads";

  // Resolve buffer
  let buffer: Buffer;
  if (file.buffer) {
    buffer = file.buffer;
  } else if (file.path) {
    const fs = await import("node:fs/promises");
    buffer = await fs.readFile(file.path);
    await fs.unlink(file.path).catch(() => {});
  } else {
    throw new Error("No file buffer or path provided");
  }

  const isPdf = file.mimetype === "application/pdf";

  let uploadBuffer: Buffer;
  let resourceType: "image" | "raw";
  let format: string | undefined;

  if (isPdf) {
    // PDFs go straight to Cloudinary as raw
    uploadBuffer = buffer;
    resourceType = "raw";
    format = undefined;
  } else {
    // Images: optimise with sharp → webp
    uploadBuffer = await sharp(buffer, {
      limitInputPixels: 268402689,
      sequentialRead: true,
    })
      .resize(2000, 2000, { fit: "inside", withoutEnlargement: true })
      .webp({ quality: 82 })
      .toBuffer();
    resourceType = "image";
    format = "webp";
  }

  // Stream upload to Cloudinary
  const secure_url = await new Promise<string>((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: cloudinaryFolder, resource_type: resourceType, ...(format ? { format } : {}) },
      (error, result) => {
        if (error || !result) return reject(error ?? new Error("Upload failed"));
        resolve(result.secure_url);
      },
    );
    streamifier.createReadStream(uploadBuffer).pipe(stream);
  });

  return secure_url;
};

export default uploadImage;
