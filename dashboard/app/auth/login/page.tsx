"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { api } from "@/lib/api";

type Step = "phone" | "otp";

export default function LoginPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
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
      const res = await api.post<{ access_token: string; user_id: string }>("/v1/auth/verify-otp", { phone, code: otp });
      api.setToken(res.access_token);
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
        {/* Logo */}
        <div className="text-center mb-10">
          <Link href="/">
            <span className="font-fraunces text-5xl font-black text-[#C47B2B]">Hapa</span>
          </Link>
          <p className="font-mono text-xs text-stone-500 uppercase tracking-widest mt-1">Business Sign In</p>
        </div>

        <div className="border border-stone-800 p-8 bg-stone-900/50">
          {step === "phone" ? (
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
              </div>
              {error && <p className="text-red-400 text-xs font-mono">{error}</p>}
              <button
                type="submit"
                disabled={loading}
                className="w-full font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-[#1A1208] font-bold py-3 hover:bg-[#E8A84A] transition-colors disabled:opacity-50"
              >
                {loading ? "Sending..." : "Send OTP"}
              </button>
            </form>
          ) : (
            <form onSubmit={handleVerifyOtp} className="space-y-5">
              <p className="text-stone-400 text-sm">
                Enter the 6-digit code sent to <span className="text-stone-200">{phone}</span>
              </p>
              <div>
                <label className="font-mono text-xs uppercase tracking-widest text-stone-400 block mb-2">
                  OTP Code
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
                disabled={loading}
                className="w-full font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-[#1A1208] font-bold py-3 hover:bg-[#E8A84A] transition-colors disabled:opacity-50"
              >
                {loading ? "Verifying..." : "Sign In"}
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
        </div>

        <p className="text-center text-stone-500 text-xs mt-6">
          No account?{" "}
          <Link href="/auth/register" className="text-[#C47B2B] hover:underline">
            Register your business
          </Link>
        </p>
      </div>
    </div>
  );
}
