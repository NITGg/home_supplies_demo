import type { Request } from "express";

export type RoleName = "Admin" | "Customer";

// Generic AuthedRequest that accepts a specific RoleName
// In your types file
export type AuthedRequest<T extends string = string> = Request & {
  user: NonNullable<Request["user"]> & {
    role: { name: T };
  };
  auth: NonNullable<Request["auth"]>;
};

export type AdminUser = AuthedRequest<"Admin">["user"];
