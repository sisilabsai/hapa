"use client";
import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Settings, Bell, CreditCard, Shield, User, Check, ChevronRight } from "lucide-react";

type NotifPrefs = {
  new_booking: boolean;
  booking_reminder: boolean;
  new_review: boolean;
  boost_report: boolean;
  creator_reply: boolean;
  weekly_summary: boolean;
};

type BillingInfo = {
  tier: string;
  renewal_date?: string;
  payment_method?: string;
};

export default function SettingsPage() {
  const [activeSection, setActiveSection] = useState<string>("profile");

  const sections = [
    { id: "profile", label: "Profile", icon: User },
    { id: "notifications", label: "Notifications", icon: Bell },
    { id: "billing", label: "Billing & Plan", icon: CreditCard },
    { id: "security", label: "Security", icon: Shield },
  ];

  return (
    <div className="p-8 max-w-5xl">
      <div className="mb-8">
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <Settings className="text-[#C47B2B]" size={28} />
          Settings
        </h1>
      </div>

      <div className="grid grid-cols-4 gap-8">
        {/* Nav */}
        <div className="col-span-1">
          <nav className="space-y-0.5">
            {sections.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActiveSection(id)}
                className={`w-full flex items-center gap-3 px-3 py-2.5 text-left transition-colors ${
                  activeSection === id
                    ? "bg-[#C47B2B]/10 text-[#C47B2B] border-r-2 border-[#C47B2B]"
                    : "text-stone-600 hover:bg-stone-100"
                }`}
              >
                <Icon size={14} className="shrink-0" />
                <span className="text-sm font-medium">{label}</span>
              </button>
            ))}
          </nav>
        </div>

        {/* Content */}
        <div className="col-span-3">
          {activeSection === "profile" && <ProfileSection />}
          {activeSection === "notifications" && <NotificationsSection />}
          {activeSection === "billing" && <BillingSection />}
          {activeSection === "security" && <SecuritySection />}
        </div>
      </div>
    </div>
  );
}

function ProfileSection() {
  const [form, setForm] = useState({ name: "", email: "", phone: "" });
  const mutation = useMutation({
    mutationFn: () => api.put("/v1/users/me", form),
    onSuccess: () => alert("Profile updated"),
  });

  return (
    <div className="bg-white border border-stone-200 p-6 space-y-5">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">Profile</h2>

      <Field label="Display Name">
        <input
          type="text"
          value={form.name}
          onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
          placeholder="Business Owner"
          className="input"
        />
      </Field>

      <Field label="Email (optional)">
        <input
          type="email"
          value={form.email}
          onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
          placeholder="you@example.com"
          className="input"
        />
      </Field>

      <Field label="Phone">
        <input
          type="tel"
          value={form.phone}
          onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))}
          placeholder="+256 700 000 000"
          className="input"
          disabled
        />
        <span className="font-mono text-[10px] text-stone-400 mt-1 block">
          Phone is your primary identity and cannot be changed here.
        </span>
      </Field>

      <button
        onClick={() => mutation.mutate()}
        disabled={mutation.isPending}
        className="font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white px-6 py-2.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40"
      >
        {mutation.isPending ? "Saving…" : "Save Changes"}
      </button>
    </div>
  );
}

