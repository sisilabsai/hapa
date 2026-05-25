"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { endpoints, Business, Circle, CirclePost } from "@/lib/api";
import {
  Users, MapPin, Plus, ChevronRight, CheckCircle2, Building2,
  MessageSquare, Heart, Send, X, AlertCircle, Globe, Lock, Sparkles,
} from "lucide-react";
import { formatDistanceToNow } from "date-fns";

// ── Category → relevant circle categories ─────────────────────────────────────

const CATEGORY_AFFINITY: Record<string, string[]> = {
  restaurant: ["food", "dining", "nightlife", "lifestyle"],
  food: ["food", "dining", "markets", "lifestyle"],
  nightlife: ["nightlife", "entertainment", "lifestyle", "music"],
  cafe: ["food", "lifestyle", "tech", "work"],
  retail: ["shopping", "fashion", "lifestyle", "markets"],
  wellness: ["wellness", "fitness", "health", "lifestyle"],
  beauty: ["beauty", "lifestyle", "fashion", "wellness"],
  tech: ["tech", "business", "networking"],
  services: ["business", "networking", "community"],
};

// ── Circle card ────────────────────────────────────────────────────────────────

function CircleCard({
  circle,
  onJoin,
  onLeave,
  onOpen,
  isJoining,
}: {
  circle: Circle;
  onJoin: () => void;
  onLeave: () => void;
  onOpen: () => void;
  isJoining: boolean;
}) {
  return (
    <div className="bg-white border border-stone-200 p-5 hover:border-[#C47B2B]/40 transition-colors">
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-fraunces font-semibold text-stone-900 text-sm">{circle.name}</span>
            {circle.is_member && (
              <span className="flex items-center gap-0.5 font-mono text-[9px] text-[#C47B2B] uppercase tracking-widest bg-[#C47B2B]/8 px-1.5 py-0.5">
                <CheckCircle2 size={8} /> Member
              </span>
            )}
            {!circle.is_public && (
              <span className="flex items-center gap-0.5 font-mono text-[9px] text-stone-500 bg-stone-100 px-1.5 py-0.5">
                <Lock size={8} /> Private
              </span>
            )}
          </div>
          <p className="flex items-center gap-1 font-mono text-[10px] text-stone-400 mt-1">
            <MapPin size={9} /> {circle.city}
            <span className="mx-1 text-stone-300">·</span>
            <span className="capitalize">{circle.category}</span>
          </p>
        </div>
        <div className="text-right shrink-0">
          <p className="font-fraunces font-bold text-stone-900 text-lg">{circle.member_count.toLocaleString()}</p>
          <p className="font-mono text-[9px] text-stone-400 uppercase tracking-wide">members</p>
        </div>
      </div>

      {circle.description && (
        <p className="text-stone-500 text-xs leading-relaxed mb-4 line-clamp-2">{circle.description}</p>
      )}

      <div className="flex gap-2">
        {circle.is_member ? (
          <>
            <button
              onClick={onOpen}
              className="flex-1 flex items-center justify-center gap-1.5 font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white py-2 hover:bg-[#E8A84A] transition-colors"
            >
              <Send size={11} /> Post to Circle
            </button>
            <button
              onClick={onLeave}
              disabled={isJoining}
              className="font-mono text-[10px] uppercase tracking-widest border border-stone-200 text-stone-400 px-3 py-2 hover:border-red-300 hover:text-red-400 transition-colors disabled:opacity-40"
            >
              Leave
            </button>
          </>
        ) : (
          <button
            onClick={onJoin}
            disabled={isJoining}
            className="flex-1 flex items-center justify-center gap-1.5 font-mono text-[10px] uppercase tracking-widest border border-[#C47B2B] text-[#C47B2B] py-2 hover:bg-[#C47B2B] hover:text-white transition-colors disabled:opacity-40"
          >
            <Plus size={11} /> {isJoining ? "Joining…" : "Join Circle"}
          </button>
        )}
        <button
          onClick={onOpen}
          className="font-mono text-[10px] uppercase tracking-widest border border-stone-200 text-stone-500 px-3 py-2 hover:border-stone-400 transition-colors flex items-center gap-1"
        >
          <ChevronRight size={12} />
        </button>
      </div>
    </div>
  );
}

