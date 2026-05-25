"use client";
import { useState, useCallback, useRef, useEffect } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import {
  MapPin, ChevronLeft, Check, Navigation, Search,
  Loader2, AlertCircle, X, RotateCcw, Globe,
} from "lucide-react";
import Link from "next/link";

// ── Constants ─────────────────────────────────────────────────────────────────

const CATEGORIES = [
  { value: "food_dining", label: "Food & Dining", emoji: "🍽️" },
  { value: "accommodation", label: "Hotel & Stay", emoji: "🏨" },
  { value: "transport", label: "Transport", emoji: "🚗" },
  { value: "health_wellness", label: "Health & Wellness", emoji: "🏥" },
  { value: "beauty_grooming", label: "Beauty & Grooming", emoji: "💇" },
  { value: "retail", label: "Retail & Shopping", emoji: "🛍️" },
  { value: "entertainment", label: "Entertainment", emoji: "🎭" },
  { value: "professional_services", label: "Professional Services", emoji: "⚙️" },
  { value: "education", label: "Education", emoji: "📚" },
  { value: "events_venues", label: "Events & Venues", emoji: "🎪" },
  { value: "arts_culture", label: "Arts & Culture", emoji: "🎨" },
  { value: "faith_community", label: "Faith & Community", emoji: "🕊️" },
  { value: "technology", label: "Technology", emoji: "💻" },
  { value: "agriculture_markets", label: "Markets", emoji: "🌾" },
  { value: "other", label: "Other", emoji: "📍" },
] as const;

