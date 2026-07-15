type Lang = "ar" | "en";

export function buildVerificationSms(input: { code: string; lang: Lang }) {
  const isAR = input.lang === "ar";

  const text = isAR
    ? `رمز التحقق الخاص بك هو: ${input.code}\nصالح لمدة 5 دقائق.`
    : `Your verification code is: ${input.code}\nValid for 5 minutes.`;

  return { text };
}
