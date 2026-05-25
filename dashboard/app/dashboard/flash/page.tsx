"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { endpoints, Business, FlashPost } from "@/lib/api";
import {
  Zap, Clock, Sparkles, AlertCircle, CheckCircle2, Building2,
  MapPin, Flame, Timer, Star, Eye, TrendingUp, Plus, X,
} from "lucide-react";
import { formatDistanceToNow, addHours } from "date-fns";

// ── Expiry options ─────────────────────────────────────────────────────────────

const EXPIRY_OPTIONS = [
  { hours: 1, label: "1 hour", icon: "⚡", note: "Flash deal — max urgency" },
  { hours: 2, label: "2 hours", icon: "🔥", note: "Lunch / happy hour window" },
  { hours: 4, label: "4 hours", icon: "☀️", note: "Half-day event" },
  { hours: 8, label: "8 hours", icon: "📅", note: "Full session" },
  { hours: 12, label: "12 hours", icon: "🌗", note: "Day-long special" },
  { hours: 24, label: "24 hours", icon: "🌙", note: "Extended run" },
];

// ── Category-specific prompts ──────────────────────────────────────────────────

const QUICK_PROMPTS: Record<string, string[]> = {
  restaurant: ["Live music starting now", "Flash discount on mains", "Happy hour extended", "Chef's special just landed"],
  nightlife: ["DJ set starting soon", "Free entry before 10pm", "Bottle service deal", "VIP table available"],
  cafe: ["Fresh batch just out of oven", "Buy 1 get 1 coffee", "Wi-Fi + workspace available", "Live jazz this afternoon"],
  retail: ["Flash sale — selected items", "New stock just arrived", "Last chance clearance", "Exclusive members deal"],
  default: ["Special offer today only", "Limited availability", "Just opened", "Don't miss this"],
};

// ── Countdown display ──────────────────────────────────────────────────────────

function Countdown({ expiresAt }: { expiresAt: string }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  const expiry = new Date(expiresAt).getTime();
  const remaining = expiry - now;
  if (remaining <= 0) return <span className="text-red-500 font-mono text-[10px]">Expired</span>;

  const hours = Math.floor(remaining / 3600000);
  const mins = Math.floor((remaining % 3600000) / 60000);

  return (
    <span className="flex items-center gap-1 font-mono text-[11px] text-[#C47B2B]">
      <Timer size={10} />
      {hours > 0 ? `${hours}h ${mins}m` : `${mins}m`} left
    </span>
  );
}

// ── Active flash card ──────────────────────────────────────────────────────────