const PRICE_TIERS = [
  { value: 1, label: "$", desc: "Budget" },
  { value: 2, label: "$$", desc: "Moderate" },
  { value: 3, label: "$$$", desc: "Upscale" },
  { value: 4, label: "$$$$", desc: "Luxury" },
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

// ── Types ─────────────────────────────────────────────────────────────────────

type CityResult = {
  name: string;
  country: string;
  country_code: string;
  is_launched: boolean;
  lat: number;
  lng: number;
};

type DetectState = "idle" | "detecting" | "found" | "denied" | "error";

type LocationData = {
  city: string;
  country: string;
  lat: number;
  lng: number;
  source: "gps" | "search";
};

type DaySchedule = { open: string; close: string; closed: boolean };
type OpeningHoursData = Record<string, DaySchedule>;

type FormData = {
  name: string;
  category: string;
  description: string;
  address: string;
  neighbourhood: string;
  phone: string;
  website: string;
  whatsapp: string;
  price_tier: number;
  opening_hours: OpeningHoursData;
};

// ── Main page ─────────────────────────────────────────────────────────────────

export default function NewPlacePage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [form, setForm] = useState<FormData>({
    name: "",
    category: "",
    description: "",
    address: "",
    neighbourhood: "",
    phone: "",
    website: "",
    whatsapp: "",
    price_tier: 1,
    opening_hours: DEFAULT_HOURS,
  });
  const [location, setLocation] = useState<LocationData | null>(null);

  // Pre-fill contact details from the user's Hapa profile
  useEffect(() => {
    api.get<{ phone?: string }>("/v1/users/me").then((user) => {
      if (user.phone) {
        setForm((f) => ({
          ...f,
          phone: f.phone || user.phone!,
          whatsapp: f.whatsapp || user.phone!,
        }));
      }
    }).catch(() => {});
  }, []);

  const set = (key: keyof Omit<FormData, "opening_hours">) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
      setForm((f) => ({ ...f, [key]: e.target.value }));

  const buildOpeningHoursPayload = () => {
    const out: Record<string, { open?: string; close?: string; closed?: boolean }> = {};
    for (const [day, s] of Object.entries(form.opening_hours)) {
      out[day] = s.closed ? { closed: true } : { open: s.open, close: s.close };
    }
    return out;
  };

  const mutation = useMutation({
    mutationFn: () =>
      api.post("/v1/businesses", {
        name: form.name,
        category: form.category,
        description: form.description,
        address: form.address,
        neighbourhood: form.neighbourhood,
        city: location?.city ?? "",
        phone: form.phone,
        website: form.website,
        whatsapp: form.whatsapp,
        price_tier: Number(form.price_tier),
        opening_hours: buildOpeningHoursPayload(),
        lat: location?.lat ?? 0,
        lng: location?.lng ?? 0,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-businesses"] });
      router.push("/dashboard/places");
    },
  });

  const step1Valid = form.name && form.category;
  const step2Valid = !!location && !!form.address.trim();

  return (
    <div className="p-8 max-w-2xl">
      {/* Header */}
      <div className="mb-8">
        <Link
          href="/dashboard/places"
          className="flex items-center gap-1.5 text-stone-400 hover:text-stone-600 text-sm mb-4 transition-colors"
        >
          <ChevronLeft size={14} />
          Back to My Places
        </Link>
        <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
          <MapPin className="text-[#C47B2B]" size={28} />
          Register Business
        </h1>
        <p className="text-stone-500 text-sm mt-1">
          Get on the Hapa map. Takes under 5 minutes.
        </p>
      </div>

      {/* Step indicator */}
      <StepIndicator step={step} />

      {/* Step content */}
      <div className="bg-white border border-stone-200 p-6 space-y-5">
        {step === 1 && <Step1 form={form} set={set} setForm={setForm} />}
        {step === 2 && (
          <Step2
            location={location}
            address={form.address}
            neighbourhood={form.neighbourhood}
            onLocationSet={setLocation}
            onAddressChange={(v) => setForm((f) => ({ ...f, address: v }))}
            onNeighbourhoodChange={(v) => setForm((f) => ({ ...f, neighbourhood: v }))}
          />
        )}
        {step === 3 && (
          <Step3
            form={form}
            set={set}
            onHoursChange={(hours) => setForm((f) => ({ ...f, opening_hours: hours }))}
          />
        )}
      </div>

      {/* Navigation */}
      <div className="flex items-center justify-between mt-6">
        {step > 1 ? (
          <button
            onClick={() => setStep((s) => (s - 1) as 1 | 2 | 3)}
            className="font-mono text-xs uppercase tracking-widest border border-stone-200 text-stone-500 px-5 py-2.5 hover:bg-stone-50 transition-colors"
          >
            Back
          </button>
        ) : (
          <div />
        )}

        {step < 3 ? (
          <button
            disabled={step === 1 ? !step1Valid : !step2Valid}
            onClick={() => setStep((s) => (s + 1) as 1 | 2 | 3)}
            className="font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white px-6 py-2.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            Continue
          </button>
        ) : (
          <button
            disabled={mutation.isPending}
            onClick={() => mutation.mutate()}
            className="font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-white px-6 py-2.5 hover:bg-[#E8A84A] transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <MapPin size={13} />
            {mutation.isPending ? "Registering..." : "Register Business"}
          </button>
        )}
      </div>

      {mutation.isError && (
        <p className="text-red-500 text-xs font-mono mt-3 text-center">
          Something went wrong. Please try again.
        </p>
      )}
    </div>
  );
}

// ── Step indicator ────────────────────────────────────────────────────────────

function StepIndicator({ step }: { step: number }) {
  return (
    <div className="flex items-center gap-0 mb-8">
      {[
        { n: 1, label: "Basics" },
        { n: 2, label: "Location" },
        { n: 3, label: "Details" },
      ].map(({ n, label }, i) => (
        <div key={n} className="flex items-center flex-1">
          <div className="flex flex-col items-center">
            <div
              className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold font-mono transition-colors ${
                step > n
                  ? "bg-[#C47B2B] text-white"
                  : step === n
                  ? "bg-[#1A1208] text-[#C47B2B] border-2 border-[#C47B2B]"
                  : "bg-stone-100 text-stone-400"
              }`}
            >
              {step > n ? <Check size={13} /> : n}
            </div>
            <span
              className={`font-mono text-[9px] uppercase tracking-widest mt-1 ${
                step >= n ? "text-stone-700" : "text-stone-400"
              }`}
            >
              {label}
            </span>
          </div>
          {i < 2 && (
            <div
              className={`flex-1 h-px mx-2 mb-4 ${
                step > n ? "bg-[#C47B2B]" : "bg-stone-200"
              }`}
            />
          )}
        </div>
      ))}
    </div>
  );
}

// ── Step 1: Basics ────────────────────────────────────────────────────────────

function Step1({
  form,
  set,
  setForm,
}: {
  form: FormData;
  set: (key: keyof Omit<FormData, "opening_hours">) => (e: any) => void;
  setForm: React.Dispatch<React.SetStateAction<FormData>>;
}) {
  return (
    <>
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">
        Basic Information
      </h2>

      <Field label="Business Name *">
        <input
          type="text"
          value={form.name}
          onChange={set("name")}
          placeholder="e.g. Mama Ashanti Kitchen"
          className="input"
          maxLength={120}
        />
      </Field>

      <Field label="Category *">
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
          {CATEGORIES.map((c) => (
            <button
              key={c.value}
              type="button"
              onClick={() => setForm((f) => ({ ...f, category: c.value }))}
              className={`flex items-center gap-2 px-3 py-2.5 border text-sm text-left transition-colors ${
                form.category === c.value
                  ? "border-[#C47B2B] bg-[#C47B2B]/5 text-[#C47B2B]"
                  : "border-stone-200 text-stone-600 hover:border-[#C47B2B]/40"
              }`}
            >
              <span>{c.emoji}</span>
              <span className="text-xs font-medium">{c.label}</span>
            </button>
          ))}
        </div>
      </Field>

      <Field label="Description">
        <textarea
          value={form.description}
          onChange={set("description")}
          placeholder="What makes your place special? What do you offer?"
          className="input min-h-[100px] resize-none"
          maxLength={500}
        />
        <span className="font-mono text-[10px] text-stone-400 mt-1 block text-right">
          {form.description.length}/500
        </span>
      </Field>

      <Field label="Price Range">
        <div className="flex gap-3">
          {PRICE_TIERS.map(({ value, label, desc }) => (
            <button
              key={value}
              type="button"
              onClick={() => setForm((f) => ({ ...f, price_tier: value }))}
              className={`flex-1 py-3 text-center border transition-colors ${
                form.price_tier === value
                  ? "border-[#C47B2B] bg-[#C47B2B]/5 text-[#C47B2B]"
                  : "border-stone-200 text-stone-500 hover:border-[#C47B2B]/40"
              }`}
            >
              <div className="font-mono text-sm font-bold">{label}</div>
              <div className="font-mono text-[9px] uppercase tracking-wider mt-0.5 opacity-70">
                {desc}
              </div>
            </button>
          ))}
        </div>
      </Field>
    </>
  );
}

// ── Step 2: Location (smart GPS detection) ────────────────────────────────────

function Step2({
  location,
  address,
  neighbourhood,
  onLocationSet,
  onAddressChange,
  onNeighbourhoodChange,
}: {
  location: LocationData | null;
  address: string;
  neighbourhood: string;
  onLocationSet: (loc: LocationData) => void;
  onAddressChange: (v: string) => void;
  onNeighbourhoodChange: (v: string) => void;
}) {
  const [detectState, setDetectState] = useState<DetectState>(
    location ? "found" : "idle"
  );
  const [detectError, setDetectError] = useState<string | null>(null);
  const [showSearch, setShowSearch] = useState(false);

  const detect = useCallback(async () => {
    if (!navigator.geolocation) {
      setDetectState("error");
      setDetectError("Your browser doesn't support GPS.");
      return;
    }

    setDetectState("detecting");
    setDetectError(null);

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const { latitude: lat, longitude: lng } = pos.coords;
          const city = await api.get<CityResult>(
            `/v1/location/city?lat=${lat}&lng=${lng}`
          );
          onLocationSet({
            city: city.name,
            country: city.country,
            lat,
            lng,
            source: "gps",
          });
          setDetectState("found");
        } catch {
          setDetectState("error");
          setDetectError("Could not identify your city. Please search manually.");
        }
      },
      (err) => {
        if (err.code === err.PERMISSION_DENIED) {
          setDetectState("denied");
          setDetectError("Location access was denied. Please search for your city manually.");
        } else {
          setDetectState("error");
          setDetectError("Could not get your location. Try again or search manually.");
        }
      },
      { enableHighAccuracy: false, timeout: 12000, maximumAge: 60000 }
    );
  }, [onLocationSet]);

  const handleCitySelect = useCallback(
    (city: CityResult) => {
      onLocationSet({
        city: city.name,
        country: city.country,
        lat: city.lat,
        lng: city.lng,
        source: "search",
      });
      setDetectState("found");
      setShowSearch(false);
    },
    [onLocationSet]
  );

  return (
    <>
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">
        Location
      </h2>

      {/* ── City detection zone ─────────────────────────────────────── */}
      <div>
        <label className="font-mono text-[10px] uppercase tracking-widest text-stone-400 block mb-3">
          City *
        </label>

        {/* IDLE */}
        {detectState === "idle" && !showSearch && (
          <div className="border-2 border-dashed border-stone-200 p-8 text-center space-y-4">
            <div className="w-12 h-12 rounded-full bg-[#C47B2B]/10 flex items-center justify-center mx-auto">
              <Navigation size={22} className="text-[#C47B2B]" />
            </div>
            <div>
              <p className="font-fraunces font-semibold text-stone-700 text-base">
                Where is your business?
              </p>
              <p className="text-stone-400 text-sm mt-1">
                We'll place you precisely on the Hapa map.
              </p>
            </div>
            <button
              onClick={detect}
              className="w-full flex items-center justify-center gap-2 bg-[#1A1208] text-[#C47B2B] py-3 font-mono text-xs uppercase tracking-widest hover:bg-[#2A1E10] transition-colors"
            >
              <Navigation size={14} />
              Detect my location
            </button>
            <button
              onClick={() => setShowSearch(true)}
              className="w-full flex items-center justify-center gap-2 border border-stone-200 text-stone-500 py-2.5 font-mono text-xs uppercase tracking-widest hover:bg-stone-50 transition-colors"
            >
              <Search size={13} />
              Search for my city
            </button>
          </div>
        )}

        {/* DETECTING */}
        {detectState === "detecting" && (
          <div className="border border-[#C47B2B]/30 bg-[#C47B2B]/5 p-6 flex items-center gap-4">
            <Loader2 size={22} className="text-[#C47B2B] animate-spin shrink-0" />
            <div>
              <p className="font-mono text-xs uppercase tracking-widest text-[#C47B2B]">
                Detecting location…
              </p>
              <p className="text-stone-400 text-xs mt-0.5">
                Please allow location access if prompted.
              </p>
            </div>
          </div>
        )}

        {/* FOUND */}
        {detectState === "found" && location && (
          <div className="border border-[#C47B2B] bg-[#C47B2B]/5 p-5">
            <div className="flex items-start justify-between gap-4">
              <div className="flex items-start gap-3">
                <div className="w-9 h-9 rounded-full bg-[#C47B2B] flex items-center justify-center shrink-0 mt-0.5">
                  <Check size={16} className="text-white" />
                </div>
                <div>
                  <p className="font-mono text-[10px] uppercase tracking-widest text-[#C47B2B] mb-0.5">
                    YOUR BUSINESS IS IN
                  </p>
                  <p className="font-fraunces text-2xl font-black text-[#1A1208] leading-none">
                    {location.city.toUpperCase()}.
                  </p>
                  <p className="text-stone-500 text-xs mt-1 flex items-center gap-1.5">
                    {location.country}
                    <span className="text-stone-300">·</span>
                    {location.source === "gps" ? (
                      <span className="flex items-center gap-1">
                        <Navigation size={10} /> GPS detected
                      </span>
                    ) : (
                      <span className="flex items-center gap-1">
                        <Search size={10} /> Manually selected
                      </span>
                    )}
                  </p>
                </div>
              </div>
              <button
                onClick={() => {
                  setDetectState("idle");
                  setShowSearch(false);
                }}
                className="text-stone-400 hover:text-stone-600 shrink-0"
                title="Change city"
              >
                <X size={16} />
              </button>
            </div>
            <button
              onClick={() => setShowSearch(true)}
              className="mt-4 font-mono text-[10px] uppercase tracking-widest text-stone-400 hover:text-[#C47B2B] underline transition-colors"
            >
              Not {location.city}? Choose a different city
            </button>
          </div>
        )}

        {/* ERROR / DENIED */}
        {(detectState === "error" || detectState === "denied") && (
          <div className="border border-red-200 bg-red-50 p-4 space-y-3">
            <div className="flex items-start gap-3">
              <AlertCircle size={16} className="text-red-400 shrink-0 mt-0.5" />
              <p className="text-red-600 text-sm">{detectError}</p>
            </div>
            <div className="flex gap-2">
              {detectState === "error" && (
                <button
                  onClick={detect}
                  className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest border border-stone-200 text-stone-500 px-3 py-2 hover:bg-stone-50 transition-colors"
                >
                  <RotateCcw size={11} /> Try again
                </button>
              )}
              <button
                onClick={() => {
                  setDetectState("idle");
                  setShowSearch(true);
                }}
                className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B] text-white px-3 py-2 hover:bg-[#E8A84A] transition-colors"
              >
                <Search size={11} /> Search for my city
              </button>
            </div>
          </div>
        )}

        {/* City search panel */}
        {showSearch && detectState !== "found" && (
          <CitySearchPanel onSelect={handleCitySelect} onClose={() => setShowSearch(false)} />
        )}
      </div>

      {/* ── Address fields (shown once city is confirmed) ────────────── */}
      {location && (
        <>
          <Field label="Street Address *">
            <input
              type="text"
              value={address}
              onChange={(e) => onAddressChange(e.target.value)}
              placeholder="e.g. Plot 15, Kampala Road"
              className="input"
              autoFocus
            />
            <p className="font-mono text-[10px] text-stone-400 mt-1.5">
              The street name or plot number customers use to find you.
            </p>
          </Field>

          <Field label="Neighbourhood (optional)">
            <input
              type="text"
              value={neighbourhood}
              onChange={(e) => onNeighbourhoodChange(e.target.value)}
              placeholder={`e.g. Kololo, ${location.city}`}
              className="input"
            />
          </Field>
        </>
      )}
    </>
  );
}

// ── City search panel ─────────────────────────────────────────────────────────

function CitySearchPanel({
  onSelect,
  onClose,
}: {
  onSelect: (city: CityResult) => void;
  onClose: () => void;
}) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<CityResult[]>([]);
  const [loading, setLoading] = useState(false);
  const debounce = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (debounce.current) clearTimeout(debounce.current);
    if (query.trim().length < 2) {
      setResults([]);
      return;
    }
    debounce.current = setTimeout(async () => {
      setLoading(true);
      try {
        const data = await api.get<{ cities: CityResult[] }>(
          `/v1/location/cities?q=${encodeURIComponent(query.trim())}`
        );
        setResults(data.cities ?? []);
      } catch {
        setResults([]);
      } finally {
        setLoading(false);
      }
    }, 280);
    return () => {
      if (debounce.current) clearTimeout(debounce.current);
    };
  }, [query]);

  return (
    <div className="border border-stone-200 mt-3">
      <div className="flex items-center gap-2 border-b border-stone-100 px-3 py-2.5">
        <Search size={14} className="text-stone-400 shrink-0" />
        <input
          autoFocus
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search cities…"
          className="flex-1 text-sm outline-none placeholder-stone-300"
        />
        {loading && <Loader2 size={13} className="text-[#C47B2B] animate-spin shrink-0" />}
        <button onClick={onClose} className="text-stone-300 hover:text-stone-500">
          <X size={14} />
        </button>
      </div>
      {results.length > 0 && (
        <ul className="divide-y divide-stone-50 max-h-56 overflow-y-auto">
          {results.map((city) => (
            <li key={city.name}>
              <button
                onClick={() => onSelect(city)}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-stone-50 text-left transition-colors"
              >
                <div>
                  <p className="text-sm font-medium text-stone-800">{city.name}</p>
                  <p className="text-xs text-stone-400">{city.country}</p>
                </div>
                {city.is_launched && (
                  <span className="font-mono text-[9px] uppercase tracking-widest bg-[#C47B2B]/10 text-[#C47B2B] px-2 py-0.5 font-bold">
                    LIVE
                  </span>
                )}
              </button>
            </li>
          ))}
        </ul>
      )}
      {query.trim().length >= 2 && results.length === 0 && !loading && (
        <p className="text-center text-stone-400 text-sm py-6 font-mono">
          No cities found for "{query}"
        </p>
      )}
      {query.trim().length < 2 && (
        <p className="text-center text-stone-400 text-xs py-4 font-mono">
          Type at least 2 characters to search
        </p>
      )}
    </div>
  );
}

// ── Step 3: Contact & Hours ───────────────────────────────────────────────────

function Step3({
  form,
  set,
  onHoursChange,
}: {
  form: FormData;
  set: (key: keyof Omit<FormData, "opening_hours">) => (e: any) => void;
  onHoursChange: (hours: OpeningHoursData) => void;
}) {
  return (
    <>
      <h2 className="font-fraunces text-lg font-semibold border-b border-stone-100 pb-3">
        Contact & Hours
      </h2>

      <Field label="Phone Number">
        <input
          type="tel"
          value={form.phone}
          onChange={set("phone")}
          placeholder="+256 700 000 000"
          className="input"
        />
        <span className="font-mono text-[10px] text-stone-400 mt-1 block">
          Pre-filled from your Hapa profile — edit if different for this business.
        </span>
      </Field>

      <Field label="WhatsApp Number">
        <input
          type="tel"
          value={form.whatsapp}
          onChange={set("whatsapp")}
          placeholder="+256 700 000 000"
          className="input"
        />
        <span className="font-mono text-[10px] text-stone-400 mt-1 block">
          Customers can message you directly via WhatsApp.
        </span>
      </Field>

      <Field label="Website (optional)">
        <div className="relative">
          <Globe size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-400 pointer-events-none" />
          <input
            type="url"
            value={form.website}
            onChange={set("website")}
            placeholder="https://yourbusiness.com"
            className="input pl-8"
          />
        </div>
        <span className="font-mono text-[10px] text-stone-400 mt-1 block">
          Don't have a website? Hapa is your online presence.
        </span>
      </Field>

      <Field label="Opening Hours">
        <OpeningHoursPicker hours={form.opening_hours} onChange={onHoursChange} />
      </Field>
    </>
  );
}

// ── Opening Hours Picker ──────────────────────────────────────────────────────

function OpeningHoursPicker({
  hours,
  onChange,
}: {
  hours: OpeningHoursData;
  onChange: (h: OpeningHoursData) => void;
}) {
  const update = (day: string, patch: Partial<DaySchedule>) =>
    onChange({ ...hours, [day]: { ...hours[day], ...patch } });

  return (
    <div className="border border-stone-200 divide-y divide-stone-100 overflow-hidden">
      {DAYS.map(({ key, label }) => {
        const s = hours[key];
        return (
          <div
            key={key}
            className={`flex items-center gap-3 px-4 py-3 transition-colors ${
              s.closed ? "bg-stone-50" : "bg-white"
            }`}
          >
            {/* Open/closed checkbox */}
            <button
              type="button"
              onClick={() => update(key, { closed: !s.closed })}
              className={`w-5 h-5 rounded border-2 flex items-center justify-center shrink-0 transition-colors ${
                !s.closed
                  ? "bg-[#C47B2B] border-[#C47B2B]"
                  : "border-stone-300 bg-white"
              }`}
            >
              {!s.closed && <Check size={11} className="text-white" />}
            </button>

            {/* Day label */}
            <span
              className={`font-mono text-xs w-24 shrink-0 ${
                s.closed ? "text-stone-400" : "text-stone-700"
              }`}
            >
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
                  {TIME_OPTIONS.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </select>
                <span className="font-mono text-[10px] text-stone-400 shrink-0">to</span>
                <select
                  value={s.close}
                  onChange={(e) => update(key, { close: e.target.value })}
                  className="font-mono text-xs border border-stone-200 px-2 py-1.5 bg-white text-stone-700 flex-1 min-w-0 focus:outline-none focus:border-[#C47B2B] cursor-pointer"
                >
                  {TIME_OPTIONS.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </select>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Shared ────────────────────────────────────────────────────────────────────

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
