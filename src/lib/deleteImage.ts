import { v2 as cloudinary } from "cloudinary";
import fs from "fs/promises";
import path from "path";

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/**
 * Delete an image from Cloudinary (if it's a Cloudinary URL) or from the local filesystem.
 */
const deleteImage = async (
  fileUrl: string | null | undefined,
): Promise<boolean> => {
  try {
    if (!fileUrl) return false;

    // Handle Cloudinary URLs (res.cloudinary.com)
    if (fileUrl.includes("res.cloudinary.com")) {
      // Extract public_id from the URL
      // e.g. https://res.cloudinary.com/<cloud>/image/upload/v123/tawreedat_go/categories/abc.webp
      // public_id = tawreedat_go/categories/abc  (no extension)
      const url = new URL(fileUrl);
      // pathname: /dzkezctec/image/upload/v.../tawreedat_go/categories/abc.webp
      const parts = url.pathname.split("/");
      // Find the index after "upload" (skip version segment if present)
      const uploadIdx = parts.indexOf("upload");
      if (uploadIdx === -1) return false;

      // Parts after upload: ["v1234567890", "tawreedat_go", "categories", "abc.webp"]
      // or without version:  ["tawreedat_go", "categories", "abc.webp"]
      let publicParts = parts.slice(uploadIdx + 1);
      // Remove version segment (starts with "v" followed by digits)
      if (/^v\d+$/.test(publicParts[0])) publicParts = publicParts.slice(1);
      // Remove file extension from last part
      const last = publicParts[publicParts.length - 1];
      publicParts[publicParts.length - 1] = last.replace(/\.[^/.]+$/, "");
      const publicId = publicParts.join("/");

      const result = await cloudinary.uploader.destroy(publicId);
      return result.result === "ok";
    }

    // Local file fallback
    let filePath: string;
    if (fileUrl.startsWith("/uploads/")) {
      filePath = fileUrl.replace(/^\//, "");
    } else if (fileUrl.startsWith("http")) {
      const url = new URL(fileUrl);
      filePath = url.pathname.replace(/^\//, "");
    } else {
      filePath = fileUrl;
    }

    const absolutePath = path.join(__dirname, "..", filePath);
    try {
      await fs.access(absolutePath);
      await fs.unlink(absolutePath);
      return true;
    } catch (err: any) {
      if (err.code === "ENOENT") {
        console.warn("File not found:", absolutePath);
        return false;
      }
      console.error("Delete error:", err.message);
      return false;
    }
  } catch (error: any) {
    console.error("Unexpected delete error:", error.message);
    return false;
  }
};

export default deleteImage;
