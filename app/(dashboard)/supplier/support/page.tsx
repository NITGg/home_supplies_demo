"use client";
import { Headphones, Mail, MessageSquare, Phone } from "lucide-react";
import { useT } from "@/contexts/LanguageContext";

export default function SupplierSupportPage() {
  const { t, isRTL } = useT();

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      <div className="flex items-center gap-3">
        <Headphones size={20} className="text-indigo-600" />
        <h1 className="text-xl font-bold text-gray-900">{t("sp.support.title")}</h1>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-8 text-center">
        <div className="w-16 h-16 rounded-2xl bg-indigo-100 flex items-center justify-center mx-auto mb-4">
          <Headphones size={28} className="text-indigo-600" />
        </div>
        <h2 className="text-lg font-semibold text-gray-900 mb-2">{t("sp.support.needHelp")}</h2>
        <p className="text-sm text-gray-500 mb-6 max-w-md mx-auto">
          {t("sp.support.desc")}
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 max-w-lg mx-auto">
          {[
            { icon: MessageSquare, label: t("sp.support.liveChat"), desc: t("sp.support.chatDesc"), href: "/chat" },
            { icon: Mail, label: t("sp.support.email"), desc: "support@tawreedat.com", href: "mailto:support@tawreedat.com" },
            { icon: Phone, label: t("sp.support.phone"), desc: "+20 100 000 0000", href: "tel:+201000000000" },
          ].map(({ icon: Icon, label, desc, href }) => (
            <a key={label} href={href}
              className="flex flex-col items-center gap-2 p-4 border border-gray-200 rounded-xl hover:bg-gray-50 transition">
              <div className="w-10 h-10 rounded-xl bg-indigo-50 flex items-center justify-center">
                <Icon size={18} className="text-indigo-600" />
              </div>
              <p className="text-sm font-medium text-gray-900">{label}</p>
              <p className="text-xs text-gray-500 text-center">{desc}</p>
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
