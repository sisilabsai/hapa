const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080";

class ApiClient {
  private token: string | null = null;

  setToken(t: string) {
    this.token = t;
    if (typeof window !== "undefined") localStorage.setItem("hapa_token", t);
  }

  getToken(): string | null {
    if (this.token) return this.token;
    if (typeof window !== "undefined") return localStorage.getItem("hapa_token");
    return null;
  }

  private async req<T>(path: string, opts: RequestInit = {}): Promise<T> {
    const token = this.getToken();
    const res = await fetch(`${BASE}${path}`, {
      ...opts,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...opts.headers,
      },
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error ?? "Request failed");
    }

    return res.json();
  }

  get<T>(path: string) {
    return this.req<T>(path);
  }

  post<T>(path: string, body: unknown) {
    return this.req<T>(path, { method: "POST", body: JSON.stringify(body) });
  }

  put<T>(path: string, body: unknown) {
    return this.req<T>(path, { method: "PUT", body: JSON.stringify(body) });
  }

  patch<T>(path: string, body: unknown) {
    return this.req<T>(path, { method: "PATCH", body: JSON.stringify(body) });
  }

  delete<T>(path: string) {
    return this.req<T>(path, { method: "DELETE" });
  }

  async upload(file: File): Promise<{ url: string; filename: string; mime: string }> {
    const token = this.getToken();
    const form = new FormData();
    form.append("file", file);
    const res = await fetch(`${BASE}/v1/media`, {
      method: "POST",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: form,
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error ?? "Upload failed");
    }
    return res.json();
  }
}

export const api = new ApiClient();

// ── Typed API endpoints ────────────────────────────────────────────────────

export const endpoints = {
  auth: {
    sendOtp: (phone: string) => api.post("/v1/auth/send-otp", { phone }),
    verifyOtp: (phone: string, code: string) => api.post<{ access_token: string; user_id: string; is_new_user: boolean }>("/v1/auth/verify-otp", { phone, code }),
  },
  business: {
    create: (data: CreateBusinessData) => api.post<Business>("/v1/businesses", data),
    mine: () => api.get<{ businesses: Business[] }>("/v1/businesses/mine"),
    get: (id: string) => api.get<Business>(`/v1/places/${id}`),
    getOwner: (id: string) => api.get<Business>(`/v1/businesses/${id}/manage`),
    update: (id: string, data: Partial<Business> & { opening_hours?: Record<string, unknown>; amenities?: string[]; social_links?: Record<string, string>; gallery_urls?: string[] }) =>
      api.put<Business>(`/v1/businesses/${id}`, data),
    analytics: (id: string) => api.get<BusinessAnalytics>(`/v1/businesses/${id}/analytics`),
    reviews: (id: string, page?: number) => api.get<{ reviews: BusinessReview[] }>(`/v1/businesses/${id}/reviews?page=${page ?? 1}`),
    replyToReview: (id: string, reviewId: string, content: string) => api.post(`/v1/businesses/${id}/reviews/${reviewId}/reply`, { content }),
    getMenu: (id: string) => api.get<{ items: MenuItem[] }>(`/v1/businesses/${id}/menu`),
    createMenuItem: (id: string, data: Omit<MenuItem, "id" | "business_id" | "created_at">) => api.post<MenuItem>(`/v1/businesses/${id}/menu`, data),
    updateMenuItem: (id: string, itemId: string, data: Partial<MenuItem>) => api.put<MenuItem>(`/v1/businesses/${id}/menu/${itemId}`, data),
    deleteMenuItem: (id: string, itemId: string) => api.delete(`/v1/businesses/${id}/menu/${itemId}`),
    requestVerification: (id: string) => api.post(`/v1/businesses/${id}/verify`, {}),
    createBoost: (id: string, data: BoostData) => api.post(`/v1/businesses/${id}/boost`, data),
  },
  places: {
    search: (params: PlaceSearchParams) => api.get<{ places: Business[] }>(`/v1/places?${new URLSearchParams(params as any)}`),
    boosts: (lat: number, lng: number) => api.get<{ boosts: Boost[] }>(`/v1/places/boosts?lat=${lat}&lng=${lng}`),
  },
  bookings: {
    list: () => api.get<{ bookings: Booking[] }>("/v1/bookings"),
    confirm: (id: string) => api.post(`/v1/bookings/${id}/confirm`, {}),
  },
  creators: {
    discover: (city: string, focus?: string) => api.get<{ creators: Creator[] }>(`/v1/creators/discover?city=${city}&focus=${focus ?? ""}`),
  },
  ai: {
    boostCopy: (data: { business_name: string; category: string; city: string; hint?: string }) =>
      api.post<{ title: string; offer_text: string; description: string; tips: string[] }>("/v1/ai/boost-copy", data),
    flashCopy: (data: { business_name: string; category: string; city: string; prompt?: string }) =>
      api.post<{ text: string; tip: string }>("/v1/ai/flash-copy", data),
  },
  circles: {
    discover: (city: string) => api.get<{ circles: Circle[] }>(`/v1/circles?city=${encodeURIComponent(city)}&limit=30`),
    mine: () => api.get<{ circles: Circle[] }>("/v1/circles/mine"),
    join: (id: string) => api.post(`/v1/circles/${id}/join`, {}),
    leave: (id: string) => api.delete(`/v1/circles/${id}/join`),
    posts: (id: string) => api.get<{ posts: CirclePost[] }>(`/v1/circles/${id}/posts?limit=20`),
  },
  flash: {
    create: (data: CreateFlashData) => api.post<{ id: string }>("/v1/posts", data),
    active: (businessId: string) =>
      api.get<{ posts: FlashPost[] }>(`/v1/posts/by-user/${businessId}?post_type=flash&active=true`),
  },
};

