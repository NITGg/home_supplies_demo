import fs from "fs/promises";
import path from "path";

const deleteImage = async (
  fileUrl: string | null | undefined,
): Promise<boolean> => {
  try {
    if (!fileUrl) return false;

    let filePath: string;
    if (fileUrl.startsWith("/uploads/")) {
      filePath = fileUrl.replace(/^\//, "");
    } else if (fileUrl.startsWith("http")) {
      const url = new URL(fileUrl);
      filePath = url.pathname.replace(/^\//, "");
    } else {
      filePath = fileUrl;
    }

    // Assuming this file is in src/utils, '..' goes to src
    const absolutePath = path.join(__dirname, "..", filePath);

    try {
      await fs.access(absolutePath); // check file exists
      await fs.unlink(absolutePath);
      // console.log("Deleted:", absolutePath);
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
