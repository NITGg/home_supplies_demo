import { Lang } from "@/types/express";

export function buildVerificationEmail(input: {
  name: string;
  code: string;
  lang: Lang;
}) {
  const isAR = input.lang === "ar";

  const subject = isAR ? "رمز تفعيل الحساب" : "Account verification code";

  const text = isAR
    ? `مرحباً ${input.name}\nرمز التفعيل الخاص بك هو: ${input.code}\nهذا الرمز صالح لمدة 5 دقائق.`
    : `Hi ${input.name}\nYour verification code is: ${input.code}\nThis code is valid for 5 minutes.`;

  const html = `
  <div style="font-family:Arial,sans-serif;background:#f6f7fb;padding:24px">
    <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;padding:24px;border:1px solid #eee">
      <h2 style="margin:0 0 12px 0;color:#111">${isAR ? "تأكيد الحساب" : "Verify your account"}</h2>
      <p style="margin:0 0 16px 0;color:#333;line-height:1.6">
        ${isAR ? `مرحباً ${input.name}` : `Hi ${input.name}`},
        <br/>
        ${isAR ? "رمز التفعيل الخاص بك هو:" : "Your verification code is:"}
      </p>

      <div style="font-size:28px;letter-spacing:6px;font-weight:700;text-align:center;padding:16px 0;border-radius:10px;background:#f3f4f6;border:1px dashed #ddd">
        ${input.code}
      </div>

      <p style="margin:16px 0 0 0;color:#666;font-size:13px;line-height:1.6">
        ${
          isAR
            ? "هذا الرمز صالح لمدة 5 دقائق. إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة."
            : "This code is valid for 5 minutes. If you didn’t request this, you can ignore this email."
        }
      </p>
    </div>
  </div>
  `.trim();

  return { subject, text, html };
}
