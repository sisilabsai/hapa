"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type Creator } from "@/lib/api";
import { Users, Star, MessageSquare, Instagram, Youtube, Twitter, Send, ChevronRight } from "lucide-react";

const TIER_CONFIG: Record<string, { label: string; color: string }> = {
  rising_voice: { label: "Rising Voice", color: "bg-stone-100 text-stone-600" },
  local_voice: { label: "Local Voice", color: "bg-blue-50 text-blue-600" },
  city_voice: { label: "City Voice", color: "bg-[#C47B2B]/10 text-[#C47B2B]" },
};

type ColabRequest = {
  business_id: string;
  creator_id: string;
  message: string;
  offer_usd?: number;
};

export default function CreatorsPage() {
  const [city, setCity] = useState("");
  const [selectedCreator, setSelectedCreator] = useState<Creator | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["creators", city],
    queryFn: () => api.get<{ creators: Creator[] }>(`/v1/creators/discover?city=${city}&limit=20`),
  });

  const creators = data?.creators ?? [];

  return (
    <div className="p-8 max-w-5xl">
      <div className="mb-8">
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <Users className="text-[#C47B2B]" size={28} />
          Creator Partners
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Partner with local creators to reach their engaged, hyper-local audiences.
        </p>
      </div>

      {/* How it works */}
      <div className="bg-[#1A1208] p-6 mb-8 grid grid-cols-3 gap-6">
        {[
          {
            step: "01",
            title: "Find a creator",
            desc: "Browse vetted creators in your city ranked by local engagement.",
          },
          {
            step: "02",
            title: "Send a collab offer",
            desc: "Propose a deal: free meal, product trial, or direct payment.",
          },
          {
            step: "03",
            title: "Track the impact",
            desc: "Every booking that cites their post is attributed automatically.",
          },
        ].map(({ step, title, desc }) => (
          <div key={step}>
            <div className="font-mono text-[#C47B2B] text-xs font-bold mb-2">{step}</div>
            <div className="font-fraunces text-white font-semibold mb-1">{title}</div>
            <div className="text-stone-400 text-xs leading-relaxed">{desc}</div>
          </div>
        ))}
      </div>

      {/* Filter bar */}
      <div className="flex items-center gap-3 mb-6">
        <input
          type="text"
          placeholder="Filter by city…"
          value={city}
          onChange={(e) => setCity(e.target.value)}
          className="input max-w-[200px]"
        />
        <span className="font-mono text-[10px] text-stone-400 uppercase tracking-widest">
          {creators.length} creator{creators.length !== 1 ? "s" : ""} found
        </span>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-2 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="bg-white border border-stone-200 p-5 animate-pulse">
              <div className="flex gap-3">
                <div className="w-12 h-12 bg-stone-100 rounded-full" />
                <div className="flex-1">
                  <div className="h-4 bg-stone-100 rounded w-1/2 mb-2" />
                  <div className="h-3 bg-stone-100 rounded w-3/4" />
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : creators.length === 0 ? (
        <div className="border border-dashed border-stone-300 p-16 text-center">
          <Users size={32} className="text-stone-300 mx-auto mb-4" />
          <h3 className="font-fraunces text-xl font-semibold text-stone-700 mb-2">
            No creators found
          </h3>
          <p className="text-stone-400 text-sm">
            Try a different city filter or check back soon — more creators are joining every week.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4">
          {creators.map((creator) => (
            <CreatorCard
              key={creator.id}
              creator={creator}
              onSelect={() => setSelectedCreator(creator)}
            />
          ))}
        </div>
      )}

      {/* Collab modal */}
      {selectedCreator && (
        <ColabModal
          creator={selectedCreator}
          onClose={() => setSelectedCreator(null)}
        />
      )}
    </div>
  );
}

