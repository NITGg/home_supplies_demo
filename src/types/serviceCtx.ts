import { Lang } from "@/types/express";

export type ServiceCtx = {
  lang: Lang;
};



export type ServiceArgs<TInput> = {
  ctx: ServiceCtx;
  input: TInput;
};