function NotificationsSection() {
  const [prefs, setPrefs] = useState<NotifPrefs>({
    new_booking: true,
    booking_reminder: true,
    new_review: true,
    boost_report: false,
    creator_reply: true,
    weekly_summary: true,
  });

  const mutation = useMutation({
    mutationFn: () => api.put("/v1/users/me/notification-prefs", prefs),
    onSuccess: () => {},
  });

  const toggle = (key: keyof NotifPrefs) => {
    setPrefs((p) => {
      const next = { ...p, [key]: !p[key] };
      mutation.mutate();
      return next;
    });
  };

  const items: { key: keyof NotifPrefs; label: string; desc: string }[] = [
    { key: "new_booking", label: "New Booking", desc: "When a customer books your business" },
    { key: "booking_reminder", label: "Booking Reminders", desc: "1 hour before upcoming bookings" },
    { key: "new_review", label: "New Reviews", desc: "When someone leaves a review" },
    { key: "boost_report", label: "Boost Report", desc: "Summary when a boost campaign ends" },
    { key: "creator_reply", label: "Creator Replies", desc: "When a creator responds to your proposal" },
    { key: "weekly_summary", label: "Weekly Summary", desc: "Performance recap every Monday" },
  ];

  return (
    <div className="bg-white border border-stone-200 p-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3 mb-5">
        Notification Preferences
      </h2>
      <div className="space-y-4">
        {items.map(({ key, label, desc }) => (
          <div key={key} className="flex items-center justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-stone-900">{label}</p>
              <p className="font-mono text-[10px] text-stone-400">{desc}</p>
            </div>
            <button
              onClick={() => toggle(key)}
              className={`w-11 h-6 rounded-full relative transition-colors shrink-0 ${
                prefs[key] ? "bg-[#C47B2B]" : "bg-stone-200"
              }`}
            >
              <span
                className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow-sm transition-transform ${
                  prefs[key] ? "translate-x-5" : "translate-x-0.5"
                }`}
              />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

function BillingSection() {
  const TIERS = [
    {
      name: "Free",
      price: "$0",
      features: ["1 business listing", "Basic map presence", "Hapa Boost (pay-per-boost)", "Up to 5 photos"],
      current: true,
    },
    {
      name: "Growth",
      price: "$10–$30",
      period: "/mo",
      features: ["Up to 3 listings", "In-app bookings", "Priority map ranking", "Creator partnerships", "Up to 30 photos", "Basic analytics"],
      current: false,
    },
    {
      name: "Pro",
      price: "$30–$80",
      period: "/mo",
      features: ["Unlimited listings", "Everything in Growth", "Advanced analytics", "Featured placement", "Dedicated support", "Bulk boost credits"],
      current: false,
    },
  ];

  return (
    <div className="space-y-4">
      <div className="bg-white border border-stone-200 p-6">
        <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3 mb-5">
          Current Plan
        </h2>
        <div className="flex items-center gap-4 mb-6">
          <div className="flex-1">
            <p className="font-fraunces text-2xl font-bold text-stone-900">Free Tier</p>
            <p className="text-stone-500 text-sm mt-1">Great for getting started. Upgrade when you see the value.</p>
          </div>
          <span className="font-mono text-[10px] uppercase tracking-widest bg-stone-100 text-stone-500 px-3 py-1.5">
            Active
          </span>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        {TIERS.map((tier) => (
          <div
            key={tier.name}
            className={`bg-white border p-5 ${
              tier.current ? "border-[#C47B2B]" : "border-stone-200"
            }`}
          >
            {tier.current && (
              <span className="font-mono text-[9px] uppercase tracking-widest bg-[#C47B2B] text-white px-2 py-0.5 mb-3 inline-block">
                Current
              </span>
            )}
            <div className="font-fraunces text-xl font-bold text-stone-900">{tier.name}</div>
            <div className="mt-1 mb-4">
              <span className="font-fraunces text-2xl font-black text-stone-900">{tier.price}</span>
              {tier.period && <span className="text-stone-400 text-sm">{tier.period}</span>}
            </div>
            <ul className="space-y-2 mb-5">
              {tier.features.map((f) => (
                <li key={f} className="flex items-start gap-2 text-xs text-stone-600">
                  <Check size={11} className="text-[#C47B2B] mt-0.5 shrink-0" />
                  {f}
                </li>
              ))}
            </ul>
            {!tier.current && (
              <button className="w-full font-mono text-[10px] uppercase tracking-widest border border-[#C47B2B] text-[#C47B2B] py-2 hover:bg-[#C47B2B] hover:text-white transition-colors">
                Upgrade
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function SecuritySection() {
  const mutation = useMutation({
    mutationFn: () => api.post("/v1/auth/logout", {}),
    onSuccess: () => {
      api.setToken("");
      window.location.href = "/auth/login";
    },
  });

  return (
    <div className="bg-white border border-stone-200 p-6 space-y-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">Security</h2>

      <div>
        <p className="text-sm font-medium text-stone-900 mb-1">Two-Factor Authentication</p>
        <p className="font-mono text-[10px] text-stone-400 mb-3">
          Your account is secured by phone OTP. No passwords are stored.
        </p>
        <div className="flex items-center gap-2 bg-green-50 border border-green-200 px-4 py-2.5 inline-flex">
          <Check size={13} className="text-green-600" />
          <span className="font-mono text-[10px] text-green-700 uppercase tracking-widest">Phone OTP active</span>
        </div>
      </div>

      <div className="border-t border-stone-100 pt-6">
        <p className="text-sm font-medium text-stone-900 mb-1">Active Sessions</p>
        <p className="font-mono text-[10px] text-stone-400 mb-3">
          You are signed in on this device. Signing out will require re-verifying your phone number.
        </p>
        <button
          onClick={() => mutation.mutate()}
          disabled={mutation.isPending}
          className="font-mono text-xs uppercase tracking-widest border border-red-300 text-red-500 px-5 py-2.5 hover:bg-red-50 transition-colors disabled:opacity-40"
        >
          {mutation.isPending ? "Signing out…" : "Sign Out"}
        </button>
      </div>

      <div className="border-t border-stone-100 pt-6">
        <p className="text-sm font-medium text-stone-700 mb-1">Delete Account</p>
        <p className="font-mono text-[10px] text-stone-400 mb-3">
          Permanently delete your account and all associated data. This cannot be undone.
        </p>
        <button className="font-mono text-[10px] uppercase tracking-widest text-red-400 hover:text-red-600 transition-colors">
          Request account deletion →
        </button>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="font-mono text-[10px] uppercase tracking-widest text-stone-400 block mb-2">
        {label}
      </label>
      {children}
    </div>
  );
}
