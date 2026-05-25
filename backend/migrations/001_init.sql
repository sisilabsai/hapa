-- ============================================================
-- Hapa Platform — Database Schema v1
-- PostgreSQL 16 + PostGIS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- for fuzzy text search

-- ── Enum types ────────────────────────────────────────────────────────────────

CREATE TYPE user_type AS ENUM ('resident', 'new_arrival', 'traveller', 'business_owner');
CREATE TYPE user_tier AS ENUM ('member', 'pro', 'verified_local');
CREATE TYPE privacy_mode AS ENUM ('ghost', 'visible', 'discoverable');

CREATE TYPE post_type AS ENUM (
    'location_post', 'flash', 'review', 'cultural_note',
    'diary', 'community_ask', 'curated_map', 'reel'
);
CREATE TYPE moderation_status AS ENUM ('pending', 'approved', 'rejected', 'flagged');

CREATE TYPE business_category AS ENUM (
    'food_dining', 'accommodation', 'transport', 'health_wellness',
    'beauty_grooming', 'retail', 'entertainment', 'professional_services',
    'education', 'events_venues', 'arts_culture', 'faith_community',
    'technology', 'agriculture_markets', 'other'
);
CREATE TYPE business_tier AS ENUM ('free', 'growth', 'pro');

CREATE TYPE creator_tier AS ENUM ('rising_voice', 'local_voice', 'city_voice');
CREATE TYPE creator_status AS ENUM ('pending', 'approved', 'suspended');

CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'cancelled', 'completed', 'no_show');
CREATE TYPE notification_type AS ENUM (
    'flash_alert', 'city_switch', 'booking_confirmed', 'boost_nearby',
    'been_here', 'new_follower', 'creator_post', 'challenge', 'recommendation'
);
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');


-- ── Users ─────────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone           VARCHAR(20) UNIQUE,
    email           VARCHAR(255) UNIQUE,
    google_id       VARCHAR(128) UNIQUE,
    display_name    VARCHAR(80) NOT NULL DEFAULT '',
    username        VARCHAR(40) UNIQUE,
    avatar_url      TEXT,
    bio             VARCHAR(160),
    user_type       user_type NOT NULL DEFAULT 'resident',
    tier            user_tier NOT NULL DEFAULT 'member',
    privacy_mode    privacy_mode NOT NULL DEFAULT 'discoverable',
    language        VARCHAR(10) NOT NULL DEFAULT 'en',
    current_city    VARCHAR(100),
    home_city       VARCHAR(100),
    cities_lived    TEXT[] DEFAULT '{}',
    interest_tags   TEXT[] DEFAULT '{}',
    trust_score     INTEGER NOT NULL DEFAULT 0,
    is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_users_username ON users(username) WHERE username IS NOT NULL;
CREATE INDEX idx_users_current_city ON users(current_city);
CREATE INDEX idx_users_interest_tags ON users USING GIN(interest_tags);


-- ── OTP Verifications ─────────────────────────────────────────────────────────

CREATE TABLE otp_verifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone       VARCHAR(20) NOT NULL,
    code        VARCHAR(6) NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    used        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_phone ON otp_verifications(phone, expires_at);


-- ── User Location History ─────────────────────────────────────────────────────

CREATE TABLE user_locations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    city            VARCHAR(100),
    neighbourhood   VARCHAR(100),
    accuracy_m      FLOAT,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_locations_user ON user_locations(user_id, recorded_at DESC);
CREATE INDEX idx_user_locations_geo ON user_locations USING GIST(location);
CREATE INDEX idx_user_locations_city ON user_locations(city, recorded_at DESC);

-- Auto-purge location data older than 90 days (run as scheduled job)
-- DELETE FROM user_locations WHERE recorded_at < NOW() - INTERVAL '90 days';


-- ── Social Graph ──────────────────────────────────────────────────────────────

CREATE TABLE user_follows (
    follower_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id)
);

CREATE INDEX idx_user_follows_following ON user_follows(following_id);

CREATE TABLE user_blocks (
    blocker_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);


-- ── Businesses ────────────────────────────────────────────────────────────────

