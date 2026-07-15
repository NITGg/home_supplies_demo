import z from "zod";
import { faqsQuerySchema, onBoardingQuerySchema } from "./aboutus.validation";

export type FaqsQueryDTO = z.infer<typeof faqsQuerySchema>;
export type OnBoardingQueryDTO = z.infer<typeof onBoardingQuerySchema>;
