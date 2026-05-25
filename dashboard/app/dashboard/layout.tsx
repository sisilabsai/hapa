"use client";
import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { LayoutDashboard, MapPin, Zap, Calendar, Users, BarChart3, Settings, LogOut, Flame, CircleDot, Bell } from "lucide-react";
import { api } from "@/lib/api";

const navItems: { href: string; label: string; icon: React.ElementType; badge?: string }[] = [
  { href: "/dashboard", label: "Overview", icon: LayoutDashboard },
  { href: "/dashboard/places", label: "My Places", icon: MapPin },
  { href: "/dashboard/boost", label: "Hapa Boost", icon: Zap },
  { href: "/dashboard/flash", label: "Hapa Flash", icon: Flame, badge: "NEW" },
  { href: "/dashboard/circles", label: "Circles", icon: CircleDot, badge: "NEW" },
  { href: "/dashboard/bookings", label: "Bookings", icon: Calendar },
  { href: "/dashboard/creators", label: "Creator Partners", icon: Users },
  { href: "/dashboard/notifications", label: "Notifications", icon: Bell, badge: "NEW" },
  { href: "/dashboard/analytics", label: "Analytics", icon: BarChart3 },
  { href: "/dashboard/settings", label: "Settings", icon: Settings },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const [displayName, setDisplayName] = useState("Business Owner");

  useEffect(() => {
    const token = api.getToken();
    if (!token) {
      router.replace("/auth/login");
      return;
    }
    setReady(true);

    // Load user name for sidebar display
    api.get<{ display_name?: string }>("/v1/users/me")
      .then((u) => { if (u.display_name) setDisplayName(u.display_name); })
      .catch(() => {});
  }, [router]);

  function handleLogout() {
    localStorage.removeItem("hapa_token");
    router.replace("/auth/login");
  }

  if (!ready) {
    return (
      <div className="min-h-screen bg-[#1A1208] flex items-center justify-center">
        <div className="text-center space-y-3">
          <span className="font-fraunces text-4xl font-black text-[#C47B2B]">Hapa</span>
          <p className="font-mono text-xs text-stone-600 uppercase tracking-widest">Loading…</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-stone-50">
      {/* Sidebar */}
      <aside className="w-56 bg-[#1A1208] flex flex-col shrink-0">
        <div className="p-6 border-b border-stone-800">
          <Link href="/">
            <span className="font-fraunces text-2xl font-black text-[#C47B2B]">Hapa</span>
          </Link>
          <p className="font-mono text-[10px] text-stone-600 uppercase tracking-widest mt-0.5">Business</p>
        </div>

        <nav className="flex-1 p-3 space-y-0.5 overflow-y-auto">
          {navItems.map(({ href, label, icon: Icon, badge }) => {
            const active = href === "/dashboard"
              ? pathname === "/dashboard"
              : pathname.startsWith(href);
            return (
              <Link
                key={href}
                href={href}
                className={`flex items-center gap-3 px-3 py-2.5 transition-colors group ${
                  active
                    ? "bg-stone-800 text-stone-100"
                    : "text-stone-400 hover:text-stone-100 hover:bg-stone-800"
                }`}
              >
                <Icon
                  size={15}
                  className={`shrink-0 transition-colors ${
                    active ? "text-[#C47B2B]" : "group-hover:text-[#C47B2B]"
                  }`}
                />
                <span className="text-xs font-medium flex-1">{label}</span>
                {badge && !active && (
                  <span className="font-mono text-[8px] uppercase tracking-widest bg-[#C47B2B] text-white px-1.5 py-0.5 shrink-0">
                    {badge}
                  </span>
                )}
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-stone-800 space-y-2">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-[#C47B2B]/20 flex items-center justify-center shrink-0">
              <span className="text-[#C47B2B] text-xs font-bold">
                {displayName.charAt(0).toUpperCase()}
              </span>
            </div>
            <div className="min-w-0">
              <p className="text-stone-200 text-xs font-medium truncate">{displayName}</p>
              <p className="font-mono text-stone-600 text-[10px]">Business Owner</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-2 px-3 py-2 text-stone-500 hover:text-stone-300 hover:bg-stone-800 transition-colors text-xs font-mono"
          >
            <LogOut size={13} />
            Sign out
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-y-auto">
        {children}
      </main>
    </div>
  );
}
