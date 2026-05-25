"use client";
import { useState, useMemo } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { endpoints, Business } from "@/lib/api";
import {
  Zap, MapPin, Clock, DollarSign, Users, Sparkles, TrendingUp,
  Eye, MousePointer, Footprints, ChevronRight, CheckCircle2,
  Building2, Star, Lightbulb, Timer, Target, BarChart3, AlertCircle,
} from "lucide-react";

// ── Package tiers ──────────────────────────────────────────────────────────────

type Package = {
  id: string;
  label: string;
  price: number;
  reachRange: [number, number];
  durationRange: [number, number];
  badge: string;
  description: string;
  popular?: boolean;
};

const PACKAGES: Package[] = [
  {
    id: "starter",
    label: "Starter",
    price: 5,
    reachRange: [600, 1000],
    durationRange: [1, 8],
    badge: "Flash deals",
    description: "Perfect for same-day flash offers and quick announcements",
  },
  {
    id: "reach",
    label: "Reach",
    price: 10,
    reachRange: [1500, 2800],
    durationRange: [4, 24],
    badge: "Daily specials",
    description: "Ideal for daily specials and recurring promotions",
  },
  {
    id: "growth",
    label: "Growth",
    price: 20,
    reachRange: [3500, 6500],
    durationRange: [8, 48],
    badge: "Best value",
    description: "Drive real footfall with sustained neighbourhood reach",
    popular: true,
  },
  {
    id: "pro",
    label: "Pro",
    price: 50,
    reachRange: [9000, 18000],
    durationRange: [24, 72],
    badge: "Launches",
    description: "Launch events, grand openings, and major campaigns",
  },
];

// ── Timing presets ─────────────────────────────────────────────────────────────

const TIMING_PRESETS = [
  { label: "Morning Rush", icon: "🌅", hours: 3, note: "7–10am, commuters & early birds" },
  { label: "Lunch Special", icon: "☀️", hours: 3, note: "12–3pm, peak foot traffic" },
  { label: "Afternoon", icon: "🌤️", hours: 4, note: "2–6pm, retail & wellness" },
  { label: "Evening", icon: "🌆", hours: 4, note: "5–9pm, restaurants & bars" },
  { label: "Weekend Night", icon: "🌙", hours: 6, note: "Fri–Sat, nightlife peak" },
  { label: "Full Day", icon: "📅", hours: 12, note: "All-day awareness campaign" },
];

// ── Category config ────────────────────────────────────────────────────────────

const CATEGORY_CONFIG: Record<string, { clickRate: number; bestTime: string; radiusTip: string; avgTransact: number }> = {
  restaurant: { clickRate: 0.14, bestTime: "Lunch (12–2pm) and dinner (6–8pm)", radiusTip: "1km radius targets highly motivated nearby diners", avgTransact: 18 },
  food: { clickRate: 0.14, bestTime: "Lunch (12–2pm) and dinner (6–8pm)", radiusTip: "1km radius targets highly motivated nearby diners", avgTransact: 15 },
  cafe: { clickRate: 0.12, bestTime: "Morning rush (7–10am) and midday (12–2pm)", radiusTip: "500m–1km keeps it hyper-local for regulars", avgTransact: 8 },
  retail: { clickRate: 0.10, bestTime: "Weekend afternoons (1–5pm)", radiusTip: "1.5–2km brings in comparison shoppers", avgTransact: 35 },
  nightlife: { clickRate: 0.16, bestTime: "Friday & Saturday evenings (7pm+)", radiusTip: "2–3km radius catches people planning their night", avgTransact: 25 },
  wellness: { clickRate: 0.09, bestTime: "Morning (6–9am) and early evening (5–7pm)", radiusTip: "1km radius targets your core neighbourhood", avgTransact: 40 },
  beauty: { clickRate: 0.11, bestTime: "Weekday afternoons and Saturday mornings", radiusTip: "1–1.5km reaches your typical client catchment", avgTransact: 30 },
  services: { clickRate: 0.08, bestTime: "Weekday business hours (9am–5pm)", radiusTip: "2–3km wider radius works well for services", avgTransact: 50 },
};
const defaultCategory = { clickRate: 0.11, bestTime: "Peak hours 12–2pm and 6–9pm", radiusTip: "1–2km radius gives a good balance of reach and relevance", avgTransact: 20 };

// ── Prediction engine ──────────────────────────────────────────────────────────

