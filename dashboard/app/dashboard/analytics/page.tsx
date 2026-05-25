"use client";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { BarChart3, Eye, Star, Calendar, TrendingUp, Zap, Users, ArrowUp, ArrowDown } from "lucide-react";
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";

type AnalyticsSummary = {
  views_total: number;
  views_change: number;
  bookings_total: number;
  bookings_change: number;
  avg_rating: number;
  review_count: number;
  boost_reach: number;
  boost_change: number;
  been_here_count: number;
  followers_count: number;
};

type TimeSeriesPoint = { date: string; views: number; bookings: number };
type CategoryBreakdown = { category: string; count: number };

const OCHRE = "#C47B2B";
const OCHRE_MUTED = "#E8A84A";

function mockTimeSeries(): TimeSeriesPoint[] {
  const data = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    data.push({
      date: d.toLocaleDateString("en", { month: "short", day: "numeric" }),
      views: Math.floor(Math.random() * 120 + 20),
      bookings: Math.floor(Math.random() * 8),
    });
  }
  return data;
}

function mockCategoryData(): CategoryBreakdown[] {
  return [
    { category: "Organic Search", count: 42 },
    { category: "Boost", count: 28 },
    { category: "Creator Post", count: 18 },
    { category: "Direct", count: 12 },
  ];
}

