import multer, { type FileFilterCallback } from "multer";
import { sanitizeInput } from "@/lib/sanitize";
import type { Request, RequestHandler } from "express";
import path from "path";
import fs from "fs";

// ─── MIME allowlist ───────────────────────────────────────────────────────────

const ALLOWED_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
]);

/**
 * Maps field names to their own MIME allowlist.
 * If a field isn't listed here, ALLOWED_MIME_TYPES is used as the fallback.
 *
 * Example: a "document" field could allow PDFs while avatar fields stay image-only.
 */
const FIELD_MIME_OVERRIDES: Record<string, Set<string>> = {
  document: new Set(["application/pdf"]),
  tax_card: new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
  ]),
  commercial_register: new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
  ]),
};

// ─── Magic-byte signatures ────────────────────────────────────────────────────
// Validates the actual file content, not just the client-supplied MIME type.

type MagicEntry = { bytes: number[]; offset?: number };

const MAGIC_BYTES: Record<string, MagicEntry[]> = {
  "image/jpeg": [{ bytes: [0xff, 0xd8, 0xff] }],
  "image/png": [{ bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] }],
  "image/webp": [{ bytes: [0x52, 0x49, 0x46, 0x46], offset: 0 }], // "RIFF"
  "image/gif": [
    { bytes: [0x47, 0x49, 0x46, 0x38, 0x39, 0x61] }, // GIF89a
    { bytes: [0x47, 0x49, 0x46, 0x38, 0x37, 0x61] }, // GIF87a
  ],
  "application/pdf": [{ bytes: [0x25, 0x50, 0x44, 0x46] }], // %PDF
};

// Longest signature we need to inspect (PNG = 8 bytes); read a little extra.
const MAGIC_HEADER_BYTES = 16;

function matchesMagicBytes(buffer: Buffer, mime: string): boolean {
  const signatures = MAGIC_BYTES[mime];
  if (!signatures) return true; // no signature registered → skip content check

  return signatures.some(({ bytes, offset = 0 }) =>
    bytes.every((b, i) => buffer[offset + i] === b),
  );
}

// ─── File filter ──────────────────────────────────────────────────────────────

function buildFileFilter(
  fieldOverrides: Record<string, Set<string>> = FIELD_MIME_OVERRIDES,
  globalAllowed: Set<string> = ALLOWED_MIME_TYPES,
): multer.Options["fileFilter"] {
  return (req: Request, file: Express.Multer.File, cb: FileFilterCallback) => {
    const allowed = fieldOverrides[file.fieldname] ?? globalAllowed;

    if (!allowed.has(file.mimetype)) {
      return cb(
        new multer.MulterError(
          "LIMIT_UNEXPECTED_FILE",
          // reuse multer's error class; message overridden in withSanitize
        ),
      );
    }

    // Magic-byte check is deferred to `withSanitize`: with diskStorage the file
    // is only on disk after multer finishes, so we read its header there.
    // Here we only check the declared MIME.
    cb(null, true);
  };
}

// ─── Content (magic-byte) validation after upload ─────────────────────────────

/**
 * Reads the first bytes of an uploaded file. Works for both memoryStorage
 * (file.buffer) and diskStorage (file.path).
 */
function readHeader(
  file: Express.Multer.File,
  length = MAGIC_HEADER_BYTES,
): Buffer | null {
  if (file.buffer && file.buffer.length > 0) {
    return file.buffer.subarray(0, length);
  }
  if (file.path) {
    let fd: number | null = null;
    try {
      fd = fs.openSync(file.path, "r");
      const buf = Buffer.alloc(length);
      const bytesRead = fs.readSync(fd, buf, 0, length, 0);
      return bytesRead > 0 ? buf.subarray(0, bytesRead) : null;
    } catch {
      return null;
    } finally {
      if (fd !== null) fs.closeSync(fd);
    }
  }
  return null;
}