// ── Circle detail / post modal ─────────────────────────────────────────────────

function CircleModal({
  circle,
  business,
  onClose,
}: {
  circle: Circle;
  business: Business | null;
  onClose: () => void;
}) {
  const [postText, setPostText] = useState("");
  const [tab, setTab] = useState<"posts" | "compose">("posts");

  const { data: postsData } = useQuery({
    queryKey: ["circle-posts", circle.id],
    queryFn: () => endpoints.circles.posts(circle.id),
    enabled: tab === "posts",
  });

  const postMutation = useMutation({
    mutationFn: () =>
      endpoints.flash.create({
        post_type: "location",
        content: postText,
        city: circle.city,
      } as any),
    onSuccess: () => {
      setPostText("");
      setTab("posts");
    },
  });

  const posts = postsData?.posts ?? [];

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-6" onClick={onClose}>
      <div className="bg-white max-w-lg w-full max-h-[80vh] flex flex-col" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="p-5 border-b border-stone-100 flex items-start justify-between">
          <div>
            <h3 className="font-fraunces text-lg font-semibold text-stone-900">{circle.name}</h3>
            <p className="font-mono text-[10px] text-stone-400 mt-0.5">
              {circle.member_count.toLocaleString()} members · {circle.city}
            </p>
          </div>
          <button onClick={onClose} className="text-stone-400 hover:text-stone-600 mt-0.5">
            <X size={18} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-stone-100">
          {(["posts", "compose"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`flex-1 font-mono text-[10px] uppercase tracking-widest py-3 transition-colors ${
                tab === t ? "text-[#C47B2B] border-b-2 border-[#C47B2B]" : "text-stone-400 hover:text-stone-600"
              }`}
            >
              {t === "posts" ? "Recent Posts" : "Post to Circle"}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {tab === "posts" ? (
            <div className="divide-y divide-stone-100">
              {posts.length === 0 ? (
                <div className="p-8 text-center text-stone-400 text-sm">No posts yet. Be the first!</div>
              ) : (
                posts.map((post) => (
                  <div key={post.id} className="p-4">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-7 h-7 rounded-full bg-stone-100 flex items-center justify-center">
                        <span className="font-bold text-stone-500 text-[11px]">{(post.display_name || "U")[0]}</span>
                      </div>
                      <div>
                        <span className="text-stone-800 text-xs font-medium">{post.display_name}</span>
                        <span className="text-stone-400 text-[10px] ml-2">
                          {formatDistanceToNow(new Date(post.created_at), { addSuffix: true })}
                        </span>
                      </div>
                    </div>
                    <p className="text-stone-700 text-sm leading-relaxed">{post.content}</p>
                    <div className="flex items-center gap-4 mt-2.5">
                      <span className="flex items-center gap-1 font-mono text-[10px] text-stone-400">
                        <Heart size={10} /> {post.like_count}
                      </span>
                      <span className="flex items-center gap-1 font-mono text-[10px] text-stone-400">
                        <MessageSquare size={10} /> {post.comment_count}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          ) : (
            <div className="p-5 space-y-4">
              {!circle.is_member && (
                <div className="flex items-start gap-2 bg-amber-50 border border-amber-100 p-3">
                  <AlertCircle size={13} className="text-amber-600 shrink-0 mt-0.5" />
                  <p className="text-amber-700 text-xs">Join this circle first to post in it.</p>
                </div>
              )}
              {business && (
                <div className="flex items-center gap-2 bg-stone-50 border border-stone-200 p-3">
                  <span className="font-mono text-[10px] text-stone-400">Posting as:</span>
                  <span className="font-medium text-stone-800 text-xs">{business.name}</span>
                </div>
              )}
              <textarea
                value={postText}
                onChange={(e) => setPostText(e.target.value)}
                placeholder={`Share something with ${circle.name}…`}
                className="input w-full min-h-[120px] resize-none text-sm"
                maxLength={280}
                disabled={!circle.is_member}
              />
              <p className="font-mono text-[10px] text-stone-400">{280 - postText.length} characters remaining</p>
              <button
                onClick={() => postMutation.mutate()}
                disabled={!postText || !circle.is_member || postMutation.isPending}
                className="w-full font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white py-3 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                <Send size={13} />
                {postMutation.isPending ? "Posting…" : `Post to ${circle.name}`}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────

export default function CirclesPage() {
  const qc = useQueryClient();
  const [selectedBiz, setSelectedBiz] = useState<Business | null>(null);
  const [cityFilter, setCityFilter] = useState("");
  const [activeTab, setActiveTab] = useState<"discover" | "mine">("discover");
  const [selectedCircle, setSelectedCircle] = useState<Circle | null>(null);
  const [joiningId, setJoiningId] = useState<string | null>(null);

  const { data: bizData } = useQuery({
    queryKey: ["my-businesses"],
    queryFn: () => endpoints.business.mine(),
  });

  const city = cityFilter || selectedBiz?.city || "";

  const { data: discoverData, isLoading: discoverLoading } = useQuery({
    queryKey: ["circles-discover", city],
    queryFn: () => endpoints.circles.discover(city),
    enabled: activeTab === "discover",
  });

  const { data: mineData, isLoading: mineLoading } = useQuery({
    queryKey: ["circles-mine"],
    queryFn: () => endpoints.circles.mine(),
    enabled: activeTab === "mine",
  });

  const businesses = bizData?.businesses ?? [];
  const circles = activeTab === "discover"
    ? discoverData?.circles ?? []
    : mineData?.circles ?? [];

  // Relevance sort for discover: put category-matching circles first
  const sortedCircles = activeTab === "discover" && selectedBiz
    ? [...circles].sort((a, b) => {
        const affinities = CATEGORY_AFFINITY[selectedBiz.category?.toLowerCase()] ?? [];
        const aScore = affinities.some((k) => a.category?.toLowerCase().includes(k)) ? 1 : 0;
        const bScore = affinities.some((k) => b.category?.toLowerCase().includes(k)) ? 1 : 0;
        return bScore - aScore;
      })
    : circles;

  const handleJoin = async (circle: Circle) => {
    setJoiningId(circle.id);
    try {
      await endpoints.circles.join(circle.id);
      qc.invalidateQueries({ queryKey: ["circles-discover"] });
      qc.invalidateQueries({ queryKey: ["circles-mine"] });
    } finally {
      setJoiningId(null);
    }
  };

  const handleLeave = async (circle: Circle) => {
    setJoiningId(circle.id);
    try {
      await endpoints.circles.leave(circle.id);
      qc.invalidateQueries({ queryKey: ["circles-discover"] });
      qc.invalidateQueries({ queryKey: ["circles-mine"] });
    } finally {
      setJoiningId(null);
    }
  };

  const isLoading = activeTab === "discover" ? discoverLoading : mineLoading;

  return (
    <div className="p-8 max-w-5xl space-y-8">
      {/* Header */}
      <div>
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <Users className="text-[#C47B2B]" size={28} />
          Community Circles
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Join the community groups where your future customers already gather. Post in circles they trust.
        </p>
      </div>

      {/* Value prop */}
      <div className="bg-[#1A1208] p-6 grid grid-cols-3 gap-6">
        {[
          { icon: "🎯", title: "Reach the right people", desc: "A \"Nairobi Food Lovers\" circle has 2,000+ members who eat out. You can post directly to them." },
          { icon: "🤝", title: "Build trust organically", desc: "Business posts in circles feel like community — not advertising. Engagement rates are 4–8× higher." },
          { icon: "📍", title: "City-specific reach", desc: "Every circle is anchored to a city. Your posts stay relevant and local — never lost in a global feed." },
        ].map(({ icon, title, desc }) => (
          <div key={title}>
            <div className="text-2xl mb-2">{icon}</div>
            <div className="font-fraunces text-white font-semibold text-sm mb-1">{title}</div>
            <div className="text-stone-400 text-xs leading-relaxed">{desc}</div>
          </div>
        ))}
      </div>

      {/* Business selector */}
      {businesses.length > 0 && (
        <section>
          <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400 mb-3">
            Active business profile
          </p>
          <div className="flex gap-3 overflow-x-auto pb-1">
            {businesses.map((biz) => (
              <button
                key={biz.id}
                onClick={() => { setSelectedBiz(biz); setCityFilter(biz.city); }}
                className={`relative text-left border p-3 shrink-0 w-44 transition-all text-sm ${
                  selectedBiz?.id === biz.id
                    ? "border-[#C47B2B] bg-[#C47B2B]/5"
                    : "border-stone-200 bg-white hover:border-[#C47B2B]/50"
                }`}
              >
                {selectedBiz?.id === biz.id && <CheckCircle2 size={12} className="absolute top-2 right-2 text-[#C47B2B]" />}
                <p className="font-semibold text-stone-900 text-xs truncate">{biz.name}</p>
                <p className="font-mono text-[9px] text-stone-400 mt-0.5">{biz.city}</p>
              </button>
            ))}
          </div>
        </section>
      )}

      {/* Tabs + search */}
      <div className="flex items-center justify-between">
        <div className="flex border border-stone-200">
          {(["discover", "mine"] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`font-mono text-[10px] uppercase tracking-widest px-5 py-2.5 transition-colors ${
                activeTab === tab
                  ? "bg-[#C47B2B] text-white"
                  : "text-stone-500 hover:text-stone-700"
              }`}
            >
              {tab === "discover" ? "Discover Circles" : "My Circles"}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-3">
          <input
            type="text"
            placeholder="Filter by city…"
            value={cityFilter}
            onChange={(e) => setCityFilter(e.target.value)}
            className="input max-w-[180px] text-sm"
          />
        </div>
      </div>

      {/* Relevance notice */}
      {activeTab === "discover" && selectedBiz && sortedCircles.length > 0 && (
        <div className="flex items-center gap-2 bg-stone-50 border border-stone-200 px-4 py-2.5">
          <Sparkles size={12} className="text-[#C47B2B]" />
          <p className="font-mono text-[10px] text-stone-500">
            Sorted by relevance to <strong className="text-stone-700">{selectedBiz.name}</strong> ({selectedBiz.category})
          </p>
        </div>
      )}

      {/* Circles grid */}
      {isLoading ? (
        <div className="grid grid-cols-2 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="bg-white border border-stone-200 p-5 animate-pulse h-40" />
          ))}
        </div>
      ) : sortedCircles.length === 0 ? (
        <div className="border border-dashed border-stone-300 p-12 text-center">
          <Users size={32} className="text-stone-300 mx-auto mb-3" />
          <p className="text-stone-500 font-semibold mb-1">
            {activeTab === "mine" ? "Not a member of any circles yet" : "No circles found"}
          </p>
          <p className="text-stone-400 text-sm">
            {activeTab === "mine"
              ? "Discover circles relevant to your business and join them."
              : "Try a different city — circles are growing every week."}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4">
          {sortedCircles.map((circle) => (
            <CircleCard
              key={circle.id}
              circle={circle}
              onJoin={() => handleJoin(circle)}
              onLeave={() => handleLeave(circle)}
              onOpen={() => setSelectedCircle(circle)}
              isJoining={joiningId === circle.id}
            />
          ))}
        </div>
      )}

      {/* Circle modal */}
      {selectedCircle && (
        <CircleModal
          circle={selectedCircle}
          business={selectedBiz}
          onClose={() => setSelectedCircle(null)}
        />
      )}
    </div>
  );
}
