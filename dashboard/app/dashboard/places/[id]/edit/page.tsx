"use client";
import { useState, useEffect, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import {
  api, endpoints, type Business, type MenuItem,
  type BusinessReview, type BusinessAnalytics,
} from "@/lib/api";
import {
  MapPin, ChevronLeft, Star, Check, Plus, Trash2, Edit2,
  Instagram, Facebook, Globe, Youtube, Twitter, ShieldCheck,
  AlertTriangle, Image, UtensilsCrossed, MessageSquare, Settings,
  Clock, BarChart2,
} from "lucide-react";
import Link from "next/link";

// ── Constants ─────────────────────────────────────────────────────────────────

const CATEGORIES = [
  { value: "food_dining", label: "Food & Dining" },
  { value: "accommodation", label: "Hotel & Stay" },
  { value: "transport", label: "Transport" },
  { value: "health_wellness", label: "Health & Wellness" },
  { value: "beauty_grooming", label: "Beauty & Grooming" },
  { value: "retail", label: "Retail & Shopping" },
  { value: "entertainment", label: "Entertainment" },
  { value: "professional_services", label: "Professional Services" },
  { value: "education", label: "Education" },
  { value: "events_venues", label: "Events & Venues" },
  { value: "arts_culture", label: "Arts & Culture" },
  { value: "faith_community", label: "Faith & Community" },
  { value: "technology", label: "Technology" },
  { value: "agriculture_markets", label: "Markets" },
  { value: "other", label: "Other" },
] as const;

const AMENITIES = [
  "Wi-Fi", "Parking", "Air Conditioning",
  "Outdoor Seating", "Delivery", "Takeaway",
  "Reservations", "Mobile Money", "Card Payments",
  "Pet Friendly", "Wheelchair Access", "Live Music",
  "Rooftop", "Generator Backup", "Kids Area",
];

const DAYS = [
  { key: "mon", label: "Monday" },
  { key: "tue", label: "Tuesday" },
  { key: "wed", label: "Wednesday" },
  { key: "thu", label: "Thursday" },
  { key: "fri", label: "Friday" },
  { key: "sat", label: "Saturday" },
  { key: "sun", label: "Sunday" },
] as const;

const TIME_OPTIONS = Array.from({ length: 48 }, (_, i) => {
  const h = String(Math.floor(i / 2)).padStart(2, "0");
  const m = i % 2 === 0 ? "00" : "30";
  return `${h}:${m}`;
});

const DEFAULT_HOURS: OpeningHoursData = {
  mon: { open: "08:00", close: "22:00", closed: false },
  tue: { open: "08:00", close: "22:00", closed: false },
  wed: { open: "08:00", close: "22:00", closed: false },
  thu: { open: "08:00", close: "22:00", closed: false },
  fri: { open: "08:00", close: "22:00", closed: false },
  sat: { open: "09:00", close: "18:00", closed: false },
  sun: { open: "10:00", close: "16:00", closed: true },
};

const PRICE_TIERS = [
  { value: 1, label: "UGX", desc: "Budget" },
  { value: 2, label: "UGX UGX", desc: "Moderate" },
  { value: 3, label: "UGX UGX UGX", desc: "Upscale" },
  { value: 4, label: "Premium", desc: "Luxury" },
];

const TABS = [
  { key: "profile", label: "Profile", icon: BarChart2 },
  { key: "location", label: "Location & Contact", icon: MapPin },
  { key: "hours", label: "Hours & Amenities", icon: Clock },
  { key: "gallery", label: "Gallery", icon: Image },
  { key: "menu", label: "Menu", icon: UtensilsCrossed },
  { key: "reviews", label: "Reviews", icon: MessageSquare },
  { key: "settings", label: "Settings", icon: Settings },
] as const;

type TabKey = typeof TABS[number]["key"];
type DaySchedule = { open: string; close: string; closed: boolean };
type OpeningHoursData = Record<string, DaySchedule>;

// ── Shared UI helpers ─────────────────────────────────────────────────────────

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

const INPUT = "border border-stone-200 px-3 py-2 text-sm w-full focus:outline-none focus:border-[#C47B2B]";

function Toast({ msg, type }: { msg: string; type: "success" | "error" }) {
  return (
    <div className={`fixed bottom-6 right-6 px-4 py-3 text-sm font-mono z-50 shadow-lg transition-all ${
      type === "success" ? "bg-green-50 border border-green-200 text-green-700" : "bg-red-50 border border-red-200 text-red-600"
    }`}>
      {msg}
    </div>
  );
}

function useToast() {
  const [toast, setToast] = useState<{ msg: string; type: "success" | "error" } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const show = (msg: string, type: "success" | "error" = "success") => {
    if (timer.current) clearTimeout(timer.current);
    setToast({ msg, type });
    timer.current = setTimeout(() => setToast(null), 2500);
  };
  return { toast, show };
}

// ── Opening Hours Picker ──────────────────────────────────────────────────────

function OpeningHoursPicker({ hours, onChange }: { hours: OpeningHoursData; onChange: (h: OpeningHoursData) => void }) {
  const update = (day: string, patch: Partial<DaySchedule>) =>
    onChange({ ...hours, [day]: { ...hours[day], ...patch } });

  return (
    <div className="border border-stone-200 divide-y divide-stone-100 overflow-hidden">
      {DAYS.map(({ key, label }) => {
        const s = hours[key] ?? { open: "08:00", close: "22:00", closed: false };
        return (
          <div key={key} className={`flex items-center gap-3 px-4 py-3 transition-colors ${s.closed ? "bg-stone-50" : "bg-white"}`}>
            <button
              type="button"
              onClick={() => update(key, { closed: !s.closed })}
              className={`w-5 h-5 rounded border-2 flex items-center justify-center shrink-0 transition-colors ${
                !s.closed ? "bg-[#C47B2B] border-[#C47B2B]" : "border-stone-300 bg-white"
              }`}
            >
              {!s.closed && <Check size={11} className="text-white" />}
            </button>
            <span className={`font-mono text-xs w-24 shrink-0 ${s.closed ? "text-stone-400" : "text-stone-700"}`}>
              {label}
            </span>
            {s.closed ? (
              <span className="font-mono text-xs text-stone-400 italic">Closed</span>
            ) : (
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <select
                  value={s.open}
                  onChange={(e) => update(key, { open: e.target.value })}
                  className="font-mono text-xs border border-stone-200 px-2 py-1.5 bg-white text-stone-700 flex-1 min-w-0 focus:outline-none focus:border-[#C47B2B] cursor-pointer"
                >
                  {TIME_OPTIONS.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
                <span className="font-mono text-[10px] text-stone-400 shrink-0">to</span>
                <select
                  value={s.close}
                  onChange={(e) => update(key, { close: e.target.value })}
                  className="font-mono text-xs border border-stone-200 px-2 py-1.5 bg-white text-stone-700 flex-1 min-w-0 focus:outline-none focus:border-[#C47B2B] cursor-pointer"
                >
                  {TIME_OPTIONS.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────

export default function EditBusinessPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const router = useRouter();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<TabKey>("profile");
  const { toast, show: showToast } = useToast();

  const { data: biz, isLoading } = useQuery({
    queryKey: ["business-owner", id],
    queryFn: () => endpoints.business.getOwner(id),
  });

  const { data: analytics } = useQuery({
    queryKey: ["business-analytics", id],
    queryFn: () => endpoints.business.analytics(id),
  });

  if (isLoading) {
    return (
      <div className="p-8 max-w-4xl">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-stone-100 rounded w-1/3" />
          <div className="h-4 bg-stone-100 rounded w-1/2" />
          <div className="h-64 bg-stone-100 rounded" />
        </div>
      </div>
    );
  }

  if (!biz) {
    return (
      <div className="p-8">
        <p className="text-stone-500 font-mono text-sm">Business not found or access denied.</p>
        <Link href="/dashboard/places" className="text-[#C47B2B] text-sm font-mono underline mt-2 block">Back to Places</Link>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-4xl">
      {toast && <Toast msg={toast.msg} type={toast.type} />}

      {/* Header */}
      <div className="mb-6">
        <Link href="/dashboard/places" className="flex items-center gap-1.5 text-stone-400 hover:text-stone-600 text-sm mb-4 transition-colors">
          <ChevronLeft size={14} />
          Back to My Places
        </Link>
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="font-fraunces text-3xl font-bold text-stone-900">{biz.name}</h1>
            <p className="text-stone-500 text-sm mt-1 font-mono">{biz.category} · {biz.city}</p>
          </div>
          {biz.is_verified && (
            <span className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest bg-green-50 text-green-600 border border-green-200 px-3 py-1.5">
              <ShieldCheck size={12} /> Verified
            </span>
          )}
        </div>
      </div>

      {/* Analytics bar */}
      {analytics && <AnalyticsBar analytics={analytics} />}

      {/* Tab bar */}
      <div className="flex border-b border-stone-200 mb-6 overflow-x-auto">
        {TABS.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setActiveTab(key)}
            className={`flex items-center gap-1.5 px-4 py-3 font-mono text-[11px] uppercase tracking-widest whitespace-nowrap transition-colors ${
              activeTab === key
                ? "border-b-2 border-[#C47B2B] text-[#C47B2B] -mb-px"
                : "text-stone-500 hover:text-stone-700"
            }`}
          >
            <Icon size={12} />
            {label}
          </button>
        ))}
      </div>

      {/* Tab panels */}
      <div>
        {activeTab === "profile" && (
          <ProfileTab biz={biz} id={id} queryClient={queryClient} showToast={showToast} />
        )}
        {activeTab === "location" && (
          <LocationTab biz={biz} id={id} queryClient={queryClient} showToast={showToast} />
        )}
        {activeTab === "hours" && (
          <HoursTab biz={biz} id={id} queryClient={queryClient} showToast={showToast} />
        )}
        {activeTab === "gallery" && (
          <GalleryTab biz={biz} id={id} queryClient={queryClient} showToast={showToast} />
        )}
        {activeTab === "menu" && (
          <MenuTab id={id} showToast={showToast} />
        )}
        {activeTab === "reviews" && (
          <ReviewsTab id={id} showToast={showToast} />
        )}
        {activeTab === "settings" && (
          <SettingsTab biz={biz} analytics={analytics} id={id} queryClient={queryClient} showToast={showToast} router={router} />
        )}
      </div>
    </div>
  );
}

// ── Analytics Bar ─────────────────────────────────────────────────────────────

function AnalyticsBar({ analytics }: { analytics: BusinessAnalytics }) {
  return (
    <div className="flex items-center gap-6 border border-stone-200 bg-stone-50 px-5 py-3 mb-6 overflow-x-auto">
      <Stat icon={<Star size={13} className="text-[#C47B2B] fill-[#C47B2B]" />} label={analytics.rating_avg > 0 ? analytics.rating_avg.toFixed(1) : "—"} sub="Rating" />
      <Sep />
      <Stat icon={<MessageSquare size={13} className="text-stone-400" />} label={String(analytics.total_reviews)} sub="Reviews" />
      <Sep />
      <Stat icon={<UtensilsCrossed size={13} className="text-stone-400" />} label={String(analytics.total_menu_items)} sub="Menu Items" />
      <Sep />
      <Stat icon={<Clock size={13} className="text-stone-400" />} label={`${analytics.days_listed}d`} sub="Listed" />
      <Sep />
      <span className="font-mono text-[10px] uppercase tracking-widest px-2 py-1 bg-stone-200 text-stone-500">FREE</span>
    </div>
  );
}

function Stat({ icon, label, sub }: { icon: React.ReactNode; label: string; sub: string }) {
  return (
    <div className="flex items-center gap-2 shrink-0">
      {icon}
      <div>
        <span className="font-mono text-sm font-bold text-stone-900">{label}</span>
        <span className="font-mono text-[10px] text-stone-400 ml-1">{sub}</span>
      </div>
    </div>
  );
}

function Sep() {
  return <div className="h-4 w-px bg-stone-200 shrink-0" />;
}

// ── Tab: Profile ──────────────────────────────────────────────────────────────

function ProfileTab({ biz, id, queryClient, showToast }: TabProps) {
  const [name, setName] = useState(biz.name);
  const [description, setDescription] = useState(biz.description ?? "");
  const [category, setCategory] = useState(biz.category);
  const [subCategory, setSubCategory] = useState(biz.sub_category ?? "");
  const [priceRange, setPriceRange] = useState(biz.price_range ?? 1);

  useEffect(() => {
    setName(biz.name);
    setDescription(biz.description ?? "");
    setCategory(biz.category);
    setSubCategory(biz.sub_category ?? "");
    setPriceRange(biz.price_range ?? 1);
  }, [biz]);

  const mutation = useMutation({
    mutationFn: () => endpoints.business.update(id, { name, description, category, sub_category: subCategory, price_range: priceRange }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["business-owner", id] }); showToast("Saved successfully"); },
    onError: () => showToast("Failed to save. Please try again.", "error"),
  });

  return (
    <div className="space-y-6 bg-white border border-stone-200 p-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">Profile</h2>

      <Field label="Business Name *">
        <input type="text" value={name} onChange={e => setName(e.target.value)} maxLength={120} className={INPUT} />
      </Field>

      <Field label="Description">
        <textarea
          value={description}
          onChange={e => setDescription(e.target.value)}
          maxLength={300}
          rows={4}
          className={`${INPUT} resize-none`}
          placeholder="What makes your place special?"
        />
        <span className="font-mono text-[10px] text-stone-400 mt-1 block text-right">{description.length}/300</span>
      </Field>

      <Field label="Category *">
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
          {CATEGORIES.map((c) => (
            <button
              key={c.value}
              type="button"
              onClick={() => setCategory(c.value)}
              className={`px-3 py-2.5 border text-xs text-left transition-colors ${
                category === c.value
                  ? "border-[#C47B2B] bg-[#C47B2B]/5 text-[#C47B2B]"
                  : "border-stone-200 text-stone-600 hover:border-[#C47B2B]/40"
              }`}
            >
              {c.label}
            </button>
          ))}
        </div>
      </Field>

      <Field label="Sub-category (optional)">
        <input type="text" value={subCategory} onChange={e => setSubCategory(e.target.value)} maxLength={60} placeholder="e.g. Rooftop bar, Tailoring" className={INPUT} />
      </Field>

      <Field label="Price Range">
        <div className="flex gap-3">
          {PRICE_TIERS.map(({ value, label, desc }) => (
            <button
              key={value}
              type="button"
              onClick={() => setPriceRange(value)}
              className={`flex-1 py-3 text-center border transition-colors ${
                priceRange === value
                  ? "border-[#C47B2B] bg-[#C47B2B]/5 text-[#C47B2B]"
                  : "border-stone-200 text-stone-500 hover:border-[#C47B2B]/40"
              }`}
            >
              <div className="font-mono text-xs font-bold leading-tight">{label}</div>
              <div className="font-mono text-[9px] uppercase tracking-wider mt-0.5 opacity-70">{desc}</div>
            </button>
          ))}
        </div>
      </Field>

      <SaveButton loading={mutation.isPending} onClick={() => mutation.mutate()} />
    </div>
  );
}

// ── Tab: Location & Contact ───────────────────────────────────────────────────

function LocationTab({ biz, id, queryClient, showToast }: TabProps) {
  const [address, setAddress] = useState(biz.address ?? "");
  const [neighbourhood, setNeighbourhood] = useState(biz.neighbourhood ?? "");
  const [phone, setPhone] = useState(biz.phone ?? "");
  const [whatsapp, setWhatsapp] = useState(biz.whatsapp ?? "");
  const [website, setWebsite] = useState(biz.website ?? "");
  const [social, setSocial] = useState<Record<string, string>>(biz.social_links ?? {});

  useEffect(() => {
    setAddress(biz.address ?? "");
    setNeighbourhood(biz.neighbourhood ?? "");
    setPhone(biz.phone ?? "");
    setWhatsapp(biz.whatsapp ?? "");
    setWebsite(biz.website ?? "");
    setSocial(biz.social_links ?? {});
  }, [biz]);

  const setSocialField = (key: string, val: string) => setSocial(s => ({ ...s, [key]: val }));

  const mutation = useMutation({
    mutationFn: () => endpoints.business.update(id, { address, neighbourhood, phone, whatsapp, website, social_links: social }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["business-owner", id] }); showToast("Saved successfully"); },
    onError: () => showToast("Failed to save. Please try again.", "error"),
  });

  const socialFields = [
    { key: "instagram", label: "Instagram", icon: Instagram, placeholder: "https://instagram.com/yourbusiness" },
    { key: "facebook", label: "Facebook", icon: Facebook, placeholder: "https://facebook.com/yourbusiness" },
    { key: "tiktok", label: "TikTok", icon: Globe, placeholder: "https://tiktok.com/@yourbusiness" },
    { key: "twitter", label: "X / Twitter", icon: Twitter, placeholder: "https://x.com/yourbusiness" },
    { key: "youtube", label: "YouTube", icon: Youtube, placeholder: "https://youtube.com/@yourbusiness" },
  ];

  return (
    <div className="space-y-6 bg-white border border-stone-200 p-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">Location & Contact</h2>

      <Field label="Address">
        <input type="text" value={address} onChange={e => setAddress(e.target.value)} className={INPUT} placeholder="Plot 15, Kampala Road" />
      </Field>

      <Field label="Neighbourhood">
        <input type="text" value={neighbourhood} onChange={e => setNeighbourhood(e.target.value)} className={INPUT} placeholder="e.g. Kololo" />
      </Field>

      <Field label="Phone (+256)">
        <input type="tel" value={phone} onChange={e => setPhone(e.target.value)} className={INPUT} placeholder="+256 700 000 000" />
      </Field>

      <Field label="WhatsApp">
        <input type="tel" value={whatsapp} onChange={e => setWhatsapp(e.target.value)} className={INPUT} placeholder="+256 700 000 000" />
      </Field>

      <Field label="Website (optional)">
        <input type="url" value={website} onChange={e => setWebsite(e.target.value)} className={INPUT} placeholder="https://yourbusiness.com" />
      </Field>

      <div>
        <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400 mb-3">Social Links</p>
        <div className="space-y-3">
          {socialFields.map(({ key, label, icon: Icon, placeholder }) => (
            <div key={key} className="flex items-center gap-2">
              <Icon size={15} className="text-stone-400 shrink-0" />
              <input
                type="url"
                value={social[key] ?? ""}
                onChange={e => setSocialField(key, e.target.value)}
                placeholder={placeholder}
                className={`${INPUT} flex-1`}
              />
            </div>
          ))}
        </div>
      </div>

      <SaveButton loading={mutation.isPending} onClick={() => mutation.mutate()} />
    </div>
  );
}

// ── Tab: Hours & Amenities ────────────────────────────────────────────────────

function HoursTab({ biz, id, queryClient, showToast }: TabProps) {
  const parseHours = (): OpeningHoursData => {
    if (!biz.opening_hours) return DEFAULT_HOURS;
    try {
      if (typeof biz.opening_hours === "string") return { ...DEFAULT_HOURS, ...JSON.parse(biz.opening_hours) };
      return { ...DEFAULT_HOURS, ...(biz.opening_hours as OpeningHoursData) };
    } catch { return DEFAULT_HOURS; }
  };

  const [hours, setHours] = useState<OpeningHoursData>(parseHours());
  const [amenities, setAmenities] = useState<string[]>(biz.amenities ?? []);

  useEffect(() => {
    setHours(parseHours());
    setAmenities(biz.amenities ?? []);
  }, [biz]);

  const toggleAmenity = (a: string) =>
    setAmenities(prev => prev.includes(a) ? prev.filter(x => x !== a) : [...prev, a]);

  const mutation = useMutation({
    mutationFn: () => endpoints.business.update(id, { opening_hours: hours as any, amenities }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["business-owner", id] }); showToast("Saved successfully"); },
    onError: () => showToast("Failed to save. Please try again.", "error"),
  });

  return (
    <div className="space-y-6 bg-white border border-stone-200 p-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">Hours & Amenities</h2>

      <Field label="Opening Hours">
        <OpeningHoursPicker hours={hours} onChange={setHours} />
      </Field>

      <Field label="Amenities">
        <div className="grid grid-cols-3 gap-2">
          {AMENITIES.map(a => (
            <label key={a} className="flex items-center gap-2 cursor-pointer group">
              <div
                onClick={() => toggleAmenity(a)}
                className={`w-4 h-4 border-2 flex items-center justify-center shrink-0 transition-colors cursor-pointer ${
                  amenities.includes(a) ? "bg-[#C47B2B] border-[#C47B2B]" : "border-stone-300"
                }`}
              >
                {amenities.includes(a) && <Check size={10} className="text-white" />}
              </div>
              <span className="text-xs text-stone-600 group-hover:text-stone-900 transition-colors">{a}</span>
            </label>
          ))}
        </div>
      </Field>

      <SaveButton loading={mutation.isPending} onClick={() => mutation.mutate()} />
    </div>
  );
}

// ── Tab: Gallery ──────────────────────────────────────────────────────────────

function GalleryTab({ biz, id, queryClient, showToast }: TabProps) {
  const [coverUrl, setCoverUrl] = useState(biz.cover_url ?? "");
  const [gallery, setGallery] = useState<string[]>(biz.gallery_urls ?? []);

  useEffect(() => {
    setCoverUrl(biz.cover_url ?? "");
    setGallery(biz.gallery_urls ?? []);
  }, [biz]);

  const addPhoto = () => { if (gallery.length < 10) setGallery(g => [...g, ""]); };
  const removePhoto = (i: number) => setGallery(g => g.filter((_, j) => j !== i));
  const updatePhoto = (i: number, val: string) => setGallery(g => g.map((v, j) => j === i ? val : v));

  const mutation = useMutation({
    mutationFn: () => endpoints.business.update(id, { cover_url: coverUrl, gallery_urls: gallery.filter(Boolean) }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["business-owner", id] }); showToast("Saved successfully"); },
    onError: () => showToast("Failed to save. Please try again.", "error"),
  });

  return (
    <div className="space-y-6 bg-white border border-stone-200 p-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">Gallery</h2>

      <Field label="Cover Photo URL">
        <input type="url" value={coverUrl} onChange={e => setCoverUrl(e.target.value)} className={INPUT} placeholder="https://example.com/cover.jpg" />
        {coverUrl && (
          <div className="mt-3 w-32 h-20 border border-stone-200 overflow-hidden">
            <img src={coverUrl} alt="Cover preview" className="w-full h-full object-cover" onError={e => (e.currentTarget.style.display = "none")} />
          </div>
        )}
      </Field>

      <Field label={`Gallery Photos (${gallery.length}/10)`}>
        <div className="space-y-3">
          {gallery.map((url, i) => (
            <div key={i} className="flex items-center gap-2">
              <input
                type="url"
                value={url}
                onChange={e => updatePhoto(i, e.target.value)}
                className={`${INPUT} flex-1`}
                placeholder="https://example.com/photo.jpg"
              />
              {url && (
                <div className="w-10 h-10 border border-stone-200 overflow-hidden shrink-0">
                  <img src={url} alt="" className="w-full h-full object-cover" onError={e => (e.currentTarget.style.display = "none")} />
                </div>
              )}
              <button onClick={() => removePhoto(i)} className="p-2 text-stone-400 hover:text-red-500 transition-colors shrink-0">
                <Trash2 size={14} />
              </button>
            </div>
          ))}
        </div>

        {gallery.length > 0 && gallery.some(Boolean) && (
          <div className="grid grid-cols-4 gap-2 mt-4">
            {gallery.filter(Boolean).map((url, i) => (
              <div key={i} className="aspect-square border border-stone-200 overflow-hidden">
                <img src={url} alt="" className="w-full h-full object-cover" onError={e => (e.currentTarget.style.display = "none")} />
              </div>
            ))}
          </div>
        )}

        {gallery.length < 10 && (
          <button onClick={addPhoto} className="mt-3 flex items-center gap-2 font-mono text-[11px] uppercase tracking-widest text-[#C47B2B] border border-[#C47B2B]/30 px-4 py-2 hover:bg-[#C47B2B]/5 transition-colors">
            <Plus size={12} /> Add Photo
          </button>
        )}
      </Field>

      <SaveButton loading={mutation.isPending} onClick={() => mutation.mutate()} />
    </div>
  );
}

