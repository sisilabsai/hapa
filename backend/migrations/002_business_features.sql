-- Migration 002: Business owner customization features

ALTER TABLE businesses ADD COLUMN IF NOT EXISTS social_links JSONB DEFAULT '{}';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS verification_requested_at TIMESTAMPTZ;

ALTER TABLE posts ADD COLUMN IF NOT EXISTS rating SMALLINT CHECK (rating IS NULL OR rating BETWEEN 1 AND 5);

CREATE TABLE IF NOT EXISTS business_menu_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category        VARCHAR(60) NOT NULL DEFAULT 'Other',
    name            VARCHAR(120) NOT NULL,
    description     VARCHAR(300),
    price           NUMERIC(10,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(10) NOT NULL DEFAULT 'UGX',
    is_available    BOOLEAN NOT NULL DEFAULT TRUE,
    image_url       TEXT,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_menu_items_business ON business_menu_items(business_id, sort_order);

CREATE TABLE IF NOT EXISTS business_review_replies (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id         UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (post_id)
);