CREATE TABLE businesses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id        UUID NOT NULL REFERENCES users(id),
    name            VARCHAR(120) NOT NULL,
    slug            VARCHAR(140) UNIQUE,
    category        business_category NOT NULL DEFAULT 'other',
    sub_category    VARCHAR(60),
    description     VARCHAR(300),
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    neighbourhood   VARCHAR(100),
    address         TEXT,
    phone           VARCHAR(20),
    whatsapp        VARCHAR(20),
    website         VARCHAR(255),
    cover_url       TEXT,
    gallery_urls    TEXT[] DEFAULT '{}',
    opening_hours   JSONB,   -- { mon: {open:"08:00", close:"22:00"}, ... }
    amenities       TEXT[] DEFAULT '{}',
    price_range     SMALLINT CHECK (price_range BETWEEN 1 AND 4),
    tier            business_tier NOT NULL DEFAULT 'free',
    is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    rating_avg      NUMERIC(3,2) DEFAULT 0,
    review_count    INTEGER NOT NULL DEFAULT 0,
    boost_active    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_businesses_location ON businesses USING GIST(location);
CREATE INDEX idx_businesses_city_category ON businesses(city, category);
CREATE INDEX idx_businesses_owner ON businesses(owner_id);
CREATE INDEX idx_businesses_slug ON businesses(slug);
CREATE INDEX idx_businesses_amenities ON businesses USING GIN(amenities);
CREATE INDEX idx_businesses_rating ON businesses(city, rating_avg DESC) WHERE is_active = TRUE;


-- ── Hapa Boost ────────────────────────────────────────────────────────────────

CREATE TABLE boosts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    title           VARCHAR(120) NOT NULL,
    description     VARCHAR(280),
    offer_text      VARCHAR(120),
    radius_m        INTEGER NOT NULL DEFAULT 1000,  -- target radius in metres
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at         TIMESTAMPTZ NOT NULL,
    budget_usd      NUMERIC(10,2),
    impressions     INTEGER NOT NULL DEFAULT 0,
    clicks          INTEGER NOT NULL DEFAULT 0,
    conversions     INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_boosts_location ON boosts USING GIST(location);
CREATE INDEX idx_boosts_active ON boosts(ends_at) WHERE is_active = TRUE;


-- ── Posts ─────────────────────────────────────────────────────────────────────

