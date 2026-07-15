"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { login, setCurrentUser } from "@/lib/auth";
import { isDashboardRole, toAppRole, ROLE_LANDING } from "@/lib/rbac";
import api from "@/lib/api";
import toast from "react-hot-toast";
import { GoogleLogin } from "@react-oauth/google";
import { useT } from "@/contexts/LanguageContext";
import { Languages, Eye, EyeOff } from "lucide-react";

function saveTokenAndRedirect(token: string, user: any, _router: ReturnType<typeof useRouter>) {
  if (!isDashboardRole(user.role)) {
    toast.error("Access denied: this account cannot access the dashboard");
    return;
  }
  const expires = new Date();
  expires.setDate(expires.getDate() + 7);
  document.cookie = `token=${token}; path=/; expires=${expires.toUTCString()}; SameSite=Lax`;
  document.cookie = `role=${user.role}; path=/; expires=${expires.toUTCString()}; SameSite=Lax`;
  localStorage.setItem("token", token);
  setCurrentUser(user);
  window.location.href = ROLE_LANDING[toAppRole(user.role)];
}

export default function LoginPage() {
  const router   = useRouter();
  const { t, lang, setLang } = useT();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword]     = useState("");
  const [loading, setLoading]       = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);

  // Detect input type for the icon / input mode hint
  const isPhone = identifier.trim().length > 0 && !identifier.includes("@");
  const inputMode = isPhone ? ("tel" as const) : ("email" as const);

  // ── Email / phone + password ────────────────────────────────────────────
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setLoginError(null);
    try {
      const { redirectTo } = await login(identifier, password);
      window.location.href = redirectTo;
    } catch (err: any) {
      const msg = err.response?.data?.message || err.message || "Login failed";
      setLoginError(msg);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────
  async function handleGoogleSuccess(credentialResponse: { credential?: string }) {
    const idToken = credentialResponse.credential;
    if (!idToken) { toast.error("Google returned no token"); return; }
    setGoogleLoading(true);
    try {
      const res = await api.post("/auth/google/verify", { idToken });
      saveTokenAndRedirect(res.data.token, res.data.user, router);
    } catch (err: any) {
      toast.error(err.response?.data?.message || "Google sign-in failed");
    } finally {
      setGoogleLoading(false);
    }
  }

  // ── Apple ────────────────────────────────────────────────────────────────
  async function handleAppleClick() {
    toast("Apple Sign In requires Apple Developer credentials to be configured.", { icon: "ℹ️" });
  }

  const googleConfigured = !!process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-8">

        {/* Language toggle */}
        <div className="flex justify-end mb-2">
          <button
            onClick={() => setLang(lang === "EN" ? "AR" : "EN")}
            className="flex items-center gap-1.5 text-xs text-gray-500 hover:text-indigo-600 transition px-2 py-1 rounded-lg hover:bg-gray-100">
            <Languages size={14} />
            {t("lang.switch")}
          </button>
        </div>

        {/* Logo / Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-600 mb-4">
            <span className="text-white text-2xl font-bold">T</span>
          </div>
          <h1 className="text-2xl font-bold text-gray-900">{t("auth.title")}</h1>
          <p className="text-gray-500 mt-1 text-sm">{t("auth.subtitle")}</p>
        </div>

        {/* ── OAuth buttons ── */}
        <div className="space-y-3 mb-6">

          {/* Google */}
          <div className={googleLoading ? "opacity-60 pointer-events-none" : ""}>
            {googleConfigured ? (
              <div className="flex justify-center">
                <GoogleLogin
                  onSuccess={handleGoogleSuccess}
                  onError={() => toast.error("Google sign-in failed")}
                  useOneTap={false}
                  text="continue_with"
                  shape="rectangular"
                  theme="outline"
                  size="large"
                  width="400"
                />
              </div>
            ) : (
              <button
                type="button"
                onClick={() => toast("Set NEXT_PUBLIC_GOOGLE_CLIENT_ID in .env.local to enable Google Sign In", { icon: "⚙️" })}
                className="w-full flex items-center justify-center gap-3 border border-gray-300 rounded-lg py-2.5 px-4 text-sm font-medium text-gray-400 hover:bg-gray-50 transition"
              >
                <svg width="18" height="18" viewBox="0 0 48 48">
                  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
                  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
                  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
                  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.18 1.48-4.97 2.36-8.16 2.36-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
                  <path fill="none" d="M0 0h48v48H0z"/>
                </svg>
                Continue with Google
                <span className="ml-auto text-xs bg-gray-100 text-gray-400 px-1.5 py-0.5 rounded">Not configured</span>
              </button>
            )}
          </div>

          {/* Apple */}
          <button
            type="button"
            onClick={handleAppleClick}
            className="w-full flex items-center justify-center gap-3 bg-black hover:bg-gray-900 text-white rounded-lg py-2.5 px-4 text-sm font-medium transition"
          >
            <svg width="17" height="18" viewBox="0 0 814 1000" fill="white">
              <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 376.7 0 248.2 0 127.3 0 57.2 25.3-5 71.1-46c43.1-38.9 108-63.3 171.5-63.3 63.8 0 117.9 26.1 160.7 52.3 42.8 26.1 78.3 52.3 113.8 52.3 35.5 0 75.1-29 124.2-60.9 49.1-32 103.7-52.3 172.4-52.3 131.5 0 249.1 78.3 249.1 210.1zm-262.8 68.8c57.8 0 103.2-38.7 103.2-103.2 0-64.5-45.4-103.2-103.2-103.2-51.5 0-96.8 35.2-118.8 87.8 22 6.4 45.4 9.7 68.7 9.7 16.7 0 32.7-1.9 50.1-1.9z" transform="translate(0 50)"/>
            </svg>
            Continue with Apple
            <span className="ml-auto text-xs bg-white/20 px-1.5 py-0.5 rounded">Not configured</span>
          </button>
        </div>

        {/* Divider */}
        <div className="relative mb-6">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-gray-200" />
          </div>
          <div className="relative flex justify-center text-xs text-gray-400">
            <span className="bg-white px-3">{t("auth.orSignInWith")}</span>
          </div>
        </div>

        {/* Email or phone + password */}
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              {lang === "AR" ? "البريد الإلكتروني أو رقم الهاتف" : "Email or Phone"}
            </label>
            <div className="relative">
              <input
                type="text"
                inputMode={inputMode}
                autoComplete="username"
                required
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition text-[#0f1f3d] bg-white placeholder-gray-400 pr-16"
                placeholder={lang === "AR" ? "بريد إلكتروني أو هاتف" : "Email or phone number"}
              />
              {identifier.trim().length > 0 && (
                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-semibold px-1.5 py-0.5 rounded bg-gray-100 text-gray-500 select-none">
                  {isPhone ? (lang === "AR" ? "هاتف" : "PHONE") : (lang === "AR" ? "بريد" : "EMAIL")}
                </span>
              )}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">{t("auth.password")}</label>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition text-[#0f1f3d] bg-white placeholder-gray-400 pr-11"
                placeholder={t("auth.passwordPlaceholder")}
              />
              <button
                type="button"
                onClick={() => setShowPassword(p => !p)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                tabIndex={-1}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          {loginError && (
            <div className="px-4 py-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 text-center">
              {loginError}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60 text-white font-semibold py-2.5 rounded-lg transition"
          >
            {loading ? t("auth.signingIn") : t("auth.signIn")}
          </button>
        </form>

      </div>
    </div>
  );
}
