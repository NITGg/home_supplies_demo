"use client";

import { useState, useEffect, useCallback } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { X, Loader2, Eye, EyeOff, ShieldCheck, ArrowLeft } from "lucide-react";
import { GoogleLogin } from "@react-oauth/google";
import { isAxiosError } from "axios";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import {
  registerAccount,
  registerAccountWithGoogle,
  verifyAccount,
  requestVerification,
  normalizeEgPhone,
} from "@/lib/admin-auth";
import { fetchSettings } from "@/lib/settings";

interface CreateAccountModalProps {
  isOpen: boolean;
  onClose: () => void;
  /** Role id the new account is registered under (e.g. 1 = Admin, 3 = Customer). */
  roleId: number;
  /** Human label used in titles/messages (e.g. "Admin", "Customer"). */
  label: string;
}

type Phase = "register" | "verify";

/** Identifier the OTP was sent to — email for Google sign-up, phone for manual. */
type Identifier =
  | { type: "phone"; value: string }
  | { type: "email"; value: string };

/** Fallback used until app settings load (or if the value is unset). */
const DEFAULT_RESEND_SECONDS = 60;

const passwordRules = [
  { test: (p: string) => p.length >= 8, label: "At least 8 characters" },
  { test: (p: string) => /[A-Z]/.test(p), label: "One uppercase letter" },
  { test: (p: string) => /[a-z]/.test(p), label: "One lowercase letter" },
  { test: (p: string) => /[0-9]/.test(p), label: "One number" },
];

function apiErrorMessage(error: unknown, fallback: string): string {
  if (isAxiosError(error)) {
    const data = error.response?.data as
      | { message?: string; errors?: { message?: string }[] }
      | undefined;
    if (data?.errors?.length && data.errors[0]?.message) {
      return data.errors[0].message;
    }
    return data?.message || fallback;
  }
  return error instanceof Error ? error.message : fallback;
}

