import i18next from "i18next";
import Backend from "i18next-fs-backend";
import * as middleware from "i18next-http-middleware";
import path from "node:path";

/**
 * Initialize i18next (call this once before starting the server)
 */
export async function initI18n() {
  await i18next
    .use(Backend)
    .use(middleware.LanguageDetector)
    .init({
      fallbackLng: "en",
      preload: ["en", "ar"],

      // namespaces (auth.json, users.json, common.json ...)
      ns: [
        "common",
        "auth",
        "users",
        "roles",
        "badges",
        "profile",
        "governorates",
        "areas",
        "orders",
        "settings",
        "about-app",
        "articles",
        "contact-us",
        "faqs",
        "on-boarding",
        "customer-reviews",
        "customer-coupons",
        "courier-coupons",
        "unavailable-area-request",
        "admin-approval",
        "admin-courier-office",
        "admin-courier-stat",
        "admin-vehicle",
        "admin-wallet",
        "brands",
        "categories",
        "products",
        "cart",
        "offers",
        "ads",
        "refunds",
        "external_apps",
        "admin-i18n"
      ],
      defaultNS: "common",

      backend: {
        // CommonJS runtime provides __dirname
        loadPath: path.join(__dirname, "locales/{{lng}}/{{ns}}.json"),
      },

      detection: {
        order: ["header", "querystring"],
        lookupQuerystring: "lang",
      },

      interpolation: { escapeValue: false },
    });
}

export const i18nMiddleware = middleware.handle(i18next);
