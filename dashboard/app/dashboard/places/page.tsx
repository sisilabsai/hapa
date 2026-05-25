"use client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type Business } from "@/lib/api";
import { MapPin, Plus, Star, Clock, ChevronRight, Globe, Phone, Edit2, Trash2, Zap } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

const CATEGORY_LABELS: Record<string, string> = {
  restaurant: "Restaurant",
  cafe: "Café",
  bar: "Bar",
  hotel: "Hotel",
  shop: "Shop",
  salon: "Salon",
  gym: "Gym",
  clinic: "Clinic",
  pharmacy: "Pharmacy",
  supermarket: "Supermarket",
  market: "Market",
  entertainment: "Entertainment",
  services: "Services",
  other: "Other",
};

const TIER_BADGE: Record<string, { label: string; color: string }> = {
  free: { label: "Free", color: "bg-stone-100 text-stone-500" },
  growth: { label: "Growth", color: "bg-blue-50 text-blue-600" },
  pro: { label: "Pro", color: "bg-[#C47B2B]/10 text-[#C47B2B]" },
};

export default function PlacesPage() {
  const queryClient = useQueryClient();
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["my-businesses"],
    queryFn: () => api.get<{ businesses: Business[] }>("/v1/businesses/mine"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/v1/businesses/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-businesses"] });
      setDeletingId(null);
    },
  });

  const businesses = data?.businesses ?? [];

  return (
    <div className="p-8 max-w-5xl">
      <div className="mb-8 flex items-start justify-between">
        <div>
          <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
            <MapPin className="text-[#C47B2B]" size={28} />
            My Places
          </h1>
          <p className="text-stone-500 text-sm mt-1">
            Manage your business listings on the Hapa map.
          </p>
        </div>
        <Link
          href="/dashboard/places/new"
          className="flex items-center gap-2 font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white px-5 py-2.5 hover:bg-[#E8A84A] transition-colors"
        >
          <Plus size={13} />
          Add Business
        </Link>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-white border border-stone-200 p-6 animate-pulse">
              <div className="h-5 bg-stone-100 rounded w-1/3 mb-3" />
              <div className="h-3 bg-stone-100 rounded w-1/2" />
            </div>
          ))}
        </div>
      ) : businesses.length === 0 ? (
        <div className="border border-dashed border-stone-300 p-16 text-center">
          <MapPin size={32} className="text-stone-300 mx-auto mb-4" />
          <h3 className="font-fraunces text-xl font-semibold text-stone-700 mb-2">
            No businesses yet
          </h3>
          <p className="text-stone-400 text-sm mb-6">
            Register your first business to appear on the Hapa map.
          </p>
          <Link
            href="/dashboard/places/new"
            className="font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white px-6 py-3 hover:bg-[#E8A84A] transition-colors inline-flex items-center gap-2"
          >
            <Plus size={13} />
            Register Business
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          {businesses.map((biz) => (
            <BusinessCard
              key={biz.id}
              biz={biz}
              isDeleting={deletingId === biz.id}
              onDelete={() => {
                setDeletingId(biz.id);
                deleteMutation.mutate(biz.id);
              }}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function BusinessCard({
  biz,
  isDeleting,
  onDelete,
}: {
  biz: Business;
  isDeleting: boolean;
  onDelete: () => void;
}) {
  const tier = TIER_BADGE[biz.tier ?? "free"];

  return (
    <div className="bg-white border border-stone-200 p-6">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-4 flex-1 min-w-0">
          {biz.logo_url ? (
            <img
              src={biz.logo_url}
              alt={biz.name}
              className="w-14 h-14 object-cover rounded shrink-0"
            />
          ) : (
            <div className="w-14 h-14 bg-[#C47B2B]/10 flex items-center justify-center shrink-0 rounded">
              <span className="font-fraunces font-black text-[#C47B2B] text-xl">
                {biz.name[0]}
              </span>
            </div>
          )}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h3 className="font-fraunces text-lg font-semibold text-stone-900">{biz.name}</h3>
              <span className={`font-mono text-[10px] uppercase tracking-widest px-2 py-0.5 rounded-sm ${tier.color}`}>
                {tier.label}
              </span>
              {biz.is_verified && (
                <span className="font-mono text-[10px] uppercase tracking-widest px-2 py-0.5 rounded-sm bg-green-50 text-green-600">
                  Verified
                </span>
              )}
            </div>
            <div className="flex items-center gap-1 mt-0.5">
              <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400">
                {CATEGORY_LABELS[biz.category] ?? biz.category}
              </span>
              {biz.city && (
                <>
                  <span className="text-stone-300">·</span>
                  <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400">
                    {biz.city}
                  </span>
                </>
              )}
            </div>

            <p className="text-stone-500 text-sm mt-2 line-clamp-2">{biz.description}</p>

            <div className="flex items-center gap-4 mt-3 flex-wrap">
              {biz.avg_rating != null && (
                <span className="flex items-center gap-1 text-xs text-stone-600">
                  <Star size={11} className="text-[#C47B2B] fill-[#C47B2B]" />
                  {biz.avg_rating.toFixed(1)} ({biz.review_count ?? 0} reviews)
                </span>
              )}
              {biz.phone && (
                <span className="flex items-center gap-1 text-xs text-stone-400">
                  <Phone size={11} />
                  {biz.phone}
                </span>
              )}
              {biz.website && (
                <span className="flex items-center gap-1 text-xs text-stone-400">
                  <Globe size={11} />
                  {biz.website}
                </span>
              )}
              {biz.opening_hours && (
                <span className="flex items-center gap-1 text-xs text-stone-400">
                  <Clock size={11} />
                  {biz.opening_hours}
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <Link
            href={`/dashboard/boost?business=${biz.id}`}
            className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest px-3 py-2 border border-[#C47B2B]/40 text-[#C47B2B] hover:bg-[#C47B2B]/5 transition-colors"
          >
            <Zap size={11} />
            Boost
          </Link>
          <Link
            href={`/dashboard/places/${biz.id}/edit`}
            className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest px-3 py-2 border border-stone-200 text-stone-500 hover:bg-stone-50 transition-colors"
          >
            <Edit2 size={11} />
            Edit
          </Link>
          <button
            onClick={onDelete}
            disabled={isDeleting}
            className="p-2 border border-stone-200 text-stone-400 hover:border-red-300 hover:text-red-500 transition-colors disabled:opacity-40"
          >
            <Trash2 size={13} />
          </button>
          <ChevronRight size={16} className="text-stone-300" />
        </div>
      </div>
    </div>
  );
}
