import type { Request, Response, NextFunction } from "express";

export type roles =
  | "Admin"
  | "Customer"
  | "Courier"
  | "Seller"
  | "CustomerSupport"
  | "Supplier"
  | "CourierOffice"
  ; // extend as needed
export default function requireRole(...allowed: roles[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const role = req.user?.role?.name as roles | undefined;

    if (!role) {
      return res.status(401).json({ message: "admin:errors.unauthorized" });
    }

    if (!allowed.includes(role)) {
      return res.status(403).json({ message: "admin:errors.forbidden" });
    }

    next();
  };
}
