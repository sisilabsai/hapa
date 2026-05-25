"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { endpoints, Business } from "@/lib/api";
import {
  Bell, Clock, TrendingUp, Zap, Target, Eye, MousePointer,
  CheckCircle2, Building2, Lightbulb, AlertCircle, BarChart3,
  ChevronRight, Calendar, Users, Volume2, VolumeX,
} from "lucide-react";

// ── Notification intelligence config ─────────────────────────────────────────

type TimeSlot = {
  hour: number;
  label: string;
  score: number;
  note: string;
};

const CATEGORY_TIMESLOTS: Record<string, TimeSlot[]> = {
  restaurant: [
    { hour: 11, label: "11am", score: 0.92, note: "Pre-lunch decision window" },
    { hour: 12, label: "12pm", score: 0.98, note: "Peak lunch intent" },
    { hour: 17, label: "5pm", score: 0.85, note: "After-work dinner planning" },
    { hour: 18, label: "6pm", score: 0.94, note: "Prime dinner hour" },
    { hour: 19, label: "7pm", score: 0.88, note: "Evening dine-out peak" },
  ],
  cafe: [
    { hour: 7, label: "7am", score: 0.89, note: "Morning commute" },
    { hour: 8, label: "8am", score: 0.95, note: "Peak morning coffee" },
    { hour: 10, label: "10am", score: 0.82, note: "Mid-morning break" },
    { hour: 14, label: "2pm", score: 0.78, note: "Post-lunch slump" },
  ],
  nightlife: [
    { hour: 17, label: "5pm", score: 0.76, note: "Planning for tonight" },
    { hour: 19, label: "7pm", score: 0.88, note: "Pre-night decision" },
    { hour: 21, label: "9pm", score: 0.94, note: "Night out peak" },
  ],
  retail: [
    { hour: 10, label: "10am", score: 0.82, note: "Morning shopping" },
    { hour: 13, label: "1pm", score: 0.85, note: "Lunch break shopping" },
    { hour: 15, label: "3pm", score: 0.88, note: "Afternoon browse" },
    { hour: 17, label: "5pm", score: 0.92, note: "After-work purchases" },
  ],
  wellness: [
    { hour: 6, label: "6am", score: 0.91, note: "Early morning workout crowd" },
    { hour: 7, label: "7am", score: 0.86, note: "Morning routine" },
    { hour: 17, label: "5pm", score: 0.89, note: "Post-work wellness" },
    { hour: 18, label: "6pm", score: 0.94, note: "Evening class peak" },
  ],
  default: [
    { hour: 9, label: "9am", score: 0.75, note: "Morning activity" },
    { hour: 12, label: "12pm", score: 0.85, note: "Lunch window" },
    { hour: 17, label: "5pm", score: 0.88, note: "After-work peak" },
    { hour: 19, label: "7pm", score: 0.82, note: "Evening prime time" },
  ],
};

const NOTIFICATION_TYPES = [
  {
    id: "boost",
    icon: Zap,
    title: "Hapa Boost Alerts",
    description: "Sent when you run a Boost campaign. Proximity-triggered — only users within your radius receive them.",
    cap: "Max 1 per user per 4 hours",
    enabled: true,
    performance: { sent: 1240, opened: 186, clicked: 74, rate: "15%" },
  },
  {
    id: "flash",
    icon: Bell,
    title: "Hapa Flash Alerts",
    description: "Sent when your Flash post reaches the Pulse threshold. Elevated to Hapa Now for maximum reach.",
    cap: "No cap — community driven",
    enabled: true,
    performance: { sent: 340, opened: 89, clicked: 41, rate: "26%" },
  },
  {
    id: "predictive",
    icon: Target,
    title: "Predictive Discovery",
    description: "Hapa proactively recommends your business to users matching your typical customer profile — before they even search.",
    cap: "1 per user per week from your business",
    enabled: false,
    performance: { sent: 0, opened: 0, clicked: 0, rate: "—" },
    locked: true,
    lockNote: "Available on Growth+ plan",
  },
  {
    id: "review",
    icon: Users,
    title: "New Review Alerts (to you)",
    description: "Instant notification when a user leaves a review. Respond within 2 hours to boost your trust score.",
    cap: "Per review",
    enabled: true,
    performance: { sent: 23, opened: 19, clicked: 14, rate: "83%" },
  },
];