export default function CreateAccountModal({
  isOpen,
  onClose,
  roleId,
  label,
}: CreateAccountModalProps) {
  const queryClient = useQueryClient();
  const googleConfigured = !!process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

  // Resend cooldown comes from app settings (otp_resend_duration_seconds).
  const { data: appSettings } = useQuery({
    queryKey: ["app-settings"],
    queryFn: fetchSettings,
    staleTime: 5 * 60 * 1000,
  });
  const resendSeconds =
    appSettings?.otp_resend_duration_seconds ?? DEFAULT_RESEND_SECONDS;

  const [phase, setPhase] = useState<Phase>("register");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const [identifier, setIdentifier] = useState<Identifier | null>(null);
  const [code, setCode] = useState("");
  const [secondsLeft, setSecondsLeft] = useState(0);

  const reset = useCallback(() => {
    setPhase("register");
    setFullName("");
    setPhone("");
    setPassword("");
    setConfirmPassword("");
    setShowPassword(false);
    setSubmitting(false);
    setIdentifier(null);
    setCode("");
    setSecondsLeft(0);
  }, []);

  const handleClose = useCallback(() => {
    if (submitting) return;
    reset();
    onClose();
  }, [submitting, reset, onClose]);

  // ── Resend countdown ────────────────────────────────────────────────────
  useEffect(() => {
    if (phase !== "verify" || secondsLeft <= 0) return;
    const id = setInterval(() => setSecondsLeft((s) => (s > 0 ? s - 1 : 0)), 1000);
    return () => clearInterval(id);
  }, [phase, secondsLeft]);

  // Move to the verify phase and start the resend cooldown
  const goToVerify = useCallback((id: Identifier) => {
    setIdentifier(id);
    setCode("");
    setPhase("verify");
    setSecondsLeft(resendSeconds);
  }, [resendSeconds]);

  // ── Validation ──────────────────────────────────────────────────────────
  const passwordValid = passwordRules.every((r) => r.test(password));
  const confirmValid = confirmPassword.length > 0 && confirmPassword === password;
  const registerValid =
    fullName.trim().length >= 2 &&
    phone.trim().length > 0 &&
    passwordValid &&
    confirmValid;

  // ── Manual register ───────────────────────────────────────────────────────
  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    if (!registerValid || submitting) return;
    setSubmitting(true);
    try {
      const normalizedPhone = normalizeEgPhone(phone);
      await registerAccount({
        full_name: fullName.trim(),
        phone: normalizedPhone,
        password,
        role_id: roleId,
      });
      toast.success("Account created — enter the code we sent to verify it");
      goToVerify({ type: "phone", value: normalizedPhone });
    } catch (error) {
      toast.error(apiErrorMessage(error, `Failed to create ${label.toLowerCase()}`));
    } finally {
      setSubmitting(false);
    }
  }

  // ── Google register ─────────────────────────────────────────────────────
  async function handleGoogleSuccess(credentialResponse: { credential?: string }) {
    const idToken = credentialResponse.credential;
    if (!idToken) {
      toast.error("Google returned no token");
      return;
    }
    setSubmitting(true);
    try {
      const data = await registerAccountWithGoogle(idToken, roleId);
      const email: string | undefined = data?.user?.email;
      if (email) {
        toast.success("Account created — enter the code we sent to verify it");
        goToVerify({ type: "email", value: email });
      } else {
        // Already verified / no OTP needed — nothing left to do.
        toast.success(`${label} created successfully`);
        queryClient.invalidateQueries({ queryKey: ["users"] });
        handleClose();
      }
    } catch (error) {
      toast.error(apiErrorMessage(error, "Google sign-up failed"));
    } finally {
      setSubmitting(false);
    }
  }

  // ── Verify OTP ──────────────────────────────────────────────────────────
  async function handleVerify(e: React.FormEvent) {
    e.preventDefault();
    if (!identifier || !code.trim() || submitting) return;
    setSubmitting(true);
    try {
      await verifyAccount({ [identifier.type]: identifier.value, code: code.trim() });
      toast.success(`${label} verified successfully`);
      queryClient.invalidateQueries({ queryKey: ["users"] });
      handleClose();
    } catch (error) {
      toast.error(apiErrorMessage(error, "Verification failed"));
    } finally {
      setSubmitting(false);
    }
  }

  // ── Resend OTP ──────────────────────────────────────────────────────────
  async function handleResend() {
    if (!identifier || secondsLeft > 0 || submitting) return;
    setSubmitting(true);
    try {
      await requestVerification({ [identifier.type]: identifier.value });
      toast.success("A new code has been sent");
      setSecondsLeft(resendSeconds);
    } catch (error) {
      toast.error(apiErrorMessage(error, "Failed to resend code"));
    } finally {
      setSubmitting(false);
    }
  }

  if (!isOpen) return null;

  const inputCls =
    "w-full px-3 py-2 border rounded-lg text-sm text-gray-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition";

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 sticky top-0 bg-white z-10">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <ShieldCheck size={18} className="text-indigo-600" />
            {phase === "register" ? `Create ${label}` : `Verify ${label} Account`}
          </h2>
          <button
            onClick={handleClose}
            disabled={submitting}
            className="p-1.5 hover:bg-gray-100 rounded-lg transition disabled:opacity-50"
          >
            <X size={18} />
          </button>
        </div>

        {phase === "register" ? (
          <form onSubmit={handleRegister} className="p-6 space-y-5">
            {/* Google sign-up */}
            <div>
              {googleConfigured ? (
                <div
                  className={cn(
                    "flex justify-center",
                    submitting && "opacity-60 pointer-events-none",
                  )}
                >
                  <GoogleLogin
                    onSuccess={handleGoogleSuccess}
                    onError={() => toast.error("Google sign-up failed")}
                    useOneTap={false}
                    text="signup_with"
                    shape="rectangular"
                    theme="outline"
                    size="large"
                    width="352"
                  />
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() =>
                    toast("Set NEXT_PUBLIC_GOOGLE_CLIENT_ID in .env to enable Google sign-up", { icon: "⚙️" })
                  }
                  className="w-full flex items-center justify-center gap-3 border border-gray-300 rounded-lg py-2.5 px-4 text-sm font-medium text-gray-400 hover:bg-gray-50 transition"
                >
                  <svg width="18" height="18" viewBox="0 0 48 48">
                    <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
                    <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
                    <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
                    <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.18 1.48-4.97 2.36-8.16 2.36-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
                  </svg>
                  Sign up with Google
                  <span className="ml-auto text-xs bg-gray-100 text-gray-400 px-1.5 py-0.5 rounded">
                    Not configured
                  </span>
                </button>
              )}
            </div>

            {/* Divider */}
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-200" />
              </div>
              <div className="relative flex justify-center text-xs text-gray-400">
                <span className="bg-white px-3">or register manually</span>
              </div>
            </div>

            {/* Full name */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Full Name <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                className={cn(inputCls, "border-gray-300")}
                placeholder="John Doe"
                disabled={submitting}
              />
            </div>

            {/* Phone */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Phone <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                onBlur={() => setPhone((p) => (p.trim() ? normalizeEgPhone(p) : p))}
                className={cn(inputCls, "border-gray-300")}
                placeholder="+201012345678"
                disabled={submitting}
              />
            </div>

            {/* Password */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Password <span className="text-red-500">*</span>
              </label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className={cn(inputCls, "pr-10 border-gray-300")}
                  placeholder="••••••••"
                  disabled={submitting}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((p) => !p)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {password.length > 0 && (
                <ul className="mt-2 space-y-0.5">
                  {passwordRules.map((r) => {
                    const ok = r.test(password);
                    return (
                      <li
                        key={r.label}
                        className={cn(
                          "text-xs flex items-center gap-1.5",
                          ok ? "text-green-600" : "text-gray-400",
                        )}
                      >
                        <span>{ok ? "✓" : "•"}</span>
                        {r.label}
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>

            {/* Confirm password */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Confirm Password <span className="text-red-500">*</span>
              </label>
              <input
                type={showPassword ? "text" : "password"}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className={cn(
                  inputCls,
                  confirmPassword.length > 0 && !confirmValid
                    ? "border-red-400 focus:ring-red-500 focus:border-red-500"
                    : "border-gray-300",
                )}
                placeholder="••••••••"
                disabled={submitting}
              />
              {confirmPassword.length > 0 && !confirmValid && (
                <p className="mt-1 text-xs text-red-600">Passwords do not match</p>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-2">
              <button
                type="button"
                onClick={handleClose}
                disabled={submitting}
                className="flex-1 border border-gray-300 rounded-lg py-2.5 text-sm font-medium hover:bg-gray-50 transition disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={!registerValid || submitting}
                className="flex-1 flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition"
              >
                {submitting && <Loader2 size={16} className="animate-spin" />}
                {submitting ? "Creating..." : `Create ${label}`}
              </button>
            </div>
          </form>
        ) : (
          <form onSubmit={handleVerify} className="p-6 space-y-5">
            <button
              type="button"
              onClick={() => setPhase("register")}
              disabled={submitting}
              className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition disabled:opacity-50"
            >
              <ArrowLeft size={15} /> Back
            </button>

            <p className="text-sm text-gray-600">
              We sent a verification code to{" "}
              <span className="font-semibold text-gray-900">
                {identifier?.value}
              </span>
              . Enter it below to activate the {label.toLowerCase()} account.
            </p>

            {/* OTP */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Verification Code <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                inputMode="numeric"
                autoFocus
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\s/g, ""))}
                className={cn(inputCls, "border-gray-300 tracking-[0.3em] text-center text-lg")}
                placeholder="••••••"
                disabled={submitting}
              />
            </div>

            {/* Resend */}
            <div className="text-center text-sm">
              {secondsLeft > 0 ? (
                <span className="text-gray-500">
                  Resend code in{" "}
                  <span className="font-semibold text-gray-700 tabular-nums">
                    0:{String(secondsLeft).padStart(2, "0")}
                  </span>
                </span>
              ) : (
                <button
                  type="button"
                  onClick={handleResend}
                  disabled={submitting}
                  className="font-medium text-indigo-600 hover:text-indigo-700 transition disabled:opacity-50"
                >
                  Resend code
                </button>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-2">
              <button
                type="button"
                onClick={handleClose}
                disabled={submitting}
                className="flex-1 border border-gray-300 rounded-lg py-2.5 text-sm font-medium hover:bg-gray-50 transition disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={!code.trim() || submitting}
                className="flex-1 flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition"
              >
                {submitting && <Loader2 size={16} className="animate-spin" />}
                {submitting ? "Verifying..." : "Verify Account"}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
