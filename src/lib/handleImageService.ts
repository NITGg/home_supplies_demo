import uploadImage from "@/lib/uploadImage";
import deleteImage from "@/lib/deleteImage";

interface ImageHandlerOptions {
  file?: Express.Multer.File;
  existingUrl?: string | null;
  deleteFlag?: boolean;
  folder: string;
}

/**
 * Reusable logic for processing images in services.
 * Returns the next URL to be saved in the database.
 */
export async function handleImageService({
  file,
  existingUrl,
  deleteFlag,
  folder,
}: ImageHandlerOptions): Promise<string | null | undefined> {
  // 1. If a new file is uploaded
  if (file) {
    const newUrl = await uploadImage(file, folder);
    // Cleanup old file from storage if it exists
    if (existingUrl) await deleteImage(existingUrl);
    return newUrl;
  }

  // 2. If user explicitly requested to delete the image
  if (deleteFlag) {
    if (existingUrl) await deleteImage(existingUrl);
    return null;
  }

  // 3. No changes (keep existing)
  return undefined;
}
