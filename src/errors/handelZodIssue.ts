import type { Request } from "express";
import { ZodError } from "zod";

export default function translateZodIssue(
  req: Request,
  issue: ZodError["issues"][number],
) {
  // Strategy 1 (best): if your Zod messages are keys like "users.errors.email_invalid"
  // then translate them directly.
  if (issue.message.includes(".") && !issue.message.includes(" ")) {
    return req.t(issue.message);
  }

  // Strategy 2: fallback based on Zod issue code (you can expand these)
  const codeKey = `zod.${issue.code}`;
  const translated = req.t(codeKey, { defaultValue: "" });
  return translated || issue.message;
}