const DAY_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// Simulated weekly heatmap data (engagement score per day/hour)
function generateHeatmap(category: string) {
  const slots = CATEGORY_TIMESLOTS[category?.toLowerCase()] ?? CATEGORY_TIMESLOTS.default;
  const peakHours = slots.map((s) => s.hour);

  return DAY_LABELS.map((day) => ({
    day,
    hours: Array.from({ length: 24 }, (_, hour) => {
      const slotScore = slots.find((s) => s.hour === hour)?.score ?? 0;
      const isWeekend = day === "Sat" || day === "Sun";
      const weekendBonus = isWeekend && (hour >= 18 || hour <= 2) ? 0.15 : 0;
      const noise = (Math.sin(hour * 7 + day.charCodeAt(0)) * 0.08);
      return Math.max(0, Math.min(1, slotScore + weekendBonus + noise));
    }),
  }));
}

// ── Engagement heatmap ─────────────────────────────────────────────────────────

function EngagementHeatmap({ category }: { category: string }) {
  const data = generateHeatmap(category);
  const peakHours = [8, 12, 18, 20]; // show labels for these

  return (
    <div className="overflow-x-auto">
      <div className="min-w-[520px]">
        {/* Hour labels */}
        <div className="flex ml-10 mb-1">
          {Array.from({ length: 24 }, (_, h) => (
            <div key={h} className="flex-1 text-center">
              {peakHours.includes(h) && (
                <span className="font-mono text-[8px] text-stone-400">{h}h</span>
              )}
            </div>
          ))}
        </div>
        {/* Grid */}
        {data.map(({ day, hours }) => (
          <div key={day} className="flex items-center gap-1 mb-0.5">
            <span className="font-mono text-[9px] text-stone-400 w-8 shrink-0">{day}</span>
            {hours.map((score, h) => (
              <div
                key={h}
                className="flex-1 h-5 rounded-sm"
                title={`${day} ${h}:00 — score ${(score * 100).toFixed(0)}%`}
                style={{
                  backgroundColor: score > 0.1
                    ? `rgba(196, 123, 43, ${score})`
                    : "#f5f5f4",
                }}
              />
            ))}
          </div>
        ))}
        {/* Legend */}
        <div className="flex items-center gap-2 mt-3 ml-10">
          <span className="font-mono text-[9px] text-stone-400">Low</span>
          {[0.15, 0.3, 0.5, 0.7, 0.9].map((v) => (
            <div key={v} className="w-4 h-3 rounded-sm" style={{ backgroundColor: `rgba(196, 123, 43, ${v})` }} />
          ))}
          <span className="font-mono text-[9px] text-stone-400">Peak</span>
        </div>
      </div>
    </div>
  );
}

// ── Time slot row ──────────────────────────────────────────────────────────────

function TimeSlotRow({ slot }: { slot: TimeSlot }) {
  const width = Math.round(slot.score * 100);
  return (
    <div className="flex items-center gap-4">
      <span className="font-mono text-sm text-stone-700 w-12 shrink-0">{slot.label}</span>
      <div className="flex-1 h-2 bg-stone-100 rounded-full overflow-hidden">
        <div
          className="h-full bg-[#C47B2B] rounded-full transition-all"
          style={{ width: `${width}%` }}
        />
      </div>
      <span className="font-mono text-xs text-[#C47B2B] w-10 shrink-0 text-right">{width}%</span>
      <span className="text-stone-400 text-xs flex-1">{slot.note}</span>
    </div>
  );
}

// ── Notification toggle card ───────────────────────────────────────────────────

