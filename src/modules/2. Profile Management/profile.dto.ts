import z from "zod";
import {
  updateProfileSchema,
  updateDocumentsSchema,
  softDeleteSchema,
  hardDeleteSchema,
  cancelSoftDeleteSchema,
  updateSelectedAreasSchema,
  locationGovernoratesSchema,
  locationGovernoratesAreasSchema,
} from "./profile.validation";

export type updateProfileDTO = z.infer<typeof updateProfileSchema>;
export type updateDocumentsDTO = z.infer<typeof updateDocumentsSchema>;
export type updateAreasDTO = z.infer<typeof updateSelectedAreasSchema>;
export type locationGovernoratesDTO = z.infer<typeof locationGovernoratesSchema>;
export type locationGovernoratesAreasDTO = z.infer<typeof locationGovernoratesAreasSchema>;
export type softDeleteDTO = z.infer<typeof softDeleteSchema>;
export type hardDeleteDTO = z.infer<typeof hardDeleteSchema>;
export type cancelSoftDeleteDTO = z.infer<typeof cancelSoftDeleteSchema>;
