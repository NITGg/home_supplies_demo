"use client";
import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { sendNotificationStream, type RecipientType, type NotificationRole, type NotificationResult, type NotificationProgress, type SendNotificationPayload } from "@/lib/notifications";
import { useT } from "@/contexts/LanguageContext";
import { Bell, Send, Users, User } from "lucide-react";
import toast from "react-hot-toast";
import UserMultiSelect from "@/components/notifications/UserMultiSelect";

export default function NotificationsPage() {
  const { t } = useT();
  const [recipientType, setRecipientType] = useState<RecipientType>("all");
  const [selectedRoles, setSelectedRoles] = useState<NotificationRole[]>([]);
  const [selectedUserIds, setSelectedUserIds] = useState<number[]>([]);
  const [titleEn, setTitleEn] = useState("");
  const [titleAr, setTitleAr] = useState("");
  const [bodyEn, setBodyEn] = useState("");
  const [bodyAr, setBodyAr] = useState("");
  const [result, setResult] = useState<NotificationResult | null>(null);
  const [progress, setProgress] = useState<NotificationProgress | null>(null);

  const sendMut = useMutation({
    mutationFn: () => {
      // The API requires bilingual content — title/body must each be {en, ar}.
      const title =
        titleEn.trim() || titleAr.trim()
          ? { en: titleEn.trim(), ar: titleAr.trim() }
          : undefined;
      const payload: SendNotificationPayload = {
        recipientType,
        content: {
          body: { en: bodyEn.trim(), ar: bodyAr.trim() },
          ...(title ? { title } : {}),
        },
      };
      if (recipientType === "role") {
        payload.roles = selectedRoles;
      }
      if (recipientType === "users") {
        payload.userIds = selectedUserIds;
      }
      // Use the SSE stream — only it returns the per-recipient delivery counts.
      return sendNotificationStream(payload, setProgress);
    },
    onSuccess: (data) => {
      toast.success(t("notifications.sent"));
      setResult(data);
      setProgress(null);
    },
    onError: () => {
      toast.error("Failed to send notification");
      setProgress(null);
    },
  });

  function toggleRole(role: NotificationRole) {
    setSelectedRoles(prev => prev.includes(role) ? prev.filter(r => r !== role) : [...prev, role]);
  }

  const bodyFilled = bodyEn.trim().length > 0 && bodyAr.trim().length > 0;

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!bodyFilled) {
      toast.error("Enter the message body in both English and Arabic");
      return;
    }
    if (recipientType === "role" && selectedRoles.length === 0) {
      toast.error("Select at least one role");
      return;
    }
    if (recipientType === "users" && selectedUserIds.length === 0) {
      toast.error("Select at least one user");
      return;
    }
    setResult(null);
    setProgress(null);
    sendMut.mutate();
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-2 mb-1">
        <Bell size={22} className="text-indigo-600" />
        <h1 className="text-2xl font-bold text-gray-900">{t("notifications.title")}</h1>
      </div>
      <p className="text-sm text-gray-500">{t("notifications.subtitle")}</p>

      <div className="max-w-xl">
        <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 space-y-5">

          {/* Recipient type */}
          <div className="space-y-2">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("notifications.recipientType")}</label>
            <div className="flex gap-3 flex-wrap">
              {([
                { value: "all", label: t("notifications.all"), icon: Users },
                { value: "role", label: t("notifications.byRole"), icon: User },
                { value: "users", label: t("notifications.specificUsers"), icon: User },
              ] as { value: RecipientType; label: string; icon: React.ElementType }[]).map(({ value, label, icon: Icon }) => (
                <button key={value} type="button"
                  onClick={() => setRecipientType(value)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium border transition ${recipientType === value ? "bg-indigo-600 text-white border-indigo-600" : "border-gray-300 text-gray-600 hover:border-indigo-400 hover:text-indigo-600"}`}>
                  <Icon size={15} /> {label}
                </button>
              ))}
            </div>
          </div>

          {/* Role selector */}
          {recipientType === "role" && (
            <div className="space-y-2">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("notifications.roles")}</label>
              <div className="flex gap-2">
                {(["admin", "customer", "courier"] as NotificationRole[]).map(role => (
                  <button key={role} type="button" onClick={() => toggleRole(role)}
                    className={`px-4 py-2 rounded-xl text-sm font-medium border capitalize transition ${selectedRoles.includes(role) ? "bg-indigo-600 text-white border-indigo-600" : "border-gray-300 text-gray-600 hover:border-indigo-400"}`}>
                    {role}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Specific users */}
          {recipientType === "users" && (
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("notifications.userIds")}</label>
              <UserMultiSelect value={selectedUserIds} onChange={setSelectedUserIds} />
              {selectedUserIds.length > 0 && (
                <p className="text-xs text-gray-400">{selectedUserIds.length} {t("notifications.selectedUsers")}</p>
              )}
            </div>
          )}

          {/* Title (bilingual) */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("notifications.title_field")}</label>
            <div className="grid grid-cols-2 gap-3">
              <div className="relative">
                <span className="absolute top-2 left-2 text-[10px] font-bold text-gray-400">EN</span>
                <input value={titleEn} onChange={e => setTitleEn(e.target.value)} dir="ltr"
                  className="w-full border border-gray-300 rounded-xl px-3 pt-6 pb-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none" />
              </div>
              <div className="relative">
                <span className="absolute top-2 right-2 text-[10px] font-bold text-gray-400">AR</span>
                <input value={titleAr} onChange={e => setTitleAr(e.target.value)} dir="rtl"
                  className="w-full border border-gray-300 rounded-xl px-3 pt-6 pb-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none" />
              </div>
            </div>
          </div>

          {/* Body (bilingual) */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("notifications.body")}</label>
            <div className="grid grid-cols-2 gap-3">
              <div className="relative">
                <span className="absolute top-2 left-2 text-[10px] font-bold text-gray-400">EN</span>
                <textarea value={bodyEn} onChange={e => setBodyEn(e.target.value)} rows={4} dir="ltr"
                  className="w-full border border-gray-300 rounded-xl px-3 pt-6 pb-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
              </div>
              <div className="relative">
                <span className="absolute top-2 right-2 text-[10px] font-bold text-gray-400">AR</span>
                <textarea value={bodyAr} onChange={e => setBodyAr(e.target.value)} rows={4} dir="rtl"
                  className="w-full border border-gray-300 rounded-xl px-3 pt-6 pb-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
              </div>
            </div>
          </div>

          <button type="submit" disabled={sendMut.isPending || !bodyFilled}
            className="flex items-center gap-2 px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition">
            <Send size={15} />
            {sendMut.isPending ? t("notifications.sending") : t("notifications.send")}
          </button>
        </form>

        {/* Live progress while streaming */}
        {sendMut.isPending && progress && progress.totalUsers > 0 && (
          <div className="mt-5 bg-white rounded-2xl border border-gray-200 shadow-sm p-6">
            <div className="flex justify-between text-xs text-gray-500 mb-1.5">
              <span>{t("notifications.sending")}</span>
              <span className="tabular-nums">{progress.processed}/{progress.totalUsers}</span>
            </div>
            <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
              <div className="h-full bg-indigo-600 transition-all duration-300"
                style={{ width: `${Math.min(100, (progress.processed / progress.totalUsers) * 100)}%` }} />
            </div>
          </div>
        )}

        {/* Result card */}
        {result && (
          <div className="mt-5 bg-white rounded-2xl border border-gray-200 shadow-sm p-6">
            <h3 className="text-sm font-semibold text-gray-700">{t("notifications.result")}</h3>
            <p className="text-xs text-gray-400 mb-4">{t("notifications.resultHint")}</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {([
                { label: t("notifications.totalUsers"), desc: t("notifications.totalUsersDesc"), value: result.totalUsers, c: "bg-indigo-50 border-indigo-100 text-indigo-700" },
                { label: t("notifications.successCount"), desc: t("notifications.successCountDesc"), value: result.successCount, c: "bg-green-50 border-green-100 text-green-700" },
                { label: t("notifications.deliveredCount"), desc: t("notifications.deliveredCountDesc"), value: result.deliveredCount, c: "bg-blue-50 border-blue-100 text-blue-700" },
                { label: t("notifications.storedOnlyCount"), desc: t("notifications.storedOnlyCountDesc"), value: result.storedOnlyCount, c: "bg-amber-50 border-amber-100 text-amber-700" },
                { label: t("notifications.failCount"), desc: t("notifications.failCountDesc"), value: result.failCount, c: "bg-red-50 border-red-100 text-red-700" },
              ]).map(({ label, desc, value, c }) => (
                <div key={label} className={`rounded-xl px-4 py-3 border flex items-start gap-3 ${c}`}>
                  <p className="text-2xl font-bold tabular-nums leading-none mt-0.5 shrink-0 w-12">{value ?? 0}</p>
                  <div className="min-w-0">
                    <p className="text-sm font-semibold">{label}</p>
                    <p className="text-xs opacity-70 mt-0.5">{desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
