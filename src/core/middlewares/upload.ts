import multer from "multer";
import path from "path";
import fs from "fs";
import { Request, Response, NextFunction } from "express";
import logger from "../../config/logger.config";

// Ensure uploads/temp directory exists relative to the project structure
// Assuming this file is in src/core/middlewares, we go up two levels to src, then to uploads
const tempDir = path.join(__dirname, "..", "..", "uploads", "temp");

if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

// Use memoryStorage or diskStorage
// const storage = multer.memoryStorage();
const storage = multer.diskStorage({
  destination: function (req: Request, file: Express.Multer.File, cb) {
    // Store temporarily in uploads/temp
    cb(null, tempDir);
  },
  filename: function (req: Request, file: Express.Multer.File, cb) {
    // Generate unique temporary filename
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, "temp-" + uniqueSuffix + ext);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: parseInt(process.env.MULTER_MAX_FILE_SIZE_MB || "5", 10) * 1024 * 1024,
  },
  fileFilter: (req: Request, file: Express.Multer.File, cb) => {
    const allowedTypes = /jpeg|jpg|png|webp/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase(),
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files are allowed!"));
    }
  },
});

export default upload;

// ============================ cleanupTempUploads ============================
// Removes the local temp files multer wrote to uploads/temp once the response is
// finished. Runs for BOTH success and error responses, so temp files never leak
// regardless of which path the handler takes (validation throw, upload failure,
// transaction failure, etc.). Cleanup is best-effort: errors are logged, not thrown.
export const cleanupTempUploads = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  let done = false;
  const removeTempFiles = () => {
    if (done) return;
    done = true;

    // Collect files from every multer shape: .single() → req.file,
    // .array()/.fields() → req.files (array or { field: File[] }).
    const files = req.files as
      | { [fieldname: string]: Express.Multer.File[] }
      | Express.Multer.File[]
      | undefined;
    const list: Express.Multer.File[] = Array.isArray(files)
      ? [...files]
      : files
        ? Object.values(files).flat()
        : [];
    if (req.file) list.push(req.file);

    for (const file of list) {
      if (!file?.path) continue;
      fs.unlink(file.path, (err) => {
        if (err && err.code !== "ENOENT") {
          logger.warn(
            { err, path: file.path },
            "[upload] Failed to remove temp upload file",
          );
        }
      });
    }
  };

  // "finish" fires after a successful response; "close" covers aborted/errored ones.
  res.on("finish", removeTempFiles);
  res.on("close", removeTempFiles);
  next();
};
