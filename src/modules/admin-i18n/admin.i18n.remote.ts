import http from "node:http";
import https from "node:https";
import { HttpError } from "@/lib/httpError";

export interface RemoteI18nRow {
  key: string;
  en: string;
  ar: string;
}

function request(
  url: string,
  method: "GET" | "PUT",
  body?: unknown,
): Promise<{ rows: RemoteI18nRow[] }> {
  return new Promise((resolve, reject) => {
    const client = url.startsWith("https") ? https : http;
    const payload = body !== undefined ? JSON.stringify(body) : undefined;

    const req = client.request(
      url,
      {
        method,
        timeout: 8000,
        headers: payload
          ? {
              "Content-Type": "application/json",
              "Content-Length": Buffer.byteLength(payload),
            }
          : undefined,
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          if ((res.statusCode ?? 500) >= 400) {
            reject(new HttpError(502, "admin-i18n:errors.remote_app_error"));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new HttpError(502, "admin-i18n:errors.remote_app_error"));
          }
        });
      },
    );

    req.on("error", () => reject(new HttpError(502, "admin-i18n:errors.remote_app_unreachable")));
    req.on("timeout", () => {
      req.destroy();
      reject(new HttpError(502, "admin-i18n:errors.remote_app_unreachable"));
    });

    if (payload) req.write(payload);
    req.end();
  });
}

export function fetchRemoteNamespace(baseUrl: string, internalPath: string) {
  return request(`${baseUrl}${internalPath}`, "GET");
}

export function updateRemoteNamespace(
  baseUrl: string,
  internalPath: string,
  updates: { key: string; en?: string; ar?: string }[],
) {
  return request(`${baseUrl}${internalPath}`, "PUT", { updates });
}