function ActiveFlashCard({ flash }: { flash: FlashPost }) {
  const isExpired = flash.expires_at ? new Date(flash.expires_at) < new Date() : false;

  return (
    <div className={`border p-4 transition-all ${isExpired ? "border-stone-100 opacity-50" : "border-stone-200 bg-white"}`}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <p className="text-stone-800 text-sm leading-snug">{flash.body}</p>
          <div className="flex items-center gap-3 mt-2">
            {flash.expires_at && !isExpired && <Countdown expiresAt={flash.expires_at} />}
            {isExpired && <span className="font-mono text-[10px] text-stone-400">Ended {formatDistanceToNow(new Date(flash.expires_at!), { addSuffix: true })}</span>}
            <span className="flex items-center gap-1 font-mono text-[10px] text-stone-400">
              <Flame size={9} /> {flash.pulse_count} pulses
            </span>
            <span className="font-mono text-[10px] text-stone-300">
              {formatDistanceToNow(new Date(flash.created_at), { addSuffix: true })}
            </span>
          </div>
        </div>
        <span className={`font-mono text-[9px] uppercase tracking-widest px-2 py-0.5 shrink-0 ${
          isExpired ? "bg-stone-100 text-stone-400" : "bg-amber-50 text-amber-700"
        }`}>
          {isExpired ? "Ended" : "Live"}
        </span>
      </div>
      {!isExpired && flash.pulse_count >= 5 && (
        <div className="mt-3 flex items-center gap-1.5 bg-amber-50 border border-amber-100 px-3 py-1.5">
          <TrendingUp size={11} className="text-amber-600" />
          <span className="font-mono text-[10px] text-amber-700">
            Trending — {flash.pulse_count} community confirmations
          </span>
        </div>
      )}
    </div>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────

export default function FlashPage() {
  const qc = useQueryClient();
  const [selectedBiz, setSelectedBiz] = useState<Business | null>(null);
  const [text, setText] = useState("");
  const [expiryHours, setExpiryHours] = useState(2);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiPrompt, setAiPrompt] = useState("");
  const [aiError, setAiError] = useState("");
  const [showAiPanel, setShowAiPanel] = useState(false);
  const [launched, setLaunched] = useState(false);

  const { data: bizData, isLoading: bizLoading } = useQuery({
    queryKey: ["my-businesses"],
    queryFn: () => endpoints.business.mine(),
  });

  const businesses = bizData?.businesses ?? [];
  const prompts = QUICK_PROMPTS[selectedBiz?.category?.toLowerCase() ?? ""] ?? QUICK_PROMPTS.default;

  const handleGenerateFlash = async () => {
    if (!selectedBiz) return;
    setAiLoading(true);
    setAiError("");
    try {
      const result = await endpoints.ai.flashCopy({
        business_name: selectedBiz.name,
        category: selectedBiz.category,
        city: selectedBiz.city,
        prompt: aiPrompt || undefined,
      });
      setText(result.text ?? "");
    } catch {
      setAiError("AI unavailable — try writing your own Flash below");
    } finally {
      setAiLoading(false);
    }
  };

  const createMutation = useMutation({
    mutationFn: () => {
      const expiresAt = addHours(new Date(), expiryHours).toISOString();
      return endpoints.flash.create({
        post_type: "flash",
        content: text,
        business_id: selectedBiz?.id,
        lat: selectedBiz?.lat,
        lng: selectedBiz?.lng,
        city: selectedBiz?.city,
        expires_at: expiresAt,
      });
    },
    onSuccess: () => {
      setLaunched(true);
      setText("");
      setAiPrompt("");
      qc.invalidateQueries({ queryKey: ["flash-posts"] });
      setTimeout(() => setLaunched(false), 4000);
    },
  });

  const canPost = !!selectedBiz && text.length > 0 && text.length <= 140;
  const expiryTime = addHours(new Date(), expiryHours);

  return (
    <div className="p-8 max-w-5xl space-y-8">
      {/* Header */}
      <div>
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <Flame className="text-[#C47B2B]" size={28} />
          Hapa Flash
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Real-time, time-limited announcements that drive immediate foot traffic. Auto-expires. Creates urgency.
        </p>
      </div>

      {/* What is Hapa Flash */}
      <div className="bg-[#1A1208] p-6 grid grid-cols-3 gap-6">
        {[
          { icon: "⚡", title: "Goes live instantly", desc: "Posted to Hapa Now — visible to everyone near your business the moment you publish." },
          { icon: "🔥", title: "Community confirms it", desc: "Users tap Pulse to confirm they see it happening. More pulses = city-wide alert." },
          { icon: "⏱️", title: "Auto-expires", desc: "Choose 1–24 hours. Hapa removes it automatically. No stale content, always urgent." },
        ].map(({ icon, title, desc }) => (
          <div key={title}>
            <div className="text-2xl mb-2">{icon}</div>
            <div className="font-fraunces text-white font-semibold text-sm mb-1">{title}</div>
            <div className="text-stone-400 text-xs leading-relaxed">{desc}</div>
          </div>
        ))}
      </div>

      {/* Business selector */}
      <section>
        <SectionLabel step={1} title="Choose your business" />
        {bizLoading ? (
          <div className="flex gap-3">
            {[1, 2].map((i) => <div key={i} className="w-48 h-24 bg-stone-100 animate-pulse" />)}
          </div>
        ) : (
          <div className="flex gap-3 overflow-x-auto pb-2">
            {businesses.map((biz) => (
              <button
                key={biz.id}
                onClick={() => setSelectedBiz(biz)}
                className={`relative text-left border p-4 shrink-0 w-48 transition-all ${
                  selectedBiz?.id === biz.id
                    ? "border-[#C47B2B] bg-[#C47B2B]/5 ring-1 ring-[#C47B2B]"
                    : "border-stone-200 bg-white hover:border-[#C47B2B]/50"
                }`}
              >
                {selectedBiz?.id === biz.id && <CheckCircle2 size={12} className="absolute top-2 right-2 text-[#C47B2B]" />}
                {biz.cover_url
                  ? <img src={biz.cover_url} alt="" className="w-full h-14 object-cover mb-2" />
                  : <div className="w-full h-14 bg-stone-100 flex items-center justify-center mb-2"><Building2 size={18} className="text-stone-300" /></div>}
                <p className="font-semibold text-stone-900 text-xs truncate">{biz.name}</p>
                <p className="font-mono text-[9px] text-stone-400 uppercase mt-0.5 truncate">{biz.category}</p>
                {biz.neighbourhood && (
                  <p className="font-mono text-[9px] text-stone-400 flex items-center gap-0.5 mt-0.5">
                    <MapPin size={8} /> {biz.neighbourhood}
                  </p>
                )}
              </button>
            ))}
          </div>
        )}
      </section>

      {selectedBiz && (
        <div className="grid grid-cols-[1fr_320px] gap-8">
          {/* Left: Composer */}
          <div className="space-y-5">
            {/* Step 2: Expiry */}
            <section className="bg-white border border-stone-200 p-6">
              <SectionLabel step={2} title="How long should it run?" />
              <div className="grid grid-cols-3 gap-2">
                {EXPIRY_OPTIONS.map((opt) => (
                  <button
                    key={opt.hours}
                    onClick={() => setExpiryHours(opt.hours)}
                    className={`text-left border p-3 transition-all ${
                      expiryHours === opt.hours
                        ? "border-[#C47B2B] bg-[#C47B2B]/5"
                        : "border-stone-200 hover:border-stone-300"
                    }`}
                  >
                    <span className="block text-lg">{opt.icon}</span>
                    <span className="block font-fraunces font-semibold text-stone-800 text-sm mt-1">{opt.label}</span>
                    <span className="block font-mono text-[9px] text-stone-400 mt-0.5">{opt.note}</span>
                  </button>
                ))}
              </div>
            </section>

            {/* Step 3: Flash text */}
            <section className="bg-white border border-stone-200 p-6 space-y-4">
              <SectionLabel step={3} title="Write your Flash" />

              {/* Quick prompts */}
              <div>
                <p className="font-mono text-[10px] text-stone-400 uppercase tracking-widest mb-2">Quick prompts</p>
                <div className="flex flex-wrap gap-2">
                  {prompts.map((p) => (
                    <button
                      key={p}
                      onClick={() => setAiPrompt(p)}
                      className="font-mono text-[10px] text-stone-600 border border-stone-200 px-2.5 py-1 hover:border-[#C47B2B] hover:text-[#C47B2B] transition-colors"
                    >
                      {p}
                    </button>
                  ))}
                </div>
              </div>

              {/* AI panel */}
              <div className="bg-stone-50 border border-stone-200 p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">AI Flash Writer</p>
                  <button onClick={() => setShowAiPanel(!showAiPanel)} className="text-stone-400 hover:text-stone-600">
                    {showAiPanel ? <X size={13} /> : <Plus size={13} />}
                  </button>
                </div>
                {showAiPanel && (
                  <>
                    <input
                      type="text"
                      placeholder={`What's happening at ${selectedBiz.name} right now?`}
                      value={aiPrompt}
                      onChange={(e) => setAiPrompt(e.target.value)}
                      className="input text-sm w-full"
                      onKeyDown={(e) => e.key === "Enter" && handleGenerateFlash()}
                    />
                    {aiError && (
                      <p className="flex items-center gap-1.5 text-red-500 font-mono text-[11px]">
                        <AlertCircle size={11} /> {aiError}
                      </p>
                    )}
                  </>
                )}
                <button
                  onClick={handleGenerateFlash}
                  disabled={aiLoading}
                  className="flex items-center gap-2 bg-stone-900 text-white font-mono text-[11px] uppercase tracking-widest px-4 py-2 hover:bg-stone-700 transition-colors disabled:opacity-50"
                >
                  <Sparkles size={12} className={aiLoading ? "animate-spin" : ""} />
                  {aiLoading ? "Writing…" : "Generate Flash with AI"}
                </button>
              </div>

              {/* Text area */}
              <div className="relative">
                <textarea
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  placeholder="Live music starting in 20 mins at Cayenne — free entry before 9pm!"
                  className="input w-full min-h-[90px] resize-none text-sm pr-16"
                  maxLength={140}
                />
                <span className={`absolute bottom-3 right-3 font-mono text-[11px] ${
                  text.length > 120 ? "text-amber-500" : text.length > 140 ? "text-red-500" : "text-stone-400"
                }`}>
                  {140 - text.length}
                </span>
              </div>

              <p className="font-mono text-[10px] text-stone-400">
                Keep it specific, urgent, and honest. Vague flashes get ignored.
              </p>
            </section>
          </div>

          {/* Right: Preview + launch */}
          <div className="space-y-4 sticky top-6">
            {/* Preview */}
            <div className="bg-[#1A1208] border border-stone-800 p-5">
              <p className="font-mono text-[10px] text-stone-500 uppercase tracking-widest mb-3">Hapa Now preview</p>

              {/* Flash card as it appears in feed */}
              <div className="bg-stone-900 rounded-xl p-4 space-y-3">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 bg-[#C47B2B] rounded-lg flex items-center justify-center shrink-0">
                    {selectedBiz.logo_url
                      ? <img src={selectedBiz.logo_url} alt="" className="w-full h-full object-cover rounded-lg" />
                      : <span className="font-fraunces font-black text-white text-xs">{selectedBiz.name.charAt(0)}</span>}
                  </div>
                  <div>
                    <p className="text-white text-xs font-medium">{selectedBiz.name}</p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="font-mono text-[9px] text-amber-400 uppercase tracking-widest flex items-center gap-0.5">
                        <Flame size={8} /> Flash
                      </span>
                      <span className="font-mono text-[9px] text-stone-500">
                        Expires in {expiryHours}h
                      </span>
                    </div>
                  </div>
                </div>
                <p className="text-stone-200 text-sm leading-snug">
                  {text || "Your flash message will appear here…"}
                </p>
                <div className="flex items-center gap-3 pt-1 border-t border-stone-800">
                  <button className="flex items-center gap-1 font-mono text-[10px] text-stone-400">
                    <Flame size={11} /> <span>Pulse</span>
                  </button>
                  <span className="font-mono text-[9px] text-stone-600">
                    {selectedBiz.neighbourhood || selectedBiz.city}
                  </span>
                </div>
              </div>
            </div>

            {/* Timing info */}
            <div className="bg-white border border-stone-200 p-4 space-y-2">
              <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">Schedule</p>
              <div className="space-y-1.5">
                <div className="flex justify-between">
                  <span className="text-xs text-stone-500">Goes live</span>
                  <span className="font-mono text-xs text-stone-800">Immediately</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-xs text-stone-500">Auto-expires</span>
                  <span className="font-mono text-xs text-stone-800">
                    {expiryTime.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-xs text-stone-500">Visible radius</span>
                  <span className="font-mono text-xs text-stone-800">City-wide Hapa Now</span>
                </div>
              </div>
            </div>

            {/* Launch */}
            {launched && (
              <div className="flex items-center gap-2 bg-green-50 border border-green-200 p-4">
                <CheckCircle2 size={15} className="text-green-600 shrink-0" />
                <p className="text-green-700 text-sm font-medium">Flash is live! Watch for Pulses.</p>
              </div>
            )}
            {createMutation.isError && (
              <p className="flex items-center gap-1.5 text-red-500 font-mono text-[11px] bg-red-50 border border-red-200 p-3">
                <AlertCircle size={12} /> {(createMutation.error as Error).message}
              </p>
            )}
            <button
              disabled={!canPost || createMutation.isPending}
              onClick={() => createMutation.mutate()}
              className="w-full font-mono text-sm uppercase tracking-widest bg-[#C47B2B] text-white font-bold py-4 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <Flame size={15} />
              {createMutation.isPending ? "Posting…" : `Post Flash — ${expiryHours}h`}
            </button>
            <p className="text-stone-400 text-[11px] text-center font-mono">
              Free for Growth+ businesses · {text.length}/140 characters
            </p>
          </div>
        </div>
      )}

      {!selectedBiz && businesses.length > 0 && (
        <div className="border border-dashed border-stone-300 p-10 text-center">
          <Flame size={28} className="text-stone-300 mx-auto mb-3" />
          <p className="text-stone-400 text-sm">Select a business above to create a Flash post</p>
        </div>
      )}
    </div>
  );
}

function SectionLabel({ step, title }: { step: number; title: string }) {
  return (
    <div className="flex items-center gap-3 mb-4">
      <span className="w-6 h-6 rounded-full bg-[#C47B2B] text-white font-mono text-[11px] flex items-center justify-center shrink-0">
        {step}
      </span>
      <h2 className="font-fraunces text-base font-semibold text-stone-800">{title}</h2>
    </div>
  );
}
