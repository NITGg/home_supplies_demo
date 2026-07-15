import { env } from "../../config/env";
import logger from "../../config/logger.config";
import { AppError } from "../../core/errors/app.error";
import { HttpStatusCode } from "../../core/http/http.status.code";
type Lang = "ar" | "en";

const SEND_TIMEOUT_MS = 10_000;

// ============================================== smsTypeForLang ==============================================
// Broadnet `type` selects the message encoding. Arabic text needs Unicode
// (UCS-2); Latin/English uses the default GSM-7. We derive it from the
// recipient's language so the text and encoding never mismatch (a Latin
// encoding on Arabic text arrives as "????").
// NOTE: confirm these codes against your Broadnet API doc — adjust if needed.
const SMS_TYPE_LATIN = "1";
const SMS_TYPE_UNICODE = "2";

function smsTypeForLang(lang: Lang): string {
  return lang === "ar" ? SMS_TYPE_UNICODE : SMS_TYPE_LATIN;
}

// ============================================== toUnicodeHex ==============================================
/**
 * Broadnet requires Unicode (type=2) message bodies to be hex-encoded UTF-16
 * (each UTF-16 code unit as 4 uppercase hex digits — e.g. "ن" → "0646").
 * Sending raw Arabic text returns status 009 (INVALID_TEXT). Latin (type=1)
 * text is sent as-is.
 */
function toUnicodeHex(text: string): string {
  let out = "";
  for (let i = 0; i < text.length; i++) {
    out += text.charCodeAt(i).toString(16).toUpperCase().padStart(4, "0");
  }
  return out;
}

// ============================================== parseBroadnetResult ==============================================
/**
 * Broadnet replies with HTTP 200 even when a submission is REJECTED, so we must
 * inspect the body. Two known shapes:
 *  - legacy string errors: "HTTP04" / "HTTP05" …
 *  - JSON API: { response: { batch_id, status } } — an ACCEPTED send returns a
 *    non-blank `batch_id`. A blank batch_id (e.g. status "009") means the
 *    message was NOT queued (unapproved sender ID, no credit, blocked number…).
 *
 * NOTE: acceptance is keyed on a non-blank `batch_id`, which matches the
 * observed success/failure responses. If your Broadnet account documents an
 * explicit success status code, tighten the check here.
 */
function parseBroadnetResult(raw: string): {
  accepted: boolean;
  status?: string | undefined;
  batchId?: string | undefined;
} {
  if (/\bHTTP\d{2,}\b/i.test(raw)) return { accepted: false };
  try {
    const data = JSON.parse(raw);
    const res = data?.response ?? data;
    const batchId =
      typeof res?.batch_id === "string" ? res.batch_id.trim() : "";
    const status = res?.status != null ? String(res.status) : undefined;
    return { accepted: batchId.length > 0, status, batchId };
  } catch {
    // Unrecognized body — don't claim success for an OTP we can't confirm.
    return { accepted: false };
  }
}

// ============================================== sendSms ==============================================
/**
 * Sends a single SMS through the Broadnet websmpp JSON gateway.
 * Throws an AppError on misconfiguration, network failure, or a rejection
 * code from the gateway, so callers can surface a translated error.
 */
export async function sendSms(input: { to: string; text: string; lang: Lang }) {
  if (!env.BROADNET_USERNAME || !env.BROADNET_PASSWORD) {
    logger.error("Broadnet credentials are not configured");
    throw new AppError(
      HttpStatusCode.INTERNAL_SERVER_ERROR,
      "SMS not configured",
    );
  }

  // Broadnet's `gsm` field expects bare MSISDN digits (e.g. "201000000000"),
  // while we store phones in E.164 ("+201000000000").
  const gsm = input.to.replace(/^\+/, "");

  const type = smsTypeForLang(input.lang);
  // Unicode (Arabic) must be hex-encoded UTF-16; Latin is sent as-is.
  const text =
    type === SMS_TYPE_UNICODE ? toUnicodeHex(input.text) : input.text;

  const payload = {
    campaign: {
      username: env.BROADNET_USERNAME,
      password: env.BROADNET_PASSWORD,
      sender: env.BROADNET_SENDER,
      format: env.BROADNET_SMS_FORMAT,
      type,
      gsm: [gsm],
      text: text,
    },
  };

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SEND_TIMEOUT_MS);

  try {
    const response = await fetch(env.BROADNET_SMS_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const raw = await response.text();
    const result = parseBroadnetResult(raw);

    if (!response.ok || !result.accepted) {
      logger.error(
        {
          httpStatus: response.status,
          broadnetStatus: result.status,
          body: raw,
          to: gsm,
        },
        "Broadnet SMS rejected",
      );
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "SMS send failed",
        {
          cause: { broadnetStatus: result.status },
        },
      );
    }

    logger.info(
      { broadnetStatus: result.status, batchId: result.batchId, to: gsm },
      "Broadnet SMS accepted",
    );

    return { batchId: result.batchId, status: result.status };
  } catch (err) {
    if (err instanceof AppError) throw err;
    logger.error({ err, to: gsm }, "Broadnet SMS request failed");
    throw new AppError(HttpStatusCode.INTERNAL_SERVER_ERROR, "SMS send failed");
  } finally {
    clearTimeout(timer);
  }
}
