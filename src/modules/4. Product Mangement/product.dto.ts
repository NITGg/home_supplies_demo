import z from "zod";
import {
  updateSupplierProductSchema,
  createSupplierProductSchema,
  updateProductSchema,
  createProductSchema,
  setDeliveryWindowsSchema,
  createSupplierOfferSchema,
  updateSupplierOfferSchema,
} from "./product.validation";

export type createSupplierProductDTO = z.infer<
  typeof createSupplierProductSchema
>;
export type updateSupplierProductDTO = z.infer<
  typeof updateSupplierProductSchema
>;
export type updateProductDTO = z.infer<typeof updateProductSchema>;
export type createProductDTO = z.infer<typeof createProductSchema>;
export type setDeliveryWindowsDTO = z.infer<typeof setDeliveryWindowsSchema>;
export type createSupplierOfferDTO = z.infer<typeof createSupplierOfferSchema>;
export type updateSupplierOfferDTO = z.infer<typeof updateSupplierOfferSchema>;
