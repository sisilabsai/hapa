"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { api } from "@/lib/api";

type Step = "phone" | "otp" | "profile";

export default function RegisterPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSendOtp(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await api.post("/v1/auth/send-otp", { phone });
      setStep("otp");
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleVerifyOtp(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await api.post<{ access_token: string; is_new_user: boolean }>(
        "/v1/auth/verify-otp",
        { phone, code: otp }
      );
      api.setToken(res.access_token);
      if (res.is_new_user) {
        setStep("profile");
      } else {
        router.push("/dashboard");
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleProfile(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await api.put("/v1/users/me", { display_name: name });
      router.push("/dashboard");
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-[#1A1208] flex items-center justify-center px-6">
      <div className="w-full max-w-sm">
        <div className="text-center mb-10">
          <Link href="/">
            <span className="font-fraunces text-5xl font-black text-[#C47B2B]">Hapa</span>
          </Link>
          <p className="font-mono text-xs text-stone-500 uppercase tracking-widest mt-1">
            Business Dashboard
          </p>
        </div>

        {/* Step pills */}
        <div className="flex items-center justify-center gap-2 mb-8">
          {(["phone", "otp", "profile"] as const).map((s, i) => (
            <div key={s} className="flex items-center gap-2">
              <div
                className={`w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-bold font-mono transition-colors ${
                  s === step
                    ? "bg-[#C47B2B] text-white"
                    : ["phone", "otp", "profile"].indexOf(step) > i
                    ? "bg-[#C47B2B]/30 text-[#C47B2B]"
                    : "bg-stone-800 text-stone-600"
                }`}
              >
                {i + 1}
              </div>
              {i < 2 && <div className="w-6 h-px bg-stone-700" />}
            </div>
          ))}
        </div>

        <div className="border border-stone-800 p-8 bg-stone-900/50">
          {step === "phone" && (
            <form onSubmit={handleSendOtp} className="space-y-5">
              <div>
                <label className="font-mono text-xs uppercase tracking-widest text-stone-400 block mb-2">
                  Phone Number
                </label>
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+256 700 000 000"
                  required
                  className="w-full bg-stone-800 border border-stone-700 text-stone-100 px-4 py-3 text-sm focus:outline-none focus:border-[#C47B2B] placeholder:text-stone-600"
                />
                <p className="font-mono text-[10px] text-stone-600 mt-2">
                  Already a Hapa user? Sign in with the same number — no new account needed.
                </p>
              </div>
              {error && <p className="text-red-400 text-xs font-mono">{error}</p>}
              <button
                type="submit"
                disabled={loading || !phone}
                className="w-full font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-[#1A1208] font-bold py-3 hover:bg-[#E8A84A] transition-colors disabled:opacity-50"
              >
                {loading ? "Sending…" : "Send Code"}
              </button>
            </form>
          )}

          {step === "otp" && (
            <form onSubmit={handleVerifyOtp} className="space-y-5">
              <p className="text-stone-400 text-sm">
                Code sent to <span className="text-stone-200">{phone}</span>
              </p>
              <div>
                <label className="font-mono text-xs uppercase tracking-widest text-stone-400 block mb-2">
                  Verification Code
                </label>
                <input
                  type="text"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value)}
                  placeholder="000000"
                  maxLength={6}
                  required
                  className="w-full bg-stone-800 border border-stone-700 text-stone-100 px-4 py-3 text-sm text-center tracking-widest text-xl focus:outline-none focus:border-[#C47B2B] placeholder:text-stone-600"
                />
              </div>
              {error && <p className="text-red-400 text-xs font-mono">{error}</p>}
              <button
                type="submit"
                disabled={loading || otp.length < 6}
                className="w-full font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-[#1A1208] font-bold py-3 hover:bg-[#E8A84A] transition-colors disabled:opacity-50"
              >
                {loading ? "Verifying…" : "Verify"}
              </button>
              <button
                type="button"
                onClick={() => setStep("phone")}
                className="w-full text-xs text-stone-500 hover:text-stone-300 transition-colors"
              >
                Change number
              </button>
            </form>
          )}

          {step === "profile" && (
            <form onSubmit={handleProfile} className="space-y-5">
              <p className="text-stone-400 text-sm">
                Almost there! Tell us your name.
              </p>
              <div>
                <label className="font-mono text-xs uppercase tracking-widest text-stone-400 block mb-2">
                  Your Name
                </label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Jane Nakato"
                  required
                  className="w-full bg-stone-800 border border-stone-700 text-stone-100 px-4 py-3 text-sm focus:outline-none focus:border-[#C47B2B] placeholder:text-stone-600"
                />
              </div>
              {error && <p className="text-red-400 text-xs font-mono">{error}</p>}
              <button
                type="submit"
                disabled={loading || !name}
                className="w-full font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-[#1A1208] font-bold py-3 hover:bg-[#E8A84A] transition-colors disabled:opacity-50"
              >
                {loading ? "Setting up…" : "Continue →"}
              </button>
            </form>
          )}
        </div>

        <p className="text-center text-stone-500 text-xs mt-6">
          Already registered?{" "}
          <Link href="/auth/login" className="text-[#C47B2B] hover:underline">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