function predict(budgetUsd: number, radiusM: number, durationHours: number, category: string) {
  const cfg = CATEGORY_CONFIG[category?.toLowerCase()] ?? defaultCategory;
  const base = budgetUsd * 145;
  const radiusMult = Math.min((radiusM / 1000) * 0.38 + 0.82, 2.1);
  const timeMult = Math.min(durationHours / 4, 3) * 0.28 + 0.72;
  const impressions = Math.round(base * radiusMult * timeMult);
  const clicks = Math.round(impressions * cfg.clickRate);
  const footfall = Math.round(clicks * 0.19);
  const revenue = footfall * cfg.avgTransact;
  const roi = Math.round((revenue / budgetUsd) * 10) / 10;
  const cpc = clicks > 0 ? (budgetUsd / clicks).toFixed(2) : "–";
  return { impressions, clicks, footfall, revenue, roi, cpc };
}

// ── Smart tips ─────────────────────────────────────────────────────────────────

function smartTips(category: string, radiusM: number, durationHours: number, budgetUsd: number): string[] {
  const cfg = CATEGORY_CONFIG[category?.toLowerCase()] ?? defaultCategory;
  const tips: string[] = [];

  tips.push(`Best time to run this boost: ${cfg.bestTime}`);

  if (radiusM > 3000) {
    tips.push("Large radius can dilute relevance — try 1–2km to hit highly motivated nearby customers");
  } else if (radiusM <= 500) {
    tips.push("Tight radius = hyper-targeted audience. Great for exclusive offers to your closest regulars");
  } else {
    tips.push(cfg.radiusTip);
  }

  if (durationHours <= 3) {
    tips.push("Short bursts create strong urgency — pair with a time-limited deal for best results");
  } else if (durationHours >= 24) {
    tips.push("Multi-day boosts build awareness — refresh your offer text midway to keep it feeling fresh");
  }

  if (budgetUsd >= 20) {
    tips.push("At this budget, track footfall vs. your normal baseline to measure true ROI");
  }

  return tips.slice(0, 3);
}

// ── Radius SVG visualisation ───────────────────────────────────────────────────