CREATE TABLE posts (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_type           post_type NOT NULL,
    content             TEXT,
    media_urls          TEXT[] DEFAULT '{}',
    location            GEOGRAPHY(POINT, 4326) NOT NULL,
    city                VARCHAR(100) NOT NULL,
    neighbourhood       VARCHAR(100),
    business_id         UUID REFERENCES businesses(id) ON DELETE SET NULL,
    interest_tags       TEXT[] DEFAULT '{}',
    expires_at          TIMESTAMPTZ,  -- Flash posts only
    moderation_status   moderation_status NOT NULL DEFAULT 'approved',
    been_here_count     INTEGER NOT NULL DEFAULT 0,
    like_count          INTEGER NOT NULL DEFAULT 0,
    comment_count       INTEGER NOT NULL DEFAULT 0,
    share_count         INTEGER NOT NULL DEFAULT 0,
    pulse_count         INTEGER NOT NULL DEFAULT 0,  -- Hapa Pulse for Flash posts
    is_pinned           BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_posts_location ON posts USING GIST(location);
CREATE INDEX idx_posts_city_created ON posts(city, created_at DESC) WHERE moderation_status = 'approved';
CREATE INDEX idx_posts_user ON posts(user_id, created_at DESC);
CREATE INDEX idx_posts_business ON posts(business_id) WHERE business_id IS NOT NULL;
CREATE INDEX idx_posts_type ON posts(post_type, city, created_at DESC);
CREATE INDEX idx_posts_flash ON posts(expires_at) WHERE post_type = 'flash' AND expires_at IS NOT NULL;
CREATE INDEX idx_posts_tags ON posts USING GIN(interest_tags);
-- Compound index for feed ranking query
CREATE INDEX idx_posts_feed ON posts(city, moderation_status, created_at DESC) INCLUDE (location, interest_tags, been_here_count, like_count);


-- ── Post Interactions ─────────────────────────────────────────────────────────

CREATE TABLE post_likes (
    post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE been_here (
    post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE post_pulses (
    post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE post_saves (
    post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE comments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id         UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content         VARCHAR(500) NOT NULL,
    is_local        BOOLEAN NOT NULL DEFAULT FALSE,   -- user is in same neighbourhood
    is_trusted_local BOOLEAN NOT NULL DEFAULT FALSE,  -- Verified Local badge
    parent_id       UUID REFERENCES comments(id) ON DELETE CASCADE,
    like_count      INTEGER NOT NULL DEFAULT 0,
    moderation_status moderation_status NOT NULL DEFAULT 'approved',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comments_post ON comments(post_id, created_at ASC);
CREATE INDEX idx_comments_user ON comments(user_id);

CREATE TABLE community_upvotes (
    post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);


-- ── Hapa Guide — Cultural Intelligence ───────────────────────────────────────

CREATE TABLE cultural_notes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    city            VARCHAR(100) NOT NULL,
    neighbourhood   VARCHAR(100),
    content         VARCHAR(300) NOT NULL,
    category        VARCHAR(50),  -- 'language', 'etiquette', 'transport', 'food', 'safety', etc.
    language        VARCHAR(10) NOT NULL DEFAULT 'en',
    upvote_count    INTEGER NOT NULL DEFAULT 0,
    is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    moderation_status moderation_status NOT NULL DEFAULT 'pending',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cultural_notes_city ON cultural_notes(city, upvote_count DESC) WHERE moderation_status = 'approved';
CREATE INDEX idx_cultural_notes_neighbourhood ON cultural_notes(neighbourhood, upvote_count DESC);

CREATE TABLE community_asks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id         UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    best_answer_id  UUID,  -- points to comments.id
    resolved        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE curated_maps (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(120) NOT NULL,
    description     VARCHAR(280),
    city            VARCHAR(100) NOT NULL,
    cover_url       TEXT,
    pin_count       INTEGER NOT NULL DEFAULT 0,
    save_count      INTEGER NOT NULL DEFAULT 0,
    sponsor_id      UUID REFERENCES businesses(id) ON DELETE SET NULL,
    is_published    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE curated_map_pins (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    map_id          UUID NOT NULL REFERENCES curated_maps(id) ON DELETE CASCADE,
    business_id     UUID REFERENCES businesses(id) ON DELETE SET NULL,
    title           VARCHAR(120) NOT NULL,
    description     VARCHAR(280),
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    sort_order      SMALLINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_map_pins_map ON curated_map_pins(map_id, sort_order);
CREATE INDEX idx_map_pins_location ON curated_map_pins USING GIST(location);


-- ── Creators ──────────────────────────────────────────────────────────────────

CREATE TABLE creators (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    city            VARCHAR(100) NOT NULL,
    content_focus   VARCHAR(80),
    tier            creator_tier NOT NULL DEFAULT 'rising_voice',
    status          creator_status NOT NULL DEFAULT 'pending',
    bio             VARCHAR(300),
    portfolio_urls  TEXT[] DEFAULT '{}',
    total_reach     INTEGER NOT NULL DEFAULT 0,
    engagement_score NUMERIC(8,2) NOT NULL DEFAULT 0,
    been_here_total INTEGER NOT NULL DEFAULT 0,
    monthly_earnings NUMERIC(10,2) NOT NULL DEFAULT 0,
    creator_fund_eligible BOOLEAN NOT NULL DEFAULT FALSE,
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_creators_city ON creators(city, tier) WHERE status = 'approved';
CREATE INDEX idx_creators_user ON creators(user_id);


-- ── Creator Partnerships ─────────────────────────────────────────────────────

CREATE TABLE creator_partnerships (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id      UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
    business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    title           VARCHAR(120) NOT NULL,
    description     TEXT,
    deal_value_usd  NUMERIC(10,2) NOT NULL,
    platform_fee    NUMERIC(10,2) NOT NULL,  -- 15% of deal_value
    creator_payout  NUMERIC(10,2) NOT NULL,  -- 85% of deal_value
    deliverables    TEXT[] DEFAULT '{}',
    starts_at       TIMESTAMPTZ,
    ends_at         TIMESTAMPTZ,
    status          VARCHAR(30) NOT NULL DEFAULT 'proposed',  -- proposed|accepted|active|completed|cancelled
    attributed_visits INTEGER NOT NULL DEFAULT 0,
    attributed_bookings INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ── Bookings ──────────────────────────────────────────────────────────────────

CREATE TABLE bookings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    business_id     UUID NOT NULL REFERENCES businesses(id),
    post_id         UUID REFERENCES posts(id) ON DELETE SET NULL,  -- attributed source
    creator_id      UUID REFERENCES creators(id) ON DELETE SET NULL,  -- creator attribution
    service_name    VARCHAR(120),
    quantity        SMALLINT NOT NULL DEFAULT 1,
    price_usd       NUMERIC(10,2),
    notes           TEXT,
    booking_date    TIMESTAMPTZ NOT NULL,
    status          booking_status NOT NULL DEFAULT 'pending',
    confirmed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    cancel_reason   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bookings_user ON bookings(user_id, created_at DESC);
CREATE INDEX idx_bookings_business ON bookings(business_id, booking_date DESC);
CREATE INDEX idx_bookings_status ON bookings(status, booking_date);


-- ── Payments ──────────────────────────────────────────────────────────────────

CREATE TABLE payments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id      UUID REFERENCES bookings(id),
    partnership_id  UUID REFERENCES creator_partnerships(id),
    boost_id        UUID REFERENCES boosts(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    amount_usd      NUMERIC(10,2) NOT NULL,
    currency        VARCHAR(10) NOT NULL DEFAULT 'USD',
    provider        VARCHAR(30) NOT NULL,  -- flutterwave|paystack|mpesa|mtn_momo|airtel
    provider_ref    VARCHAR(255),
    status          payment_status NOT NULL DEFAULT 'pending',
    metadata        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_user ON payments(user_id, created_at DESC);
CREATE INDEX idx_payments_provider_ref ON payments(provider_ref) WHERE provider_ref IS NOT NULL;


-- ── Notifications ─────────────────────────────────────────────────────────────

CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            notification_type NOT NULL,
    title           VARCHAR(120) NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB,
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;


-- ── Hapa Circles ──────────────────────────────────────────────────────────────

CREATE TABLE circles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(80) NOT NULL,
    description     VARCHAR(280),
    city            VARCHAR(100) NOT NULL,
    category        VARCHAR(50),
    cover_url       TEXT,
    member_count    INTEGER NOT NULL DEFAULT 0,
    is_public       BOOLEAN NOT NULL DEFAULT TRUE,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_circles_city ON circles(city, member_count DESC);

CREATE TABLE circle_members (
    circle_id   UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (circle_id, user_id)
);


-- ── Reviews ───────────────────────────────────────────────────────────────────
-- Reviews are stored as posts of type 'review' with business_id set.
-- This view joins them for convenience.

CREATE VIEW business_reviews AS
    SELECT
        p.id,
        p.user_id,
        p.business_id,
        p.content,
        p.media_urls,
        p.been_here_count,
        p.like_count,
        p.location AS reviewer_location,
        p.created_at,
        p.moderation_status
    FROM posts p
    WHERE p.post_type = 'review'
      AND p.business_id IS NOT NULL;


-- ── Content Moderation ────────────────────────────────────────────────────────

CREATE TABLE moderation_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id     UUID NOT NULL REFERENCES users(id),
    post_id         UUID REFERENCES posts(id) ON DELETE CASCADE,
    comment_id      UUID REFERENCES comments(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),  -- reported user
    reason          VARCHAR(50) NOT NULL,
    description     TEXT,
    status          VARCHAR(30) NOT NULL DEFAULT 'pending',
    reviewed_by     UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE INDEX idx_reports_status ON moderation_reports(status, created_at);


-- ── Local Reputation Scores ───────────────────────────────────────────────────

CREATE TABLE reputation_scores (
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    city                VARCHAR(100) NOT NULL,
    review_accuracy     INTEGER NOT NULL DEFAULT 0,
    cultural_notes      INTEGER NOT NULL DEFAULT 0,
    community_answers   INTEGER NOT NULL DEFAULT 0,
    content_engagement  INTEGER NOT NULL DEFAULT 0,
    total_score         INTEGER GENERATED ALWAYS AS (
                            review_accuracy + cultural_notes +
                            community_answers + content_engagement
                        ) STORED,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, city)
);

CREATE INDEX idx_reputation_city ON reputation_scores(city, total_score DESC);


-- ── City Challenges ───────────────────────────────────────────────────────────

CREATE TABLE city_challenges (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           VARCHAR(120) NOT NULL,
    description     TEXT NOT NULL,
    city            VARCHAR(100) NOT NULL,
    hashtag         VARCHAR(80),
    cover_url       TEXT,
    creator_id      UUID REFERENCES creators(id) ON DELETE SET NULL,
    starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at         TIMESTAMPTZ NOT NULL,
    submission_count INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_challenges_city ON city_challenges(city, ends_at) WHERE is_active = TRUE;


-- ── Hapa Pro Subscriptions ────────────────────────────────────────────────────

CREATE TABLE subscriptions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    tier            VARCHAR(20) NOT NULL DEFAULT 'pro',
    price_usd       NUMERIC(6,2) NOT NULL,
    currency        VARCHAR(10) NOT NULL DEFAULT 'USD',
    provider        VARCHAR(30) NOT NULL,
    provider_sub_id VARCHAR(255),
    starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at         TIMESTAMPTZ NOT NULL,
    auto_renew      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ── Triggers ─────────────────────────────────────────────────────────────────

-- Update updated_at automatically
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_businesses_updated_at BEFORE UPDATE ON businesses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_posts_updated_at BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_creators_updated_at BEFORE UPDATE ON creators FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- Sync review_count and rating_avg on businesses
CREATE OR REPLACE FUNCTION sync_business_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE businesses
    SET
        review_count = (
            SELECT COUNT(*) FROM posts
            WHERE business_id = COALESCE(NEW.business_id, OLD.business_id)
              AND post_type = 'review'
              AND moderation_status = 'approved'
        )
    WHERE id = COALESCE(NEW.business_id, OLD.business_id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_business_stats
AFTER INSERT OR DELETE OR UPDATE ON posts
FOR EACH ROW
WHEN (NEW.post_type = 'review' OR OLD.post_type = 'review')
EXECUTE FUNCTION sync_business_stats();


-- ── Seed data — Cities ────────────────────────────────────────────────────────

CREATE TABLE cities (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    country         VARCHAR(60) NOT NULL,
    country_code    VARCHAR(3) NOT NULL,
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    timezone        VARCHAR(60) NOT NULL,
    languages       TEXT[] NOT NULL DEFAULT '{"en"}',
    currency        VARCHAR(10) NOT NULL DEFAULT 'USD',
    is_launched     BOOLEAN NOT NULL DEFAULT FALSE,
    population      INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cities_launched ON cities(is_launched);
CREATE INDEX idx_cities_location ON cities USING GIST(location);

INSERT INTO cities (name, country, country_code, location, timezone, languages, currency, is_launched) VALUES
    ('Kampala', 'Uganda', 'UGA', ST_Point(32.5825, 0.3476)::geography, 'Africa/Kampala', '{"en","lg"}', 'UGX', TRUE),
    ('Nairobi', 'Kenya', 'KEN', ST_Point(36.8219, -1.2921)::geography, 'Africa/Nairobi', '{"en","sw"}', 'KES', FALSE),
    ('Dar es Salaam', 'Tanzania', 'TZA', ST_Point(39.2083, -6.7924)::geography, 'Africa/Dar_es_Salaam', '{"en","sw"}', 'TZS', FALSE),
    ('Kigali', 'Rwanda', 'RWA', ST_Point(30.0606, -1.9441)::geography, 'Africa/Kigali', '{"en","fr","rw"}', 'RWF', FALSE),
    ('Addis Ababa', 'Ethiopia', 'ETH', ST_Point(38.7578, 9.0248)::geography, 'Africa/Addis_Ababa', '{"am","en"}', 'ETB', FALSE),
    ('Lagos', 'Nigeria', 'NGA', ST_Point(3.3792, 6.5244)::geography, 'Africa/Lagos', '{"en","yo"}', 'NGN', FALSE),
    ('Accra', 'Ghana', 'GHA', ST_Point(-0.1969, 5.6037)::geography, 'Africa/Accra', '{"en","tw"}', 'GHS', FALSE),
    ('Johannesburg', 'South Africa', 'ZAF', ST_Point(28.0473, -26.2041)::geography, 'Africa/Johannesburg', '{"en","zu","af"}', 'ZAR', FALSE),
    ('Cairo', 'Egypt', 'EGY', ST_Point(31.2357, 30.0444)::geography, 'Africa/Cairo', '{"ar","en"}', 'EGP', FALSE),
    ('Casablanca', 'Morocco', 'MAR', ST_Point(-7.5898, 33.5731)::geography, 'Africa/Casablanca', '{"ar","fr"}', 'MAD', FALSE);