// ── Tab: Menu ─────────────────────────────────────────────────────────────────

function MenuTab({ id, showToast }: { id: string; showToast: ShowToast }) {
  const queryClient = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [editingItem, setEditingItem] = useState<MenuItem | null>(null);
  const emptyForm = { category: "Other", name: "", description: "", price: 0, currency: "UGX", is_available: true, image_url: "", sort_order: 0 };
  const [form, setForm] = useState(emptyForm);

  const { data, isLoading } = useQuery({
    queryKey: ["menu", id],
    queryFn: () => endpoints.business.getMenu(id),
  });

  const items = data?.items ?? [];

  const createMutation = useMutation({
    mutationFn: () => endpoints.business.createMenuItem(id, form),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["menu", id] }); setShowForm(false); setForm(emptyForm); showToast("Item added"); },
    onError: () => showToast("Failed to add item", "error"),
  });

  const updateMutation = useMutation({
    mutationFn: () => endpoints.business.updateMenuItem(id, editingItem!.id, form),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["menu", id] }); setEditingItem(null); showToast("Item updated"); },
    onError: () => showToast("Failed to update item", "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: (itemId: string) => endpoints.business.deleteMenuItem(id, itemId),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["menu", id] }); showToast("Item deleted"); },
    onError: () => showToast("Failed to delete item", "error"),
  });

  const openEdit = (item: MenuItem) => {
    setEditingItem(item);
    setForm({ category: item.category, name: item.name, description: item.description ?? "", price: item.price, currency: item.currency, is_available: item.is_available, image_url: item.image_url ?? "", sort_order: item.sort_order });
    setShowForm(false);
  };

  // Group by category
  const grouped = items.reduce<Record<string, MenuItem[]>>((acc, item) => {
    if (!acc[item.category]) acc[item.category] = [];
    acc[item.category].push(item);
    return acc;
  }, {});

  return (
    <div className="space-y-4">
      <div className="bg-white border border-stone-200 p-6">
        <div className="flex items-center justify-between mb-4 border-b border-stone-100 pb-3">
          <h2 className="font-fraunces text-lg font-semibold">Menu / Services</h2>
          <button
            onClick={() => { setShowForm(s => !s); setEditingItem(null); setForm(emptyForm); }}
            className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white px-4 py-2 hover:bg-[#E8A84A] transition-colors"
          >
            <Plus size={11} /> Add Item
          </button>
        </div>

        {(showForm || editingItem) && (
          <MenuItemForm
            form={form}
            setForm={setForm}
            loading={createMutation.isPending || updateMutation.isPending}
            onSave={() => editingItem ? updateMutation.mutate() : createMutation.mutate()}
            onCancel={() => { setShowForm(false); setEditingItem(null); setForm(emptyForm); }}
            isEdit={!!editingItem}
          />
        )}

        {isLoading ? (
          <div className="animate-pulse space-y-3 mt-4">
            {[1, 2, 3].map(i => <div key={i} className="h-16 bg-stone-100 rounded" />)}
          </div>
        ) : items.length === 0 ? (
          <div className="text-center py-12 border border-dashed border-stone-200">
            <UtensilsCrossed size={28} className="text-stone-300 mx-auto mb-3" />
            <p className="font-fraunces text-stone-600 font-semibold">No menu items yet</p>
            <p className="text-stone-400 text-sm mt-1">Add your first dish or service.</p>
          </div>
        ) : (
          <div className="space-y-6 mt-4">
            {Object.entries(grouped).map(([cat, catItems]) => (
              <div key={cat}>
                <p className="font-mono text-[10px] uppercase tracking-widest text-stone-400 mb-2">{cat}</p>
                <div className="space-y-2">
                  {catItems.map(item => (
                    <div key={item.id} className="flex items-start justify-between gap-4 border border-stone-100 px-4 py-3 hover:border-stone-200 transition-colors">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-stone-900 text-sm">{item.name}</span>
                          {!item.is_available && (
                            <span className="font-mono text-[9px] uppercase tracking-widest bg-stone-100 text-stone-400 px-1.5 py-0.5">Unavailable</span>
                          )}
                        </div>
                        {item.description && <p className="text-stone-500 text-xs mt-0.5 line-clamp-1">{item.description}</p>}
                        <p className="font-mono text-xs text-[#C47B2B] font-bold mt-1">{item.currency} {item.price.toLocaleString()}</p>
                      </div>
                      <div className="flex items-center gap-1 shrink-0">
                        <button onClick={() => openEdit(item)} className="p-1.5 text-stone-400 hover:text-[#C47B2B] transition-colors">
                          <Edit2 size={13} />
                        </button>
                        <button onClick={() => deleteMutation.mutate(item.id)} disabled={deleteMutation.isPending} className="p-1.5 text-stone-400 hover:text-red-500 transition-colors">
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function MenuItemForm({ form, setForm, loading, onSave, onCancel, isEdit }: {
  form: any; setForm: any; loading: boolean;
  onSave: () => void; onCancel: () => void; isEdit: boolean;
}) {
  const set = (key: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    setForm((f: any) => ({ ...f, [key]: e.target.value }));

  return (
    <div className="border border-[#C47B2B]/20 bg-[#C47B2B]/5 p-4 mb-4 space-y-3">
      <p className="font-mono text-[10px] uppercase tracking-widest text-[#C47B2B]">{isEdit ? "Edit Item" : "New Item"}</p>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Category">
          <input type="text" value={form.category} onChange={set("category")} className={INPUT} placeholder="e.g. Main Course" />
        </Field>
        <Field label="Name *">
          <input type="text" value={form.name} onChange={set("name")} className={INPUT} placeholder="e.g. Rolex" />
        </Field>
        <Field label="Price *">
          <input type="number" value={form.price} onChange={e => setForm((f: any) => ({ ...f, price: parseFloat(e.target.value) || 0 }))} className={INPUT} min={0} />
        </Field>
        <Field label="Currency">
          <input type="text" value={form.currency} onChange={set("currency")} className={INPUT} placeholder="UGX" maxLength={10} />
        </Field>
      </div>
      <Field label="Description (optional)">
        <textarea value={form.description} onChange={set("description")} className={`${INPUT} resize-none`} rows={2} maxLength={300} />
      </Field>
      <label className="flex items-center gap-2 cursor-pointer">
        <input type="checkbox" checked={form.is_available} onChange={e => setForm((f: any) => ({ ...f, is_available: e.target.checked }))} className="accent-[#C47B2B]" />
        <span className="font-mono text-xs text-stone-600">Available</span>
      </label>
      <div className="flex gap-2 pt-1">
        <button onClick={onSave} disabled={loading || !form.name} className="font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white px-4 py-2 hover:bg-[#E8A84A] transition-colors disabled:opacity-40">
          {loading ? "Saving…" : isEdit ? "Update" : "Add Item"}
        </button>
        <button onClick={onCancel} className="font-mono text-[10px] uppercase tracking-widest border border-stone-200 text-stone-500 px-4 py-2 hover:bg-stone-50 transition-colors">
          Cancel
        </button>
      </div>
    </div>
  );
}

// ── Tab: Reviews ──────────────────────────────────────────────────────────────

function ReviewsTab({ id, showToast }: { id: string; showToast: ShowToast }) {
  const { data, isLoading } = useQuery({
    queryKey: ["reviews", id],
    queryFn: () => endpoints.business.reviews(id, 1),
  });

  const reviews = data?.reviews ?? [];

  return (
    <div className="bg-white border border-stone-200 p-6">
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3 mb-4">Reviews</h2>

      {isLoading ? (
        <div className="animate-pulse space-y-4">
          {[1, 2].map(i => <div key={i} className="h-24 bg-stone-100 rounded" />)}
        </div>
      ) : reviews.length === 0 ? (
        <div className="text-center py-12 border border-dashed border-stone-200">
          <MessageSquare size={28} className="text-stone-300 mx-auto mb-3" />
          <p className="font-fraunces text-stone-600 font-semibold">No reviews yet</p>
          <p className="text-stone-400 text-sm mt-1">Reviews from the community will appear here.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {reviews.map(review => (
            <ReviewCard key={review.id} review={review} businessId={id} showToast={showToast} />
          ))}
        </div>
      )}
    </div>
  );
}

function ReviewCard({ review, businessId, showToast }: { review: BusinessReview; businessId: string; showToast: ShowToast }) {
  const queryClient = useQueryClient();
  const [replying, setReplying] = useState(false);
  const [replyText, setReplyText] = useState(review.owner_reply?.content ?? "");

  const replyMutation = useMutation({
    mutationFn: () => endpoints.business.replyToReview(businessId, review.id, replyText),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["reviews", businessId] }); setReplying(false); showToast("Reply posted"); },
    onError: () => showToast("Failed to post reply", "error"),
  });

  const initials = review.display_name.split(" ").map(w => w[0]).join("").slice(0, 2).toUpperCase();

  return (
    <div className="border border-stone-100 p-4 hover:border-stone-200 transition-colors">
      <div className="flex items-start gap-3">
        {review.avatar_url ? (
          <img src={review.avatar_url} alt={review.display_name} className="w-9 h-9 rounded-full object-cover shrink-0" />
        ) : (
          <div className="w-9 h-9 rounded-full bg-[#C47B2B]/10 flex items-center justify-center shrink-0">
            <span className="font-mono text-[10px] font-bold text-[#C47B2B]">{initials}</span>
          </div>
        )}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-semibold text-sm text-stone-900">{review.display_name}</span>
            <StarRating rating={review.rating} />
            <span className="font-mono text-[10px] text-stone-400">{new Date(review.created_at).toLocaleDateString()}</span>
          </div>
          <p className="text-stone-600 text-sm mt-1">{review.content}</p>

          {review.owner_reply && !replying && (
            <div className="mt-3 border-l-2 border-[#C47B2B]/30 pl-3 bg-stone-50 py-2 pr-2">
              <p className="font-mono text-[10px] uppercase tracking-widest text-[#C47B2B] mb-1">Owner Reply</p>
              <p className="text-stone-600 text-sm">{review.owner_reply.content}</p>
              <button onClick={() => { setReplying(true); setReplyText(review.owner_reply!.content); }} className="font-mono text-[10px] text-stone-400 hover:text-[#C47B2B] mt-1 transition-colors underline">
                Edit Reply
              </button>
            </div>
          )}

          {replying && (
            <div className="mt-3 space-y-2">
              <textarea
                value={replyText}
                onChange={e => setReplyText(e.target.value)}
                placeholder="Write your reply…"
                rows={3}
                className={`${INPUT} resize-none text-sm`}
              />
              <div className="flex gap-2">
                <button onClick={() => replyMutation.mutate()} disabled={replyMutation.isPending || !replyText.trim()} className="font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white px-4 py-1.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40">
                  {replyMutation.isPending ? "Posting…" : "Post Reply"}
                </button>
                <button onClick={() => setReplying(false)} className="font-mono text-[10px] uppercase tracking-widest border border-stone-200 text-stone-500 px-3 py-1.5 hover:bg-stone-50 transition-colors">
                  Cancel
                </button>
              </div>
            </div>
          )}

          {!review.owner_reply && !replying && (
            <button onClick={() => setReplying(true)} className="mt-2 font-mono text-[10px] uppercase tracking-widest text-stone-400 hover:text-[#C47B2B] transition-colors">
              Reply
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function StarRating({ rating }: { rating: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map(n => (
        <Star key={n} size={11} className={n <= rating ? "text-[#C47B2B] fill-[#C47B2B]" : "text-stone-200"} />
      ))}
    </div>
  );
}

// ── Tab: Settings ─────────────────────────────────────────────────────────────

function SettingsTab({ biz, analytics, id, queryClient, showToast, router }: TabProps & { router: ReturnType<typeof useRouter> }) {
  const [confirmDeactivate, setConfirmDeactivate] = useState(false);

  const verifyMutation = useMutation({
    mutationFn: () => endpoints.business.requestVerification(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["business-owner", id] }); queryClient.invalidateQueries({ queryKey: ["business-analytics", id] }); showToast("Verification requested!"); },
    onError: () => showToast("Failed to request verification", "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => api.delete(`/v1/businesses/${id}`),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["my-businesses"] }); router.push("/dashboard/places"); },
    onError: () => showToast("Failed to deactivate listing", "error"),
  });

  const isVerified = biz.is_verified;
  const verRequested = analytics?.verification_requested || !!biz.verification_requested_at;

  return (
    <div className="space-y-6">
      {/* Verification */}
      <div className="bg-white border border-stone-200 p-6">
        <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3 mb-4">Verification</h2>
        <div className="flex items-start gap-4">
          <div className="w-10 h-10 rounded-full bg-[#C47B2B]/10 flex items-center justify-center shrink-0">
            <ShieldCheck size={18} className="text-[#C47B2B]" />
          </div>
          <div className="flex-1">
            <p className="font-semibold text-stone-900 text-sm">Verified Business Badge</p>
            <p className="text-stone-500 text-sm mt-1">
              Verified businesses appear with a badge on the Hapa map, building trust with potential customers.
              Our team verifies your business location and identity via WhatsApp.
            </p>

            <div className="mt-4">
              {isVerified ? (
                <span className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-widest text-green-600 bg-green-50 border border-green-200 px-3 py-2 w-fit">
                  <Check size={12} /> Verified
                </span>
              ) : verRequested ? (
                <p className="font-mono text-xs text-stone-500 bg-stone-50 border border-stone-200 px-4 py-3">
                  Verification requested — our team will contact you via WhatsApp within 24 hours.
                </p>
              ) : (
                <button
                  onClick={() => verifyMutation.mutate()}
                  disabled={verifyMutation.isPending}
                  className="font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white px-5 py-2.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40"
                >
                  {verifyMutation.isPending ? "Requesting…" : "Request Verification"}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Danger Zone */}
      <div className="bg-white border border-red-200 p-6">
        <h2 className="font-fraunces text-lg font-semibold text-red-600 border-b border-red-100 pb-3 mb-4 flex items-center gap-2">
          <AlertTriangle size={16} /> Danger Zone
        </h2>
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="font-semibold text-stone-900 text-sm">Deactivate Listing</p>
            <p className="text-stone-500 text-sm mt-1">
              Your business will be removed from the Hapa map. This action cannot be undone.
            </p>
          </div>
          {!confirmDeactivate ? (
            <button
              onClick={() => setConfirmDeactivate(true)}
              className="font-mono text-[10px] uppercase tracking-widest border border-red-300 text-red-500 px-4 py-2 hover:bg-red-50 transition-colors shrink-0"
            >
              Deactivate
            </button>
          ) : (
            <div className="flex gap-2 shrink-0">
              <button
                onClick={() => deleteMutation.mutate()}
                disabled={deleteMutation.isPending}
                className="font-mono text-[10px] uppercase tracking-widest bg-red-500 text-white px-4 py-2 hover:bg-red-600 transition-colors disabled:opacity-40"
              >
                {deleteMutation.isPending ? "Deactivating…" : "Yes, Deactivate"}
              </button>
              <button
                onClick={() => setConfirmDeactivate(false)}
                className="font-mono text-[10px] uppercase tracking-widest border border-stone-200 text-stone-500 px-3 py-2 hover:bg-stone-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ── Shared ─────────────────────────────────────────────────────────────────────

type ShowToast = (msg: string, type?: "success" | "error") => void;

interface TabProps {
  biz: Business;
  id: string;
  queryClient: ReturnType<typeof useQueryClient>;
  showToast: ShowToast;
  analytics?: BusinessAnalytics | null;
}

function SaveButton({ loading, onClick }: { loading: boolean; onClick: () => void }) {
  return (
    <div className="pt-2 border-t border-stone-100">
      <button
        onClick={onClick}
        disabled={loading}
        className="font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white px-6 py-2.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
      >
        {loading ? "Saving…" : "Save Changes"}
      </button>
    </div>
  );
}