function RadiusMap({ radiusM, businessName }: { radiusM: number; businessName: string }) {
  const SIZE = 280;
  const C = SIZE / 2;
  const MAX_R = Math.max(radiusM * 1.7, 1800);
  const r = Math.round((radiusM / MAX_R) * (C - 24));

  // Pseudo-random nearby dots (stable, seeded from businessName length)
  const seed = businessName.length || 5;
  const nearbyDots = Array.from({ length: 6 }, (_, i) => {
    const angle = (i * 60 + seed * 17) % 360;
    const dist = ((i + 1) * 28 + seed * 3) % (C - 30) + 20;
    return {
      x: Math.round(C + dist * Math.cos((angle * Math.PI) / 180)),
      y: Math.round(C + dist * Math.sin((angle * Math.PI) / 180)),
      inside: dist < r,
    };
  });

  const label = radiusM >= 1000 ? `${(radiusM / 1000).toFixed(1)}km radius` : `${radiusM}m radius`;

  return (
    <div className="relative w-full aspect-square max-w-[280px] mx-auto">
      <svg viewBox={`0 0 ${SIZE} ${SIZE}`} className="w-full h-full">
        <defs>
          <pattern id="dots" x="0" y="0" width="18" height="18" patternUnits="userSpaceOnUse">
            <circle cx="9" cy="9" r="1" fill="#d6d3d1" opacity="0.6" />
          </pattern>
          <radialGradient id="glow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#C47B2B" stopOpacity="0.18" />
            <stop offset="100%" stopColor="#C47B2B" stopOpacity="0" />
          </radialGradient>
        </defs>

        {/* Map texture */}
        <rect width={SIZE} height={SIZE} fill="#f5f5f4" rx="4" />
        <rect width={SIZE} height={SIZE} fill="url(#dots)" rx="4" />

        {/* Faint street-like lines */}
        <line x1="0" y1={C} x2={SIZE} y2={C} stroke="#e7e5e4" strokeWidth="8" />
        <line x1={C} y1="0" x2={C} y2={SIZE} stroke="#e7e5e4" strokeWidth="8" />
        <line x1="0" y1={C * 0.5} x2={SIZE} y2={C * 0.5} stroke="#e7e5e4" strokeWidth="5" />
        <line x1="0" y1={C * 1.5} x2={SIZE} y2={C * 1.5} stroke="#e7e5e4" strokeWidth="5" />
        <line x1={C * 0.5} y1="0" x2={C * 0.5} y2={SIZE} stroke="#e7e5e4" strokeWidth="5" />
        <line x1={C * 1.5} y1="0" x2={C * 1.5} y2={SIZE} stroke="#e7e5e4" strokeWidth="5" />

        {/* Boost zone glow */}
        <circle cx={C} cy={C} r={r} fill="url(#glow)" />
        <circle cx={C} cy={C} r={r} fill="#C47B2B" opacity="0.07" />

        {/* Dashed radius ring */}
        <circle cx={C} cy={C} r={r} fill="none" stroke="#C47B2B" strokeWidth="2" strokeDasharray="6 4" opacity="0.8" />

        {/* Nearby dots — blue = outside radius, amber = inside */}
        {nearbyDots.map((d, i) => (
          <circle key={i} cx={d.x} cy={d.y} r="5"
            fill={d.inside ? "#C47B2B" : "#94a3b8"} opacity={d.inside ? 0.7 : 0.4} />
        ))}

        {/* Business pin */}
        <circle cx={C} cy={C} r="14" fill="#C47B2B" />
        <circle cx={C} cy={C} r="7" fill="white" />

        {/* Radius label */}
        <text x={C} y={SIZE - 8} textAnchor="middle" fontSize="11" fill="#78716c" fontFamily="monospace">
          {label}
        </text>
      </svg>

      {/* Legend */}
      <div className="absolute bottom-8 right-2 flex flex-col gap-1 text-[9px] font-mono text-stone-400">
        <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-[#C47B2B] inline-block" /> In range</span>
        <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-slate-400 inline-block" /> Outside</span>
      </div>
    </div>
  );
}

// ── Business card ──────────────────────────────────────────────────────────────

function BizCard({
  biz, selected, onClick,
}: { biz: Business; selected: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={`relative text-left border p-4 transition-all hover:border-[#C47B2B] shrink-0 w-56 ${
        selected
          ? "border-[#C47B2B] bg-[#C47B2B]/5 ring-1 ring-[#C47B2B]"
          : "border-stone-200 bg-white"
      }`}
    >
      {selected && (
        <CheckCircle2 size={14} className="absolute top-3 right-3 text-[#C47B2B]" />
      )}
      {biz.boost_active && (
        <span className="absolute top-3 left-3 bg-amber-100 text-amber-700 font-mono text-[9px] uppercase tracking-widest px-1.5 py-0.5">
          Boosting
        </span>
      )}
      {biz.cover_url ? (
        <img src={biz.cover_url} alt={biz.name} className="w-full h-20 object-cover mb-3 mt-4" />
      ) : (
        <div className="w-full h-20 bg-stone-100 flex items-center justify-center mb-3 mt-4">
          <Building2 size={24} className="text-stone-300" />
        </div>
      )}
      <p className="font-fraunces font-semibold text-stone-900 text-sm leading-tight truncate">{biz.name}</p>
      <p className="font-mono text-[10px] text-stone-400 uppercase tracking-wider mt-0.5 truncate">{biz.category}</p>
      {biz.avg_rating && (
        <span className="flex items-center gap-1 mt-1.5">
          <Star size={10} className="text-amber-400 fill-amber-400" />
          <span className="font-mono text-[10px] text-stone-500">{biz.avg_rating.toFixed(1)}</span>
        </span>
      )}
      {biz.neighbourhood && (
        <p className="font-mono text-[10px] text-stone-400 mt-0.5 flex items-center gap-1">
          <MapPin size={9} /> {biz.neighbourhood}
        </p>
      )}
    </button>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────

export default function BoostPage() {
  const [selectedBiz, setSelectedBiz] = useState<Business | null>(null);
  const [pkg, setPkg] = useState(PACKAGES[2]); // default: Growth
  const [form, setForm] = useState({ title: "", offer_text: "", description: "" });
  const [hint, setHint] = useState("");
  const [radiusM, setRadiusM] = useState(1000);
  const [durationHours, setDurationHours] = useState(8);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiError, setAiError] = useState("");
  const [launched, setLaunched] = useState(false);

  const { data: bizData, isLoading: bizLoading } = useQuery({
    queryKey: ["my-businesses"],
    queryFn: () => endpoints.business.mine(),
  });

  const businesses = bizData?.businesses ?? [];

  const predictions = useMemo(
    () => predict(pkg.price, radiusM, durationHours, selectedBiz?.category ?? ""),
    [pkg.price, radiusM, durationHours, selectedBiz?.category]
  );

  const tips = useMemo(
    () => smartTips(selectedBiz?.category ?? "", radiusM, durationHours, pkg.price),
    [selectedBiz?.category, radiusM, durationHours, pkg.price]
  );

  const handleGenerateCopy = async () => {
    if (!selectedBiz) return;
    setAiLoading(true);
    setAiError("");
    try {
      const result = await endpoints.ai.boostCopy({
        business_name: selectedBiz.name,
        category: selectedBiz.category,
        city: selectedBiz.city,
        hint: hint || undefined,
      });
      setForm({
        title: result.title ?? "",
        offer_text: result.offer_text ?? "",
        description: result.description ?? "",
      });
    } catch {
      setAiError("AI unavailable — try again or write your own copy below");
    } finally {
      setAiLoading(false);
    }
  };

  const launchMutation = useMutation({
    mutationFn: () =>
      endpoints.business.createBoost(selectedBiz!.id, {
        title: form.title,
        description: form.description,
        offer_text: form.offer_text,
        radius_m: radiusM,
        duration_hours: durationHours,
        budget_usd: pkg.price,
      }),
    onSuccess: () => setLaunched(true),
  });

  const canLaunch = !!selectedBiz && !!form.title && !!form.offer_text && !launchMutation.isPending;

  if (launched) {
    return <LaunchSuccess biz={selectedBiz!} pkg={pkg} predictions={predictions} onReset={() => { setLaunched(false); setForm({ title: "", offer_text: "", description: "" }); }} />;
  }

  return (
    <div className="p-8 max-w-6xl space-y-8">
      {/* Header */}
      <div>
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <Zap className="text-[#C47B2B]" size={28} />
          Hapa Boost
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Push a hyper-local promotion to Hapa users around your business — right now.
        </p>
      </div>

      {/* Step 1: Business selector */}
      <section>
        <SectionLabel step={1} title="Choose your business" />
        {bizLoading ? (
          <div className="flex gap-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="w-56 h-44 bg-stone-100 animate-pulse shrink-0" />
            ))}
          </div>
        ) : businesses.length === 0 ? (
          <div className="border border-dashed border-stone-300 p-6 text-center text-stone-400 text-sm">
            You have no registered businesses yet.{" "}
            <a href="/dashboard/places/new" className="text-[#C47B2B] underline">Add one →</a>
          </div>
        ) : (
          <div className="flex gap-3 overflow-x-auto pb-2">
            {businesses.map((biz) => (
              <BizCard
                key={biz.id}
                biz={biz}
                selected={selectedBiz?.id === biz.id}
                onClick={() => setSelectedBiz(biz)}
              />
            ))}
          </div>
        )}
      </section>

      {/* Campaign builder — only shown when business selected */}
      {selectedBiz && (
        <div className="grid grid-cols-[1fr_380px] gap-8 items-start">
          {/* ── LEFT COLUMN ── */}
          <div className="space-y-6">
            {/* Step 2: Package */}
            <section className="bg-white border border-stone-200 p-6 space-y-4">
              <SectionLabel step={2} title="Select a boost package" />
              <div className="grid grid-cols-2 gap-3">
                {PACKAGES.map((p) => (
                  <button
                    key={p.id}
                    onClick={() => setPkg(p)}
                    className={`relative text-left border p-4 transition-all ${
                      pkg.id === p.id
                        ? "border-[#C47B2B] bg-[#C47B2B]/5 ring-1 ring-[#C47B2B]"
                        : "border-stone-200 hover:border-[#C47B2B]/50"
                    }`}
                  >
                    {p.popular && (
                      <span className="absolute -top-2.5 left-3 bg-[#C47B2B] text-white font-mono text-[9px] uppercase tracking-widest px-2 py-0.5">
                        Most popular
                      </span>
                    )}
                    {pkg.id === p.id && (
                      <CheckCircle2 size={13} className="absolute top-3 right-3 text-[#C47B2B]" />
                    )}
                    <div className="flex items-baseline gap-1 mb-1">
                      <span className="font-fraunces text-2xl font-bold text-stone-900">${p.price}</span>
                      <span className="font-mono text-[10px] text-stone-400">USD</span>
                    </div>
                    <p className="font-fraunces font-semibold text-stone-800 text-sm">{p.label}</p>
                    <p className="font-mono text-[10px] text-stone-400 mt-0.5">{p.badge}</p>
                    <div className="mt-2 pt-2 border-t border-stone-100 space-y-0.5">
                      <p className="font-mono text-[10px] text-stone-500">
                        <span className="text-stone-800 font-semibold">{p.reachRange[0].toLocaleString()}–{p.reachRange[1].toLocaleString()}</span> people
                      </p>
                      <p className="font-mono text-[10px] text-stone-400">
                        {p.durationRange[0]}–{p.durationRange[1]}h duration
                      </p>
                    </div>
                  </button>
                ))}
              </div>
            </section>

            {/* Step 3: AI Copy */}
            <section className="bg-white border border-stone-200 p-6 space-y-4">
              <SectionLabel step={3} title="Craft your promotion" />

              {/* AI hint */}
              <div className="bg-stone-50 border border-stone-200 p-4 space-y-3">
                <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">
                  AI Promotion Writer
                </p>
                <input
                  type="text"
                  placeholder={`What do you want to promote at ${selectedBiz.name}? (optional hint)`}
                  value={hint}
                  onChange={(e) => setHint(e.target.value)}
                  className="input text-sm"
                />
                <button
                  onClick={handleGenerateCopy}
                  disabled={aiLoading}
                  className="flex items-center gap-2 bg-stone-900 text-white font-mono text-[11px] uppercase tracking-widest px-4 py-2.5 hover:bg-stone-700 transition-colors disabled:opacity-50"
                >
                  <Sparkles size={13} className={aiLoading ? "animate-spin" : ""} />
                  {aiLoading ? "Generating…" : "Generate with AI"}
                </button>
                {aiError && (
                  <p className="flex items-center gap-1.5 text-red-500 font-mono text-[11px]">
                    <AlertCircle size={12} /> {aiError}
                  </p>
                )}
              </div>

              <Field label={`Campaign title (${form.title.length}/60)`}>
                <input
                  type="text"
                  placeholder="Lunch Special — Today Only"
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="input"
                  maxLength={60}
                />
              </Field>

              <Field label={`Notification text (${form.offer_text.length}/80)`}>
                <input
                  type="text"
                  placeholder="20% off all mains 12pm–3pm, walk-ins welcome"
                  value={form.offer_text}
                  onChange={(e) => setForm({ ...form, offer_text: e.target.value })}
                  className="input"
                  maxLength={80}
                />
              </Field>

              <Field label={`Description (${form.description.length}/200)`}>
                <textarea
                  placeholder="Tell people what makes this offer special today…"
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  className="input min-h-[70px] resize-none text-sm"
                  maxLength={200}
                />
              </Field>
            </section>

            {/* Step 4: Targeting */}
            <section className="bg-white border border-stone-200 p-6 space-y-5">
              <SectionLabel step={4} title="Set targeting" />

              <Field label={`Radius — ${radiusM >= 1000 ? `${(radiusM / 1000).toFixed(1)}km` : `${radiusM}m`} around ${selectedBiz.name}`}>
                <input
                  type="range" min={100} max={5000} step={100}
                  value={radiusM}
                  onChange={(e) => setRadiusM(+e.target.value)}
                  className="w-full accent-[#C47B2B]"
                />
                <div className="flex justify-between font-mono text-[9px] text-stone-400 mt-1">
                  <span>100m</span><span>1km</span><span>2.5km</span><span>5km</span>
                </div>
              </Field>

              <div>
                <label className="font-mono text-[10px] uppercase tracking-widest text-stone-400 block mb-2">
                  Duration — <span className="text-stone-700">{durationHours} hour{durationHours !== 1 ? "s" : ""}</span>
                </label>
                <div className="grid grid-cols-3 gap-2 mb-3">
                  {TIMING_PRESETS.map((preset) => (
                    <button
                      key={preset.label}
                      onClick={() => setDurationHours(preset.hours)}
                      title={preset.note}
                      className={`text-left border px-3 py-2.5 transition-colors ${
                        durationHours === preset.hours
                          ? "border-[#C47B2B] bg-[#C47B2B]/5"
                          : "border-stone-200 hover:border-stone-300"
                      }`}
                    >
                      <span className="block text-base leading-none">{preset.icon}</span>
                      <span className="block font-mono text-[10px] text-stone-700 mt-1">{preset.label}</span>
                      <span className="block font-mono text-[9px] text-stone-400">{preset.hours}h</span>
                    </button>
                  ))}
                </div>
                <input
                  type="range" min={1} max={72} step={1}
                  value={durationHours}
                  onChange={(e) => setDurationHours(+e.target.value)}
                  className="w-full accent-[#C47B2B]"
                />
                <div className="flex justify-between font-mono text-[9px] text-stone-400 mt-1">
                  <span>1h</span><span>12h</span><span>36h</span><span>72h</span>
                </div>
              </div>
            </section>
          </div>

          {/* ── RIGHT COLUMN ── */}
          <div className="space-y-5 sticky top-6">
            {/* Radius map */}
            <div className="bg-white border border-stone-200 p-5">
              <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400 mb-3">Boost zone</p>
              <RadiusMap radiusM={radiusM} businessName={selectedBiz.name} />
            </div>

            {/* Predicted results */}
            <div className="bg-white border border-stone-200 p-5 space-y-3">
              <div className="flex items-center justify-between">
                <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">Predicted results</p>
                <span className="font-mono text-[9px] text-stone-400 bg-stone-100 px-2 py-0.5">
                  ${pkg.price} · {radiusM >= 1000 ? `${(radiusM / 1000).toFixed(1)}km` : `${radiusM}m`} · {durationHours}h
                </span>
              </div>
              <div className="space-y-2.5">
                <PredStat icon={Eye} label="Impressions" value={predictions.impressions.toLocaleString()} sub="people who'll see your boost" color="stone" />
                <PredStat icon={MousePointer} label="Est. clicks" value={predictions.clicks.toLocaleString()} sub="taps through to your profile" color="amber" />
                <PredStat icon={Footprints} label="Est. footfall" value={predictions.footfall.toLocaleString()} sub="expected walk-in visits" color="amber" />
                <PredStat icon={DollarSign} label="Cost per click" value={`$${predictions.cpc}`} sub="value per engaged user" color="stone" />
              </div>
              <div className="bg-[#C47B2B]/8 border border-[#C47B2B]/20 p-3 mt-2">
                <div className="flex items-center gap-2">
                  <TrendingUp size={14} className="text-[#C47B2B] shrink-0" />
                  <p className="font-mono text-[10px] text-stone-600">
                    Estimated <span className="font-bold text-[#C47B2B]">{predictions.roi}× return</span> based on avg transaction value for {selectedBiz.category || "this category"}
                  </p>
                </div>
              </div>
            </div>

            {/* Smart tips */}
            {tips.length > 0 && (
              <div className="bg-white border border-stone-200 p-5 space-y-3">
                <div className="flex items-center gap-2">
                  <Lightbulb size={13} className="text-[#C47B2B]" />
                  <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">Smart tips</p>
                </div>
                <ul className="space-y-2">
                  {tips.map((tip, i) => (
                    <li key={i} className="flex items-start gap-2">
                      <ChevronRight size={11} className="text-[#C47B2B] mt-0.5 shrink-0" />
                      <span className="text-stone-600 text-xs leading-relaxed">{tip}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Phone preview */}
            <div className="bg-[#1A1208] border border-stone-800 p-5">
              <p className="font-mono text-[10px] text-stone-500 uppercase tracking-widest mb-3">
                Preview — how it looks on phone
              </p>
              <div className="bg-stone-900 rounded-2xl p-4 flex items-start gap-3">
                <div className="w-10 h-10 bg-[#C47B2B] rounded-xl flex items-center justify-center shrink-0">
                  {selectedBiz.logo_url ? (
                    <img src={selectedBiz.logo_url} alt="" className="w-full h-full object-cover rounded-xl" />
                  ) : (
                    <span className="font-fraunces font-black text-white text-sm">
                      {selectedBiz.name.charAt(0)}
                    </span>
                  )}
                </div>
                <div className="min-w-0">
                  <p className="text-white text-sm font-medium leading-snug">
                    {form.title || "Your campaign title"}
                  </p>
                  <p className="text-stone-400 text-xs mt-0.5 leading-relaxed">
                    {form.offer_text || "Your offer text appears here"}
                  </p>
                  <p className="text-stone-500 text-[10px] mt-1.5 font-mono">
                    {selectedBiz.name} · {radiusM >= 1000 ? `${(radiusM / 1000).toFixed(1)}km away` : `${radiusM}m away`}
                  </p>
                </div>
              </div>
            </div>

            {/* Launch */}
            <div className="space-y-3">
              {launchMutation.isError && (
                <p className="flex items-center gap-1.5 text-red-500 font-mono text-[11px] bg-red-50 border border-red-200 p-3">
                  <AlertCircle size={12} /> {(launchMutation.error as Error).message}
                </p>
              )}
              <button
                disabled={!canLaunch}
                onClick={() => launchMutation.mutate()}
                className="w-full font-mono text-sm uppercase tracking-widest bg-[#C47B2B] text-white font-bold py-4 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                <Zap size={15} />
                {launchMutation.isPending ? "Launching…" : `Launch Boost — $${pkg.price}`}
              </button>
              <p className="text-stone-400 text-[11px] text-center font-mono">
                Pay via mobile money, card, or Hapa credit balance
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Placeholder when no business selected */}
      {!selectedBiz && businesses.length > 0 && (
        <div className="border border-dashed border-stone-300 p-10 text-center space-y-2">
          <Target size={28} className="text-stone-300 mx-auto" />
          <p className="text-stone-400 text-sm">Select a business above to configure your boost campaign</p>
        </div>
      )}
    </div>
  );
}

// ── Success screen ─────────────────────────────────────────────────────────────

function LaunchSuccess({
  biz, pkg, predictions, onReset,
}: {
  biz: Business;
  pkg: Package;
  predictions: ReturnType<typeof predict>;
  onReset: () => void;
}) {
  return (
    <div className="p-8 max-w-xl mx-auto text-center space-y-6 pt-16">
      <div className="w-16 h-16 bg-[#C47B2B] rounded-full flex items-center justify-center mx-auto">
        <Zap size={28} className="text-white" />
      </div>
      <div>
        <h2 className="font-fraunces text-2xl font-bold text-stone-900">Boost live!</h2>
        <p className="text-stone-500 text-sm mt-2">
          Your promotion for <strong>{biz.name}</strong> is going live within minutes.
        </p>
      </div>
      <div className="grid grid-cols-3 gap-3 text-center">
        {[
          { label: "Impressions", value: predictions.impressions.toLocaleString() },
          { label: "Est. clicks", value: predictions.clicks.toLocaleString() },
          { label: "Est. footfall", value: predictions.footfall.toLocaleString() },
        ].map((s) => (
          <div key={s.label} className="bg-stone-50 border border-stone-200 p-4">
            <p className="font-fraunces text-2xl font-bold text-[#C47B2B]">{s.value}</p>
            <p className="font-mono text-[10px] text-stone-400 uppercase tracking-wider mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>
      <div className="flex gap-3 justify-center">
        <button onClick={onReset} className="font-mono text-xs uppercase tracking-widest border border-stone-200 px-5 py-2.5 hover:border-stone-400 transition-colors">
          Launch Another
        </button>
        <a href="/dashboard/analytics" className="font-mono text-xs uppercase tracking-widest bg-stone-900 text-white px-5 py-2.5 hover:bg-stone-700 transition-colors flex items-center gap-1.5">
          <BarChart3 size={13} /> View Analytics
        </a>
      </div>
    </div>
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="font-mono text-[10px] uppercase tracking-widest text-stone-400 block mb-2">{label}</label>
      {children}
    </div>
  );
}

function PredStat({
  icon: Icon, label, value, sub, color,
}: { icon: any; label: string; value: string; sub: string; color: "amber" | "stone" }) {
  return (
    <div className="flex items-start gap-3">
      <div className={`w-7 h-7 flex items-center justify-center shrink-0 ${color === "amber" ? "bg-[#C47B2B]/10" : "bg-stone-100"}`}>
        <Icon size={13} className={color === "amber" ? "text-[#C47B2B]" : "text-stone-500"} />
      </div>
      <div className="min-w-0">
        <div className="flex items-baseline gap-2">
          <span className="font-fraunces font-bold text-stone-900">{value}</span>
          <span className="font-mono text-[10px] uppercase tracking-wider text-stone-400">{label}</span>
        </div>
        <p className="font-mono text-[9px] text-stone-400 mt-0.5">{sub}</p>
      </div>
    </div>
  );
}