function validateFileContents(files: Express.Multer.File[]): string | null {
  for (const file of files) {
    const header = readHeader(file);
    if (!header || header.length === 0) {
      return `File "${file.fieldname}" is empty.`;
    }
    if (!matchesMagicBytes(header, file.mimetype)) {
      return `File "${file.fieldname}" content does not match its declared type (${file.mimetype}).`;
    }
  }
  return null;
}

function collectFiles(req: Request): Express.Multer.File[] {
  if (Array.isArray(req.files)) return req.files;
  if (req.files && typeof req.files === "object") {
    return Object.values(req.files).flat();
  }
  if (req.file) return [req.file];
  return [];
}

/** Best-effort removal of temp files left on disk by diskStorage. */
function cleanupFiles(files: Express.Multer.File[]): void {
  for (const file of files) {
    if (file.path) fs.unlink(file.path, () => {});
  }
}

// ─── Storage (diskStorage → uploads/temp) ─────────────────────────────────────

// Ensure uploads/temp directory exists relative to the project structure.
// This file lives in src/middlewares, so go up two levels to the project root.
const tempDir = path.join(__dirname, "..", "..", "uploads", "temp");

if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

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

const multerInstance = multer({
  storage,
  limits: {
    fileSize:
      parseInt(process.env.MULTER_MAX_FILE_SIZE_MB || "5", 10) * 1024 * 1024,
  },
  fileFilter: buildFileFilter(),
});

// ─── Sanitize wrapper ─────────────────────────────────────────────────────────
//
// The global middleware in app.ts sanitizes req.body and freezes req.sanitized
// *before* routes run. For multipart/form-data the body is still empty at that
// point (multer parses it later), so req.sanitized.body would stay {}. This
// wrapper re-sanitizes after multer has populated req.body and refreshes
// req.sanitized so controllers reading req.sanitized.body get the form fields.

function withSanitize(handler: RequestHandler): RequestHandler {
  return (req, res, next) => {
    // Remove temp files written by diskStorage once the response is finished.
    // Covers BOTH success and every error path (controller throw, upload to
    // remote storage, etc.) — not just the rejected-upload case handled below —
    // so temp files in uploads/temp never leak. Best-effort: errors are ignored.
    let cleaned = false;
    const removeTempFiles = () => {
      if (cleaned) return;
      cleaned = true;
      cleanupFiles(collectFiles(req));
    };
    res.on("finish", removeTempFiles);
    res.on("close", removeTempFiles);

    handler(req, res, (err) => {
      if (err) {
        // Improve the default MulterError message for MIME rejections
        if (
          err instanceof multer.MulterError &&
          err.code === "LIMIT_UNEXPECTED_FILE"
        ) {
          (err as any).message =
            "File type not allowed. Only images (JPEG, PNG, WebP, GIF) — and PDF where supported — are accepted.";
        }
        return next(err);
      }

      // ── Magic-byte content validation ────────────────────────────────────
      const files = collectFiles(req);
      if (files.length > 0) {
        const contentError = validateFileContents(files);
        if (contentError) {
          cleanupFiles(files); // remove rejected temp files from disk
          return res.status(415).json({ message: contentError });
        }
      }

      // ── Body sanitisation ────────────────────────────────────────────────
      if (req.body) {
        const clean = sanitizeInput(req.body);
        req.body = clean;

        const current = req.sanitized;
        Object.defineProperty(req, "sanitized", {
          value: { ...current, body: clean },
          writable: true,
          configurable: true,
          enumerable: true,
        });
      }

      next();
    });
  };
}

// ─── Public API ───────────────────────────────────────────────────────────────

const upload = {
  single: (field: string) => withSanitize(multerInstance.single(field)),
  fields: (fields: multer.Field[]) =>
    withSanitize(multerInstance.fields(fields)),
  array: (field: string, max?: number) =>
    withSanitize(multerInstance.array(field, max)),
  none: () => withSanitize(multerInstance.none()),
};

export default upload;
export { ALLOWED_MIME_TYPES, FIELD_MIME_OVERRIDES, buildFileFilter };
