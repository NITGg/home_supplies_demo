import type { AppEnvironment, User, UserRole } from "@prisma/client";
export type Lang = "ar" | "en";

declare global {
  namespace Express {
    interface Request {
      sanitized: {
        body: ReqBody;
        query: ReqQuery;
        params: P;
      };
      t: (key: string, options?: any) => string;
      language: Lang;
      auth?: { userId: number };
      user?: Pick<
        User,
        "id" | "full_name" | "email" | "phone" | "is_active" | "deleted_at"
      > & {
        role: Pick<UserRole, "name">;
      };
      externalApp?: {
        id: number;
        env: AppEnvironment;
        partner_id: number | null;
      };
    }
  }
}

export {};
