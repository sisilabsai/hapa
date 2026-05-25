"use client";
import { useQuery } from "@tanstack/react-query";
import { api, type Business } from "@/lib/api";
import { Eye, Star, Calendar, TrendingUp, Zap, ArrowUpRight, Flame, CircleDot, Bell, Users } from "lucide-react";
import Link from "next/link";

export default function DashboardPage() {
  const { data: bizData } = useQuery({
    queryKey: ["my-businesses"],
    queryFn: () => api.get<{ businesses: Business[] }>("/v1/businesses/mine"),
  });

  const businesses = bizData?.businesses ?? [];
  const hasBusiness = businesses.length > 0;

  return (
    <div className="p-8 max-w-6xl">
      {/* Header */}
      <div className="mb-8 flex items-start justify-between">
        <div>
          <h1 className="font-fraunces text-3xl font-bold text-stone-900">Overview</h1>
          <p className="text-stone-500 text-sm mt-1">
            {hasBusiness ? `Managing ${businesses.length} business${businesses.length > 1 ? "es" : ""}` : "Get started on Hapa"}
          </p>
        </div>
        {hasBusiness && (
          <Link
            href="/dashboard/boost/new"
            className="flex items-center gap-2 font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white px-5 py-2.5 hover:bg-[#E8A84A] transition-colors"
          >
            <Zap size={13} />
            Launch Boost
          </Link>
        )}
      </div>

      {!hasBusiness ? (
        <OnboardingCTA />
      ) : (
        <>
          <StatCards />
          <div className="mt-8 grid grid-cols-3 gap-6">
            <div className="col-span-2">
              <RecentBookings />
            </div>
            <div>
              <QuickActions />
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function OnboardingCTA() {
  return (
    <div className="border border-[#C47B2B]/30 bg-[#C47B2B]/5 p-10 text-center max-w-xl mx-auto mt-16">
      <div className="font-fraunces text-4xl mb-4">🏪</div>
      <h2 className="font-fraunces text-2xl font-bold text-stone-900 mb-3">
        Register your first business
      </h2>
      <p className="text-stone-500 text-sm mb-8 leading-relaxed">
        Get on the Hapa map in under 10 minutes. Free to start — upgrade when you see the value.
      </p>
      <Link
        href="/dashboard/places/new"
        className="font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white font-bold px-8 py-3 hover:bg-[#E8A84A] transition-colors inline-block"
      >
        Register Business
      </Link>
    </div>
  );
}

function StatCards() {
  const stats = [
    { label: "Profile Views", value: "—", icon: Eye, change: null },
    { label: "Avg Rating", value: "—", icon: Star, change: null },
    { label: "Bookings This Week", value: "0", icon: Calendar, change: null },
    { label: "Boost Reach", value: "—", icon: TrendingUp, change: null },
  ];

  return (
    <div className="grid grid-cols-4 gap-4">
      {stats.map(({ label, value, icon: Icon }) => (
        <div key={label} className="bg-white border border-stone-200 p-5">
          <div className="flex items-center justify-between mb-3">
            <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">{label}</p>
            <Icon size={14} className="text-[#C47B2B]" />
          </div>
          <p className="font-fraunces text-3xl font-bold text-stone-900">{value}</p>
        </div>
      ))}
    </div>
  );
}

function RecentBookings() {
  return (
    <div className="bg-white border border-stone-200">
      <div className="p-5 border-b border-stone-100 flex items-center justify-between">
        <h3 className="font-fraunces text-lg font-semibold">Recent Bookings</h3>
        <Link href="/dashboard/bookings" className="text-[#C47B2B] text-xs flex items-center gap-1 hover:underline">
          View all <ArrowUpRight size={12} />
        </Link>
      </div>
      <div className="p-8 text-center">
        <p className="text-stone-400 text-sm">No bookings yet.</p>
        <p className="text-stone-300 text-xs mt-1">
          Upgrade to Growth tier to enable in-app bookings.
        </p>
      </div>
    </div>
  );
}

function QuickActions() {
  const actions = [
    { label: "Launch Boost", href: "/dashboard/boost", icon: "⚡", desc: "Push a promotion now" },
    { label: "Post a Flash", href: "/dashboard/flash", icon: "🔥", desc: "Real-time announcement", badge: "NEW" },
    { label: "Join Circles", href: "/dashboard/circles", icon: "⭕", desc: "Community groups", badge: "NEW" },
    { label: "Find Creators", href: "/dashboard/creators", icon: "🎙️", desc: "Partnership hub" },
    { label: "Notification Intel", href: "/dashboard/notifications", icon: "🔔", desc: "Best send times", badge: "NEW" },
    { label: "View Analytics", href: "/dashboard/analytics", icon: "📊", desc: "Performance data" },
  ];

  return (
    <div className="bg-white border border-stone-200">
      <div className="p-5 border-b border-stone-100">
        <h3 className="font-fraunces text-lg font-semibold">Quick Actions</h3>
      </div>
      <div className="divide-y divide-stone-100">
        {actions.map(({ label, href, icon, desc, badge }) => (
          <Link
            key={label}
            href={href}
            className="flex items-center gap-3 px-5 py-3 hover:bg-stone-50 transition-colors group"
          >
            <span className="text-base shrink-0">{icon}</span>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-sm text-stone-700 group-hover:text-stone-900 font-medium">{label}</span>
                {badge && (
                  <span className="font-mono text-[8px] uppercase tracking-widest bg-[#C47B2B] text-white px-1.5 py-0.5">
                    {badge}
                  </span>
                )}
              </div>
              <span className="font-mono text-[10px] text-stone-400">{desc}</span>
            </div>
            <ArrowUpRight size={12} className="text-stone-300 group-hover:text-[#C47B2B] shrink-0" />
          </Link>
        ))}
      </div>
    </div>
  );
}
