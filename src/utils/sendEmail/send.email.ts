import { createTransport } from "nodemailer";
import { env } from "../../config/env";

export const sendEmail = async ({
  to,
  subject,
  html,
}: {
  to: string;
  subject: string;
  html: string;
}) => {
  const transporter = createTransport({
    host: env.HOST_EMAIL as string,
    port: 465,
    secure: true,
    service: "gmail",
    auth: {
      user: env.SENDER_EMAIL,
      pass: env.GOOGLE_APP_PASSWORD,
    },
    // tls: {
    //   rejectUnauthorized: false, // Only for development
    // },
  });
  try {
    const info = await transporter.sendMail({
      from: `"Tawreedat" <${env.SENDER_EMAIL}>`, // sender address
      to, // list of receivers
      subject, // Subject line
      html, // html body
    });
    const isEmailSended =
      Array.isArray(info?.accepted) && info.accepted.length > 0;
    return { isEmailSended, info };
  } catch (err) {
    return { isEmailSended: false, err: err + "" };
  }
};
