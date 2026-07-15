import { NextFunction, Request, Response } from "express";
import { ZodObject } from "zod";
import { HttpStatusCode } from "../http/http.status.code";
import { AppError } from "../errors/app.error";

export const validation = (shcema: ZodObject) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const data = {
      ...req.query,
      ...req.body,
      ...req.params,
      // express.json() can't see or parssing fields that has files, so we create this field and put data in it manually
      // profileImage: req.file,
      // attachment: req.file,
      // attachments: req.files,
    };
    const result = shcema.safeParse(data);
    if (!result.success) {
      const issues = result.error?.issues;

      // Format errors into readable message
      const errorMessages = issues
        .map((issue) => {
          const field = issue.path.join(".") || "general";
          return `${field}: ${issue.message}`;
        })
        .join(",||&&||,");

      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        `Validation failed: ${errorMessages}`,
        {
          cause: {
            errors: issues.map((issue) => ({
              field: issue.path.join(".") || "general",
              message: issue.message,
              code: issue.code,
            })),
            originalError: result.error,
          },
        },
      );
    }
    // save the transformed data so services can use it
    res.locals.validatedData = result.data;
    next();
  };
};