function CreatorCard({ creator, onSelect }: { creator: Creator; onSelect: () => void }) {
  const tier = TIER_CONFIG[creator.tier ?? "rising_voice"];

  return (
    <div className="bg-white border border-stone-200 p-5 hover:border-[#C47B2B]/40 transition-colors">
      <div className="flex items-start gap-3 mb-4">
        <div className="w-12 h-12 bg-[#C47B2B]/10 rounded-full flex items-center justify-center shrink-0">
          <span className="font-fraunces font-black text-[#C47B2B]">
            {(creator.display_name ?? "C")[0]}
          </span>
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-semibold text-stone-900">{creator.display_name}</span>
            <span className={`font-mono text-[9px] uppercase tracking-widest px-1.5 py-0.5 rounded-sm ${tier.color}`}>
              {tier.label}
            </span>
          </div>
          {creator.city && (
            <span className="font-mono text-[10px] text-stone-400">{creator.city}</span>
          )}
          {creator.bio && (
            <p className="text-stone-500 text-xs mt-1 line-clamp-2">{creator.bio}</p>
          )}
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-2 mb-4">
        <Metric label="Followers" value={creator.follower_count?.toLocaleString() ?? "—"} />
        <Metric label="Posts" value={creator.post_count?.toLocaleString() ?? "—"} />
        <Metric label="Eng. Rate" value={creator.engagement_rate ? `${(creator.engagement_rate * 100).toFixed(1)}%` : "—"} />
      </div>

      {/* Socials */}
      {creator.social_links && Object.keys(creator.social_links).length > 0 && (
        <div className="flex items-center gap-2 mb-4">
          {creator.social_links.instagram && (
            <a
              href={creator.social_links.instagram}
              target="_blank"
              rel="noopener noreferrer"
              className="text-stone-400 hover:text-[#C47B2B] transition-colors"
            >
              <Instagram size={13} />
            </a>
          )}
          {creator.social_links.youtube && (
            <a
              href={creator.social_links.youtube}
              target="_blank"
              rel="noopener noreferrer"
              className="text-stone-400 hover:text-[#C47B2B] transition-colors"
            >
              <Youtube size={13} />
            </a>
          )}
          {creator.social_links.twitter && (
            <a
              href={creator.social_links.twitter}
              target="_blank"
              rel="noopener noreferrer"
              className="text-stone-400 hover:text-[#C47B2B] transition-colors"
            >
              <Twitter size={13} />
            </a>
          )}
        </div>
      )}

      <button
        onClick={onSelect}
        className="w-full flex items-center justify-center gap-2 font-mono text-[10px] uppercase tracking-widest border border-[#C47B2B] text-[#C47B2B] py-2 hover:bg-[#C47B2B] hover:text-white transition-colors"
      >
        <Send size={11} />
        Propose Collab
        <ChevronRight size={11} />
      </button>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="text-center bg-stone-50 py-2 px-1">
      <div className="font-fraunces text-base font-bold text-stone-900">{value}</div>
      <div className="font-mono text-[9px] uppercase tracking-widest text-stone-400 mt-0.5">{label}</div>
    </div>
  );
}

function ColabModal({ creator, onClose }: { creator: Creator; onClose: () => void }) {
  const [message, setMessage] = useState("");
  const [offerUsd, setOfferUsd] = useState("");

  const mutation = useMutation({
    mutationFn: () =>
      api.post("/v1/creators/collab", {
        creator_id: creator.id,
        message,
        offer_usd: offerUsd ? Number(offerUsd) : undefined,
      }),
    onSuccess: onClose,
  });

  return (
    <div
      className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-6"
      onClick={onClose}
    >
      <div
        className="bg-white max-w-md w-full p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="font-fraunces text-xl font-semibold mb-1">
          Propose Collaboration
        </h3>
        <p className="text-stone-500 text-sm mb-5">
          Send a message to <strong>{creator.display_name}</strong>
        </p>

        <div className="space-y-4">
          <div>
            <label className="font-mono text-[10px] uppercase tracking-widest text-stone-400 block mb-2">
              Your Message *
            </label>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Hi! We'd love for you to visit and share your experience with your audience. We can offer..."
              className="input min-h-[120px] resize-none w-full"
              maxLength={600}
            />
          </div>

          <div>
            <label className="font-mono text-[10px] uppercase tracking-widest text-stone-400 block mb-2">
              Cash Offer (USD, optional)
            </label>
            <input
              type="number"
              value={offerUsd}
              onChange={(e) => setOfferUsd(e.target.value)}
              placeholder="0"
              min="0"
              className="input w-full"
            />
            <span className="font-mono text-[10px] text-stone-400 mt-1 block">
              Leave blank for product/experience-only collab
            </span>
          </div>
        </div>

        <div className="flex gap-3 mt-6">
          <button
            onClick={onClose}
            className="flex-1 font-mono text-xs uppercase tracking-widest border border-stone-200 text-stone-500 py-2.5 hover:bg-stone-50 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => mutation.mutate()}
            disabled={!message || mutation.isPending}
            className="flex-1 font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white py-2.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {mutation.isPending ? "Sending…" : "Send Proposal"}
          </button>
        </div>
      </div>
    </div>
  );
}
