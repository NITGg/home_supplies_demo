import nodemailer from "nodemailer";
import env from "@/config/env";

export function getTransporter() {
  return nodemailer.createTransport({
    host: env.MAIL_HOST,
    port: env.MAIL_PORT,
    secure: env.MAIL_PORT === 465,
    requireTLS: env.MAIL_PORT === 465,
    auth: {
      user: env.MAIL_USER,
      pass: env.MAIL_PASS,
    },
  });
}

export async function sendEmail(input: { to: string; subject: string; text: string; html: string }) {
  const transporter = getTransporter();
  return transporter.sendMail({
    from: env.MAIL_FROM ?? env.MAIL_USER,
    to: input.to,
    subject: input.subject,
    text: input.text,
    html: input.html,
  });
}
