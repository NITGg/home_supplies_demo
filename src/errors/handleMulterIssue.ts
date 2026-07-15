import type { Request } from "express";
import multer from "multer";

export function translateMulterError(req: Request, err: multer.MulterError) {
  switch (err.code) {
    case "LIMIT_FILE_SIZE":
      return {
        status: 400,
        body: {
          message:
            req.t?.("errors.upload.file_too_large") ?? "File is too large",
          code: err.code,
        },
      };

    case "LIMIT_UNEXPECTED_FILE":
      return {
        status: 400,
        body: {
          message:
            req.t?.("errors.upload.unexpected_field") ??
            "Unexpected file field",
          code: err.code,
          field: (err as any).field, // Multer attaches this
        },
      };

    case "LIMIT_FILE_COUNT":
      return {
        status: 400,
        body: {
          message:
            req.t?.("errors.upload.too_many_files") ??
            "Too many files uploaded",
          code: err.code,
        },
      };

    case "LIMIT_FIELD_KEY":
      return {
        status: 400,
        body: {
          message:
            req.t?.("errors.upload.field_name_too_long") ??
            "Field name is too long",
          code: err.code,
        },
      };

    case "LIMIT_FIELD_VALUE":
      return {
        status: 400,
        body: {
          message:
            req.t?.("errors.upload.field_value_too_long") ??
            "Field value is too long",
          code: err.code,
        },
      };

    case "LIMIT_FIELD_COUNT":
      return {
        status: 400,
        body: {
          message:
            req.t?.("errors.upload.too_many_fields") ?? "Too many fields",
          code: err.code,
        },
      };

    case "LIMIT_PART_COUNT":
      return {
        status: 400,
        body: {
          message: req.t?.("errors.upload.too_many_parts") ?? "Too many parts",
          code: err.code,
        },
      };

    default:
      return {
        status: 400,
        body: {
          message: req.t?.("errors.upload.failed") ?? err.message,
          code: err.code,
        },
      };
  }
}
