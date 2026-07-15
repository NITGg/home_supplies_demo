import { z } from "zod";

export interface AttributeRule {
  type: "string" | "number" | "boolean";
  enum?: (string | number)[];
  required?: boolean;
}

export function validateDynamicAttributes(
  rules: Record<string, AttributeRule>,
  providedAttributes: { key: string; value: any }[]
) {
  const shape: Record<string, z.ZodTypeAny> = {};

  // Build the schema based on category rules
  for (const [key, rule] of Object.entries(rules)) {
    let validator: z.ZodTypeAny;

    switch (rule.type) {
      case "number": validator = z.coerce.number(); break;
      case "boolean": validator = z.preprocess((v) => v === "true" || v === 1 || v === true, z.boolean()); break;
      default: validator = z.coerce.string();
    }

    if (rule.enum?.length) {
      validator = validator.refine(val => rule.enum!.map(String).includes(String(val)), {
        message: `Must be one of: ${rule.enum.join(", ")}`
      });
    }

    shape[key] = rule.required ? validator : validator.optional();
  }

  // Convert array to object for Zod: [{key: 'Size', value: 'XL'}] -> { Size: 'XL' }
  const dataObject = providedAttributes.reduce((acc, curr) => ({
    ...acc, [curr.key]: curr.value
  }), {});

  return z.object(shape).safeParse(dataObject);
}