function NotifCard({
  type,
  onToggle,
}: {
  type: (typeof NOTIFICATION_TYPES)[number];
  onToggle: (id: string) => void;
}) {
  const Icon = type.icon;
  return (
    <div className={`border p-5 transition-all ${type.enabled ? "border-stone-200 bg-white" : "border-stone-100 bg-stone-50"}`}>
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-3 flex-1 min-w-0">
          <div className={`w-9 h-9 flex items-center justify-center shrink-0 ${type.enabled ? "bg-[#C47B2B]/10" : "bg-stone-100"}`}>
            <Icon size={15} className={type.enabled ? "text-[#C47B2B]" : "text-stone-400"} />
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-fraunces font-semibold text-stone-900 text-sm">{type.title}</span>
              {type.locked && (
                <span className="font-mono text-[9px] uppercase tracking-widest bg-stone-100 text-stone-500 px-2 py-0.5">
                  {type.lockNote}
                </span>
              )}
            </div>
            <p className="text-stone-500 text-xs leading-relaxed mt-1">{type.description}</p>
            <p className="font-mono text-[9px] text-stone-400 mt-1.5">{type.cap}</p>
          </div>
        </div>

        {/* Toggle */}
        <button
          onClick={() => !type.locked && onToggle(type.id)}
          disabled={type.locked}
          className={`shrink-0 w-11 h-6 rounded-full transition-colors relative ${
            type.enabled && !type.locked ? "bg-[#C47B2B]" : "bg-stone-200"
          } ${type.locked ? "opacity-40 cursor-not-allowed" : "cursor-pointer"}`}
        >
          <span className={`absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-all ${
            type.enabled && !type.locked ? "left-6" : "left-1"
          }`} />
        </button>
      </div>

      {/* Performance stats */}
      {type.performance.sent > 0 && (
        <div className="grid grid-cols-4 gap-2 mt-4 pt-4 border-t border-stone-100">
          {[
            { label: "Sent", value: type.performance.sent.toLocaleString() },
            { label: "Opened", value: type.performance.opened.toLocaleString() },
            { label: "Clicked", value: type.performance.clicked.toLocaleString() },
            { label: "Open rate", value: type.performance.rate },
          ].map(({ label, value }) => (
            <div key={label} className="text-center">
              <p className="font-fraunces font-bold text-stone-900 text-sm">{value}</p>
              <p className="font-mono text-[9px] text-stone-400 uppercase tracking-wide mt-0.5">{label}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────

export default function NotificationsPage() {
  const [selectedBiz, setSelectedBiz] = useState<Business | null>(null);
  const [notifTypes, setNotifTypes] = useState(NOTIFICATION_TYPES);

  const { data: bizData } = useQuery({
    queryKey: ["my-businesses"],
    queryFn: () => endpoints.business.mine(),
  });

  const businesses = bizData?.businesses ?? [];
  const category = selectedBiz?.category ?? "default";
  const slots = CATEGORY_TIMESLOTS[category.toLowerCase()] ?? CATEGORY_TIMESLOTS.default;
  const topSlot = slots.reduce((a, b) => (a.score > b.score ? a : b), slots[0]);

  const toggleNotif = (id: string) => {
    setNotifTypes((prev) =>
      prev.map((n) => (n.id === id ? { ...n, enabled: !n.enabled } : n))
    );
  };

  return (
    <div className="p-8 max-w-5xl space-y-8">
      {/* Header */}
      <div>
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <Bell className="text-[#C47B2B]" size={28} />
          Notification Intelligence
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Every notification Hapa sends on your behalf should make a user think: <em>how did it know?</em>
        </p>
      </div>

      {/* Principle */}
      <div className="border-l-4 border-[#C47B2B] pl-5 py-2">
        <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400 mb-1">Hapa Rule</p>
        <p className="text-stone-700 text-sm leading-relaxed">
          Maximum <strong>5 push notifications per user per day</strong> across all types. Maximum <strong>1 promotional per 4 hours</strong>. No notifications between <strong>10pm–7am</strong>. Hapa auto-reduces frequency for users who consistently dismiss without opening.
        </p>
      </div>

      {/* Business selector */}
      {businesses.length > 0 && (
        <section>
          <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400 mb-3">Select a business for personalised insights</p>
          <div className="flex gap-3 overflow-x-auto pb-1">
            {businesses.map((biz) => (
              <button
                key={biz.id}
                onClick={() => setSelectedBiz(biz)}
                className={`relative text-left border p-3 shrink-0 w-44 transition-all ${
                  selectedBiz?.id === biz.id
                    ? "border-[#C47B2B] bg-[#C47B2B]/5"
                    : "border-stone-200 bg-white hover:border-[#C47B2B]/50"
                }`}
              >
                {selectedBiz?.id === biz.id && <CheckCircle2 size={12} className="absolute top-2 right-2 text-[#C47B2B]" />}
                <p className="font-semibold text-stone-900 text-xs truncate">{biz.name}</p>
                <p className="font-mono text-[9px] text-stone-400 mt-0.5">{biz.category}</p>
              </button>
            ))}
          </div>
        </section>
      )}

      <div className="grid grid-cols-[1fr_320px] gap-8">
        {/* Left */}
        <div className="space-y-6">
          {/* Notification types */}
          <section>
            <h2 className="font-fraunces text-lg font-semibold text-stone-800 mb-4">Your notification channels</h2>
            <div className="space-y-3">
              {notifTypes.map((type) => (
                <NotifCard key={type.id} type={type} onToggle={toggleNotif} />
              ))}
            </div>
          </section>

          {/* Engagement heatmap */}
          {selectedBiz && (
            <section className="bg-white border border-stone-200 p-6">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="font-fraunces text-lg font-semibold text-stone-800">When your audience is active</h2>
                  <p className="text-stone-400 text-xs mt-0.5">Engagement heatmap for {selectedBiz.category} businesses in {selectedBiz.city}</p>
                </div>
                <BarChart3 size={16} className="text-stone-300" />
              </div>
              <EngagementHeatmap category={category} />
            </section>
          )}
        </div>

        {/* Right: Smart timing + tips */}
        <div className="space-y-5 sticky top-6">
          {/* Best times */}
          <div className="bg-white border border-stone-200 p-5">
            <div className="flex items-center gap-2 mb-4">
              <Clock size={14} className="text-[#C47B2B]" />
              <h3 className="font-fraunces font-semibold text-stone-800">
                {selectedBiz ? `Best times for ${selectedBiz.category}` : "Best send times"}
              </h3>
            </div>
            <div className="space-y-3">
              {slots.map((slot) => (
                <TimeSlotRow key={slot.hour} slot={slot} />
              ))}
            </div>

            {selectedBiz && (
              <div className="mt-4 pt-4 border-t border-stone-100 bg-[#C47B2B]/5 p-3">
                <div className="flex items-start gap-2">
                  <Lightbulb size={13} className="text-[#C47B2B] shrink-0 mt-0.5" />
                  <p className="font-mono text-[10px] text-stone-600 leading-relaxed">
                    Schedule your Boost for <strong className="text-[#C47B2B]">{topSlot.label}</strong> — highest engagement window for {selectedBiz.category} in your city.
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* Daily budget */}
          <div className="bg-white border border-stone-200 p-5 space-y-3">
            <h3 className="font-fraunces font-semibold text-stone-800">Daily notification budget</h3>
            <p className="text-stone-500 text-xs leading-relaxed">
              Hapa enforces a 5-notification daily cap per user. Your campaigns share this budget with platform notifications.
            </p>
            <div className="space-y-2">
              {[
                { label: "Boost promotions", used: 1, max: 1, color: "#C47B2B" },
                { label: "Flash alerts", used: 0, max: 2, color: "#3B82F6" },
                { label: "Platform (reviews, etc.)", used: 1, max: 2, color: "#6B7280" },
              ].map(({ label, used, max, color }) => (
                <div key={label}>
                  <div className="flex justify-between mb-1">
                    <span className="font-mono text-[10px] text-stone-500">{label}</span>
                    <span className="font-mono text-[10px] text-stone-400">{used}/{max}</span>
                  </div>
                  <div className="h-1.5 bg-stone-100 rounded-full">
                    <div
                      className="h-full rounded-full transition-all"
                      style={{ width: `${(used / max) * 100}%`, backgroundColor: color }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Tips */}
          <div className="bg-white border border-stone-200 p-5 space-y-3">
            <div className="flex items-center gap-2">
              <Lightbulb size={13} className="text-[#C47B2B]" />
              <h3 className="font-mono text-[10px] uppercase tracking-widest text-stone-400">Notification tips</h3>
            </div>
            <ul className="space-y-2.5">
              {[
                "Specific numbers outperform vague claims: '20% off' beats 'big discount'",
                "Include a time limit in every Boost notification for 2× click rate",
                "Users who dismiss 3 in a row won't receive more for 48 hours — stay relevant",
                "Flash posts that get 5+ Pulses get auto-escalated to city-wide Hapa Now",
              ].map((tip, i) => (
                <li key={i} className="flex items-start gap-2">
                  <ChevronRight size={11} className="text-[#C47B2B] shrink-0 mt-0.5" />
                  <span className="text-stone-500 text-xs leading-relaxed">{tip}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* Boost CTA */}
          <a
            href="/dashboard/boost"
            className="block w-full font-mono text-[11px] uppercase tracking-widest bg-[#C47B2B] text-white font-bold py-3.5 hover:bg-[#E8A84A] transition-colors text-center flex items-center justify-center gap-2"
          >
            <Zap size={13} /> Launch Boost Campaign
          </a>
        </div>
      </div>
    </div>
  );
}