// ── Types ──────────────────────────────────────────────────────────────────

export interface Business {
  id: string;
  owner_id: string;
  name: string;
  slug: string;
  category: string;
  sub_category?: string;
  description: string;
  address?: string;
  lat: number;
  lng: number;
  city: string;
  neighbourhood?: string;
  phone?: string;
  whatsapp?: string;
  website?: string;
  cover_url?: string;
  logo_url?: string;
  gallery_urls?: string[];
  tier: "free" | "growth" | "pro";
  is_verified: boolean;
  avg_rating?: number;
  rating_avg: number;
  review_count: number;
  price_range: number;
  price_tier?: number;
  opening_hours?: string;
  amenities?: string[];
  social_links?: Record<string, string>;
  boost_active?: boolean;
  verification_requested_at?: string;
  created_at: string;
}

export interface MenuItem {
  id: string;
  business_id: string;
  category: string;
  name: string;
  description?: string;
  price: number;
  currency: string;
  is_available: boolean;
  image_url?: string;
  sort_order: number;
  created_at: string;
}

export interface BusinessReview {
  id: string;
  user_id: string;
  display_name: string;
  avatar_url?: string;
  content: string;
  rating: number;
  like_count: number;
  been_here_count: number;
  created_at: string;
  owner_reply?: { id: string; content: string; created_at: string };
}

export interface BusinessAnalytics {
  total_reviews: number;
  rating_avg: number;
  total_menu_items: number;
  days_listed: number;
  is_verified: boolean;
  verification_requested: boolean;
}

export interface Boost {
  id: string;
  title: string;
  offer_text: string;
  ends_at: string;
  business_name: string;
  category: string;
  cover_url?: string;
  distance_m: number;
}

export interface Booking {
  id: string;
  user_id: string;
  business_id: string;
  service_name?: string;
  quantity: number;
  price_usd?: number;
  booking_date: string;
  status: "pending" | "confirmed" | "cancelled" | "completed";
  created_at: string;
}

export interface Creator {
  id: string;
  user_id: string;
  city: string;
  content_focus: string;
  tier: "rising_voice" | "local_voice" | "city_voice";
  total_reach: number;
  engagement_score: number;
  engagement_rate?: number;
  been_here_total: number;
  monthly_earnings: number;
  display_name: string;
  avatar_url?: string;
  bio?: string;
  follower_count?: number;
  post_count?: number;
  social_links?: {
    instagram?: string;
    youtube?: string;
    twitter?: string;
    tiktok?: string;
  };
}

export interface CreateBusinessData {
  name: string;
  category: string;
  description: string;
  lat: number;
  lng: number;
  phone: string;
  whatsapp?: string;
  cover_url?: string;
}

export interface BoostData {
  title: string;
  description: string;
  offer_text: string;
  radius_m: number;
  duration_hours: number;
  budget_usd: number;
}

export interface Circle {
  id: string;
  name: string;
  description?: string;
  city: string;
  category: string;
  cover_url?: string;
  member_count: number;
  is_public: boolean;
  is_member: boolean;
  created_by: string;
  created_at: string;
}

export interface CirclePost {
  id: string;
  user_id: string;
  display_name: string;
  avatar_url?: string;
  content: string;
  media_urls: string[];
  post_type: string;
  like_count: number;
  comment_count: number;
  is_liked: boolean;
  created_at: string;
}

export interface FlashPost {
  id: string;
  user_id: string;
  post_type: string;
  body: string;
  pulse_count: number;
  expires_at?: string;
  created_at: string;
  business_id?: string;
}

export interface CreateFlashData {
  post_type: "flash";
  content: string;
  business_id?: string;
  lat?: number;
  lng?: number;
  city?: string;
  expires_at?: string;
}

export interface PlaceSearchParams {
  lat: number;
  lng: number;
  radius?: number;
  category?: string;
  q?: string;
}