export default function AnalyticsPage() {
  const { data: summary } = useQuery<AnalyticsSummary>({
    queryKey: ["analytics-summary"],
    queryFn: () => api.get("/v1/analytics/summary"),
    placeholderData: {
      views_total: 1247,
      views_change: 12.4,
      bookings_total: 43,
      bookings_change: -3.2,
      avg_rating: 4.3,
      review_count: 18,
      boost_reach: 3200,
      boost_change: 22.1,
      been_here_count: 89,
      followers_count: 134,
    },
  });

  const timeSeries = mockTimeSeries();
  const categoryData = mockCategoryData();

  const COLORS = [OCHRE, "#D4956A", "#8B5E2A", "#4A3219"];

  return (
    <div className="p-8 max-w-6xl">
      <div className="mb-8">
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <BarChart3 className="text-[#C47B2B]" size={28} />
          Analytics
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Performance overview for the last 30 days.
        </p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-4 gap-4 mb-8">
        <KpiCard
          icon={Eye}
          label="Profile Views"
          value={summary?.views_total.toLocaleString() ?? "—"}
          change={summary?.views_change}
        />
        <KpiCard
          icon={Calendar}
          label="Bookings"
          value={summary?.bookings_total.toLocaleString() ?? "—"}
          change={summary?.bookings_change}
        />
        <KpiCard
          icon={Zap}
          label="Boost Reach"
          value={summary?.boost_reach ? `${(summary.boost_reach / 1000).toFixed(1)}k` : "—"}
          change={summary?.boost_change}
        />
        <KpiCard
          icon={Users}
          label="Been Here"
          value={summary?.been_here_count?.toLocaleString() ?? "—"}
          change={null}
        />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-3 gap-6 mb-6">
        {/* Views + bookings over time */}
        <div className="col-span-2 bg-white border border-stone-200 p-6">
          <h3 className="font-fraunces text-base font-semibold mb-5">Views & Bookings (30 days)</h3>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={timeSeries} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="viewsGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={OCHRE} stopOpacity={0.15} />
                  <stop offset="95%" stopColor={OCHRE} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f5f0eb" />
              <XAxis
                dataKey="date"
                tick={{ fontSize: 9, fontFamily: "JetBrains Mono", fill: "#a8a29e" }}
                tickLine={false}
                axisLine={false}
                interval={6}
              />
              <YAxis
                tick={{ fontSize: 9, fontFamily: "JetBrains Mono", fill: "#a8a29e" }}
                tickLine={false}
                axisLine={false}
              />
              <Tooltip
                contentStyle={{
                  background: "#1A1208",
                  border: "none",
                  borderRadius: 6,
                  color: "#F5EFE0",
                  fontSize: 11,
                  fontFamily: "JetBrains Mono",
                }}
                labelStyle={{ color: "#a8a29e" }}
              />
              <Area
                type="monotone"
                dataKey="views"
                stroke={OCHRE}
                strokeWidth={1.5}
                fill="url(#viewsGrad)"
                dot={false}
                name="Views"
              />
              <Bar dataKey="bookings" fill={OCHRE_MUTED} name="Bookings" barSize={4} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Traffic sources */}
        <div className="bg-white border border-stone-200 p-6">
          <h3 className="font-fraunces text-base font-semibold mb-5">Traffic Sources</h3>
          <ResponsiveContainer width="100%" height={140}>
            <PieChart>
              <Pie
                data={categoryData}
                dataKey="count"
                nameKey="category"
                cx="50%"
                cy="50%"
                innerRadius={40}
                outerRadius={65}
                paddingAngle={2}
              >
                {categoryData.map((_, index) => (
                  <Cell key={index} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip
                contentStyle={{
                  background: "#1A1208",
                  border: "none",
                  borderRadius: 6,
                  color: "#F5EFE0",
                  fontSize: 11,
                  fontFamily: "JetBrains Mono",
                }}
              />
            </PieChart>
          </ResponsiveContainer>
          <div className="space-y-2 mt-3">
            {categoryData.map(({ category, count }, i) => (
              <div key={category} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div
                    className="w-2 h-2 rounded-full shrink-0"
                    style={{ background: COLORS[i % COLORS.length] }}
                  />
                  <span className="font-mono text-[10px] text-stone-500">{category}</span>
                </div>
                <span className="font-mono text-[10px] font-bold text-stone-700">{count}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Rating + secondary stats */}
      <div className="grid grid-cols-3 gap-6">
        <div className="bg-white border border-stone-200 p-6">
          <h3 className="font-fraunces text-base font-semibold mb-4">Rating Overview</h3>
          <div className="flex items-end gap-3 mb-4">
            <span className="font-fraunces text-5xl font-black text-stone-900">
              {summary?.avg_rating?.toFixed(1) ?? "—"}
            </span>
            <div className="mb-1">
              <div className="flex gap-0.5">
                {[1, 2, 3, 4, 5].map((s) => (
                  <Star
                    key={s}
                    size={14}
                    className={
                      s <= Math.round(summary?.avg_rating ?? 0)
                        ? "text-[#C47B2B] fill-[#C47B2B]"
                        : "text-stone-200 fill-stone-200"
                    }
                  />
                ))}
              </div>
              <span className="font-mono text-[10px] text-stone-400 mt-0.5 block">
                {summary?.review_count ?? 0} reviews
              </span>
            </div>
          </div>
          {[5, 4, 3, 2, 1].map((star) => {
            const pct = star === 5 ? 55 : star === 4 ? 30 : star === 3 ? 10 : star === 2 ? 3 : 2;
            return (
              <div key={star} className="flex items-center gap-2 mb-1.5">
                <span className="font-mono text-[10px] text-stone-400 w-4">{star}</span>
                <div className="flex-1 h-1.5 bg-stone-100 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-[#C47B2B] rounded-full transition-all"
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <span className="font-mono text-[10px] text-stone-400 w-6 text-right">{pct}%</span>
              </div>
            );
          })}
        </div>

        <div className="bg-white border border-stone-200 p-6">
          <h3 className="font-fraunces text-base font-semibold mb-4">Boost Performance</h3>
          <ResponsiveContainer width="100%" height={160}>
            <BarChart
              data={[
                { name: "Mon", reach: 320 },
                { name: "Tue", reach: 480 },
                { name: "Wed", reach: 210 },
                { name: "Thu", reach: 590 },
                { name: "Fri", reach: 780 },
                { name: "Sat", reach: 620 },
                { name: "Sun", reach: 430 },
              ]}
              margin={{ top: 0, right: 0, left: -20, bottom: 0 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#f5f0eb" />
              <XAxis
                dataKey="name"
                tick={{ fontSize: 9, fontFamily: "JetBrains Mono", fill: "#a8a29e" }}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                tick={{ fontSize: 9, fontFamily: "JetBrains Mono", fill: "#a8a29e" }}
                tickLine={false}
                axisLine={false}
              />
              <Tooltip
                contentStyle={{
                  background: "#1A1208",
                  border: "none",
                  borderRadius: 6,
                  color: "#F5EFE0",
                  fontSize: 11,
                  fontFamily: "JetBrains Mono",
                }}
              />
              <Bar dataKey="reach" fill={OCHRE} barSize={18} radius={[2, 2, 0, 0]} name="Reach" />
            </BarChart>
          </ResponsiveContainer>
          <div className="mt-3 flex items-center justify-between">
            <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400">This week</span>
            <span className="font-mono text-sm font-bold text-stone-900">3,430 reached</span>
          </div>
        </div>

        <div className="bg-white border border-stone-200 p-6 space-y-4">
          <h3 className="font-fraunces text-base font-semibold">Audience</h3>
          <SecondaryMetric label="Profile Saves" value="—" />
          <SecondaryMetric label="Direction Requests" value="—" />
          <SecondaryMetric label="Phone Taps" value="—" />
          <SecondaryMetric label="WhatsApp Taps" value="—" />
          <SecondaryMetric label="Followers" value={summary?.followers_count?.toLocaleString() ?? "—"} />
          <div className="pt-3 border-t border-stone-100">
            <p className="font-mono text-[10px] text-stone-400 text-center">
              Detailed audience insights available on Pro tier.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

function KpiCard({
  icon: Icon,
  label,
  value,
  change,
}: {
  icon: any;
  label: string;
  value: string;
  change: number | null | undefined;
}) {
  return (
    <div className="bg-white border border-stone-200 p-5">
      <div className="flex items-center justify-between mb-3">
        <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400">{label}</p>
        <Icon size={14} className="text-[#C47B2B]" />
      </div>
      <p className="font-fraunces text-3xl font-bold text-stone-900">{value}</p>
      {change != null && (
        <div
          className={`flex items-center gap-1 mt-2 text-xs font-mono ${
            change >= 0 ? "text-green-600" : "text-red-500"
          }`}
        >
          {change >= 0 ? <ArrowUp size={11} /> : <ArrowDown size={11} />}
          {Math.abs(change).toFixed(1)}% vs last month
        </div>
      )}
    </div>
  );
}

function SecondaryMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400">{label}</span>
      <span className="text-stone-700 text-sm font-medium">{value}</span>
    </div>
  );
}
