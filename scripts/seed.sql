-- ============================================================
-- Hapa Seed Data — Uganda (Kampala focus)
-- Run via: scripts/seed.sh
-- ============================================================

-- ── Users ─────────────────────────────────────────────────────────────────────

INSERT INTO users (id, phone, display_name, username, user_type, tier, privacy_mode, current_city, home_city, bio, interest_tags, trust_score, is_verified)
VALUES
  ('aa000001-0000-0000-0000-000000000001', '+256770100001', 'Amara Nakato',       'amaranakato',    'resident',       'verified_local', 'discoverable', 'Kampala', 'Kampala', 'Kampala born and raised 🇺🇬 | Foodie | Culture lover',                  ARRAY['food','culture','music','art'],          92, TRUE),
  ('aa000001-0000-0000-0000-000000000002', '+256772100002', 'Joseph Ssekandi',    'jssekandi',      'resident',       'member',         'discoverable', 'Kampala', 'Kampala', 'Tech guy | Coffee addict | Kampala nightlife',                          ARRAY['tech','coffee','nightlife','football'],  78, FALSE),
  ('aa000001-0000-0000-0000-000000000003', '+256756100003', 'Grace Apio',         'graceapio',      'new_arrival',    'member',         'discoverable', 'Kampala', 'Gulu',    'From Gulu, finding my feet in Kampala. Ask me about Northern Uganda!',  ARRAY['travel','food','culture','community'],   65, FALSE),
  ('aa000001-0000-0000-0000-000000000004', '+256700100004', 'David Mugisha',      'mugisha_d',      'business_owner', 'pro',            'discoverable', 'Kampala', 'Kampala', 'Entrepreneur | Kampala hustle | Always building something',             ARRAY['business','fitness','networking','tech'], 88, TRUE),
  ('aa000001-0000-0000-0000-000000000005', '+256752100005', 'Fatuma Namusoke',    'fnamusoke',      'resident',       'member',         'discoverable', 'Kampala', 'Kampala', 'Fashionista | Ugandan fabrics | Style is a language',                   ARRAY['fashion','art','culture','beauty'],      74, FALSE),
  ('aa000001-0000-0000-0000-000000000006', '+256777100006', 'Emmanuel Okello',    'emmaokello',     'new_arrival',    'member',         'discoverable', 'Kampala', 'Jinja',   'Jinja boy in Kampala | Source of the Nile pride 🌊',                    ARRAY['football','music','community','travel'], 61, FALSE),
  ('aa000001-0000-0000-0000-000000000007', '+256705100007', 'Sarah Namukasa',     'sarahnamukasa',  'resident',       'verified_local', 'discoverable', 'Kampala', 'Kampala', 'Teacher | Community organiser | Love my city',                          ARRAY['community','education','culture','food'], 95, TRUE),
  ('aa000001-0000-0000-0000-000000000008', '+256780100008', 'Patrick Asiimwe',    'pat_asiimwe',    'new_arrival',    'member',         'discoverable', 'Kampala', 'Mbarara', 'Western Uganda representing 🤝 | Boda driver turned entrepreneur',       ARRAY['business','transport','community','football'], 58, FALSE),
  ('aa000001-0000-0000-0000-000000000009', '+256758100009', 'Lydia Akello',       'lydiaakello',    'resident',       'verified_local', 'discoverable', 'Kampala', 'Kampala', 'Chef | Ugandan recipes | Street food explorer',                         ARRAY['food','cooking','culture','market'],     87, TRUE),
  ('aa000001-0000-0000-0000-000000000010', '+256703100010', 'Moses Ssemwogerere', 'mssemwogerere',  'business_owner', 'verified_local', 'discoverable', 'Kampala', 'Kampala', 'Running the best nyama choma spot in Kampala',                          ARRAY['business','food','community','networking'], 91, TRUE),
  ('aa000001-0000-0000-0000-000000000011', '+256775100011', 'Christine Nabirye',  'christinenabirye','resident',      'member',         'discoverable', 'Kampala', 'Kampala', 'Hair artist | Afro specialist | DM for bookings',                      ARRAY['beauty','fashion','art','community'],    76, FALSE),
  ('aa000001-0000-0000-0000-000000000012', '+256763100012', 'John Kiggundu',      'johnkiggundu',   'resident',       'verified_local', 'discoverable', 'Kampala', 'Kampala', 'Journalist | Telling Kampala stories one post at a time',               ARRAY['culture','politics','community','art'],  89, TRUE),
  ('aa000001-0000-0000-0000-000000000013', '+256756100013', 'Ruth Kyomugisha',    'ruthkyo',        'traveller',      'member',         'discoverable', 'Kampala', 'Kigali',  'East African wanderer 🌍 | Kigali → Kampala → Nairobi',                 ARRAY['travel','food','culture','photography'], 72, FALSE),
  ('aa000001-0000-0000-0000-000000000014', '+256702100014', 'Alex Tumwebaze',     'atumwebaze',     'resident',       'member',         'discoverable', 'Kampala', 'Kampala', 'Fitness coach | Lake Victoria sunsets | Healthy living',                ARRAY['fitness','health','outdoors','food'],    83, FALSE),
  ('aa000001-0000-0000-0000-000000000015', '+256782100015', 'Peace Achola',       'peaceachola',    'resident',       'member',         'discoverable', 'Gulu',    'Gulu',    'Gulu hustle 💪 | Northern culture keeper',                             ARRAY['culture','community','food','music'],   70, FALSE),
  ('aa000001-0000-0000-0000-000000000016', '+256759100016', 'Deo Byarugaba',      'deobyarugaba',   'resident',       'member',         'discoverable', 'Mbarara', 'Mbarara', 'Mbarara milk 🥛 | Ankole culture | Western Uganda represent',           ARRAY['culture','agriculture','community','food'], 68, FALSE),
  ('aa000001-0000-0000-0000-000000000017', '+256706100017', 'Patience Nalubega',  'pnalubega',      'business_owner', 'member',         'discoverable', 'Kampala', 'Kampala', 'Salon owner | Kampala beauty scene | Nails & braids',                   ARRAY['beauty','fashion','business','community'], 80, FALSE),
  ('aa000001-0000-0000-0000-000000000018', '+256771100018', 'Henry Mutumba',      'henrymutumba',   'resident',       'member',         'discoverable', 'Kampala', 'Kampala', 'Fisherman | Lake Victoria vibes | Fresh catch daily',                   ARRAY['outdoors','food','community','fishing'], 73, FALSE),
  ('aa000001-0000-0000-0000-000000000019', '+256753100019', 'Florence Nansubuga', 'florencen',      'resident',       'verified_local', 'discoverable', 'Kampala', 'Kampala', 'Nurse | Community health | Kampala wellness advocate',                  ARRAY['health','community','fitness','culture'], 86, TRUE),
  ('aa000001-0000-0000-0000-000000000020', '+256779100020', 'Isaac Ssennoga',     'issennoga',      'resident',       'member',         'discoverable', 'Jinja',   'Jinja',   'River Nile lover | Jinja adventure guide | Rafting pro',                ARRAY['travel','outdoors','adventure','tourism'], 77, FALSE)
ON CONFLICT (id) DO NOTHING;


-- ── User locations (for nearby discovery) ─────────────────────────────────────
-- Centred near the test user location: 0.3375, 32.6598 (Kireka/Bweyogerere)
-- and central Kampala

INSERT INTO user_locations (user_id, location, city, neighbourhood, accuracy_m, recorded_at)
VALUES
  ('aa000001-0000-0000-0000-000000000001', ST_Point(32.5841, 0.3271)::geography, 'Kampala', 'Kololo',        50, NOW() - INTERVAL '45 minutes'),
  ('aa000001-0000-0000-0000-000000000002', ST_Point(32.6171, 0.3560)::geography, 'Kampala', 'Ntinda',        80, NOW() - INTERVAL '20 minutes'),
  ('aa000001-0000-0000-0000-000000000003', ST_Point(32.6545, 0.3628)::geography, 'Kampala', 'Kyaliwajjala',  60, NOW() - INTERVAL '10 minutes'),
  ('aa000001-0000-0000-0000-000000000004', ST_Point(32.6167, 0.3162)::geography, 'Kampala', 'Bugolobi',      40, NOW() - INTERVAL '1 hour'),
  ('aa000001-0000-0000-0000-000000000005', ST_Point(32.5617, 0.3074)::geography, 'Kampala', 'Mengo',         70, NOW() - INTERVAL '30 minutes'),
  ('aa000001-0000-0000-0000-000000000006', ST_Point(32.6618, 0.3280)::geography, 'Kampala', 'Kireka',        55, NOW() - INTERVAL '15 minutes'),
  ('aa000001-0000-0000-0000-000000000007', ST_Point(32.5903, 0.2780)::geography, 'Kampala', 'Makindye',      45, NOW() - INTERVAL '25 minutes'),
  ('aa000001-0000-0000-0000-000000000008', ST_Point(32.6380, 0.3874)::geography, 'Kampala', 'Naalya',        90, NOW() - INTERVAL '5 minutes'),
  ('aa000001-0000-0000-0000-000000000009', ST_Point(32.5894, 0.2696)::geography, 'Kampala', 'Kabalagala',    50, NOW() - INTERVAL '35 minutes'),
  ('aa000001-0000-0000-0000-000000000010', ST_Point(32.5742, 0.3201)::geography, 'Kampala', 'Nakasero',      30, NOW() - INTERVAL '50 minutes'),
  ('aa000001-0000-0000-0000-000000000011', ST_Point(32.5952, 0.3860)::geography, 'Kampala', 'Kisasi',        65, NOW() - INTERVAL '8 minutes'),
  ('aa000001-0000-0000-0000-000000000012', ST_Point(32.5976, 0.3360)::geography, 'Kampala', 'Bukoto',        40, NOW() - INTERVAL '40 minutes'),
  ('aa000001-0000-0000-0000-000000000013', ST_Point(32.5819, 0.3286)::geography, 'Kampala', 'Kololo',        60, NOW() - INTERVAL '12 minutes'),
  ('aa000001-0000-0000-0000-000000000014', ST_Point(32.6336, 0.3002)::geography, 'Kampala', 'Mutungo',       75, NOW() - INTERVAL '22 minutes'),
  ('aa000001-0000-0000-0000-000000000017', ST_Point(32.6720, 0.3420)::geography, 'Kampala', 'Bweyogerere',   55, NOW() - INTERVAL '7 minutes'),
  ('aa000001-0000-0000-0000-000000000018', ST_Point(32.6601, 0.2916)::geography, 'Kampala', 'Luzira',        80, NOW() - INTERVAL '60 minutes'),
  ('aa000001-0000-0000-0000-000000000019', ST_Point(32.5517, 0.2988)::geography, 'Kampala', 'Rubaga',        50, NOW() - INTERVAL '18 minutes')
ON CONFLICT DO NOTHING;


-- ── Businesses ────────────────────────────────────────────────────────────────

INSERT INTO businesses (id, owner_id, name, slug, category, description, location, city, neighbourhood, address, phone, price_range, tier, is_verified, rating_avg, opening_hours)
VALUES
  (
    'bb000002-0000-0000-0000-000000000001',
    'aa000001-0000-0000-0000-000000000010',
    'Kampala Grill House', 'kampala-grill-house', 'food_dining',
    'Kampala''s favourite nyama choma and grills. Open air, live music weekends.',
    ST_Point(32.5841, 0.3271)::geography, 'Kampala', 'Kololo',
    'Plot 23, Kololo Hill Drive, Kampala', '+256414100001', 2, 'growth', TRUE, 4.60,
    '{"mon":{"open":"12:00","close":"23:00"},"tue":{"open":"12:00","close":"23:00"},"wed":{"open":"12:00","close":"23:00"},"thu":{"open":"12:00","close":"23:00"},"fri":{"open":"12:00","close":"01:00"},"sat":{"open":"11:00","close":"01:00"},"sun":{"open":"11:00","close":"22:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000002',
    'aa000001-0000-0000-0000-000000000004',
    'Café Pap', 'cafe-pap-nakasero', 'food_dining',
    'The best breakfast in Kampala. Try our rolex and fresh juice.',
    ST_Point(32.5748, 0.3195)::geography, 'Kampala', 'Nakasero',
    '8 Nakasero Road, Kampala', '+256414100002', 1, 'free', FALSE, 4.40,
    '{"mon":{"open":"07:00","close":"20:00"},"tue":{"open":"07:00","close":"20:00"},"wed":{"open":"07:00","close":"20:00"},"thu":{"open":"07:00","close":"20:00"},"fri":{"open":"07:00","close":"20:00"},"sat":{"open":"08:00","close":"18:00"},"sun":{"open":"09:00","close":"16:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000003',
    'aa000001-0000-0000-0000-000000000010',
    'The Lawns Hotel', 'the-lawns-hotel', 'accommodation',
    'Boutique hotel with garden, pool and farm-to-table restaurant.',
    ST_Point(32.5801, 0.3298)::geography, 'Kampala', 'Kololo',
    '3 Malcolm X Avenue, Kololo, Kampala', '+256414100003', 3, 'pro', TRUE, 4.70,
    '{"mon":{"open":"00:00","close":"23:59"},"tue":{"open":"00:00","close":"23:59"},"wed":{"open":"00:00","close":"23:59"},"thu":{"open":"00:00","close":"23:59"},"fri":{"open":"00:00","close":"23:59"},"sat":{"open":"00:00","close":"23:59"},"sun":{"open":"00:00","close":"23:59"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000004',
    'aa000001-0000-0000-0000-000000000017',
    'Matoke Republic', 'matoke-republic-ntinda', 'food_dining',
    'Authentic Ugandan home cooking. Matoke, groundnut stew, posho and more.',
    ST_Point(32.6158, 0.3542)::geography, 'Kampala', 'Ntinda',
    'Plot 7, Ntinda Road, Kampala', '+256414100004', 1, 'free', FALSE, 4.80,
    '{"mon":{"open":"08:00","close":"22:00"},"tue":{"open":"08:00","close":"22:00"},"wed":{"open":"08:00","close":"22:00"},"thu":{"open":"08:00","close":"22:00"},"fri":{"open":"08:00","close":"22:00"},"sat":{"open":"09:00","close":"22:00"},"sun":{"open":"09:00","close":"21:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000005',
    'aa000001-0000-0000-0000-000000000004',
    'Liquid Silk', 'liquid-silk-kabalagala', 'entertainment',
    'Kampala''s top bar and club. Live performances every Friday and Saturday.',
    ST_Point(32.5889, 0.2705)::geography, 'Kampala', 'Kabalagala',
    'Kabalagala, Kampala', '+256414100005', 2, 'growth', TRUE, 4.20,
    '{"thu":{"open":"19:00","close":"03:00"},"fri":{"open":"18:00","close":"04:00"},"sat":{"open":"18:00","close":"04:00"},"sun":{"open":"18:00","close":"02:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000006',
    'aa000001-0000-0000-0000-000000000014',
    'FitLife Gym Ntinda', 'fitlife-gym-ntinda', 'health_wellness',
    'Modern gym with certified trainers, cardio zone, and nutrition advice.',
    ST_Point(32.6175, 0.3561)::geography, 'Kampala', 'Ntinda',
    'Ntinda Complex, Kampala', '+256414100006', 2, 'free', FALSE, 4.30,
    '{"mon":{"open":"06:00","close":"21:00"},"tue":{"open":"06:00","close":"21:00"},"wed":{"open":"06:00","close":"21:00"},"thu":{"open":"06:00","close":"21:00"},"fri":{"open":"06:00","close":"21:00"},"sat":{"open":"07:00","close":"19:00"},"sun":{"open":"08:00","close":"17:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000007',
    'aa000001-0000-0000-0000-000000000011',
    'Nalubale Hair Studio', 'nalubale-hair-studio', 'beauty_grooming',
    'Specialising in braids, locs, afros and natural hair care. Book online.',
    ST_Point(32.5947, 0.3855)::geography, 'Kampala', 'Kisasi',
    'Kisasi Road, Kampala', '+256414100007', 2, 'free', FALSE, 4.90,
    '{"mon":{"open":"09:00","close":"19:00"},"tue":{"open":"09:00","close":"19:00"},"wed":{"open":"09:00","close":"19:00"},"thu":{"open":"09:00","close":"19:00"},"fri":{"open":"09:00","close":"19:00"},"sat":{"open":"09:00","close":"18:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000008',
    'aa000001-0000-0000-0000-000000000012',
    'The Bookpoint', 'the-bookpoint-nakasero', 'retail',
    'Kampala''s independent bookstore. New, used and Ugandan authors.',
    ST_Point(32.5729, 0.3210)::geography, 'Kampala', 'Nakasero',
    'Nakasero Road, Kampala', '+256414100008', 1, 'free', FALSE, 4.50,
    '{"mon":{"open":"09:00","close":"18:00"},"tue":{"open":"09:00","close":"18:00"},"wed":{"open":"09:00","close":"18:00"},"thu":{"open":"09:00","close":"18:00"},"fri":{"open":"09:00","close":"18:00"},"sat":{"open":"10:00","close":"17:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000009',
    'aa000001-0000-0000-0000-000000000004',
    'Café Javas Bugolobi', 'cafe-javas-bugolobi', 'food_dining',
    'Kampala''s most loved restaurant chain. All-day breakfast, local and international.',
    ST_Point(32.6159, 0.3172)::geography, 'Kampala', 'Bugolobi',
    'Bugolobi Shopping Centre, Kampala', '+256414100009', 2, 'growth', TRUE, 4.50,
    '{"mon":{"open":"07:00","close":"23:00"},"tue":{"open":"07:00","close":"23:00"},"wed":{"open":"07:00","close":"23:00"},"thu":{"open":"07:00","close":"23:00"},"fri":{"open":"07:00","close":"23:30"},"sat":{"open":"07:00","close":"23:30"},"sun":{"open":"08:00","close":"22:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000010',
    'aa000001-0000-0000-0000-000000000007',
    'Kabira Country Club', 'kabira-country-club', 'entertainment',
    'Golf, tennis, pool, restaurant and events. Membership and day passes available.',
    ST_Point(32.5974, 0.3361)::geography, 'Kampala', 'Bukoto',
    'Bukoto, Kampala', '+256414100010', 3, 'pro', TRUE, 4.60,
    '{"mon":{"open":"07:00","close":"22:00"},"tue":{"open":"07:00","close":"22:00"},"wed":{"open":"07:00","close":"22:00"},"thu":{"open":"07:00","close":"22:00"},"fri":{"open":"07:00","close":"23:00"},"sat":{"open":"07:00","close":"23:00"},"sun":{"open":"07:00","close":"21:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000011',
    'aa000001-0000-0000-0000-000000000009',
    'Nakasero Market Fresh', 'nakasero-market-fresh', 'agriculture_markets',
    'The original Kampala fresh produce market. Fruits, vegetables, spices, meat.',
    ST_Point(32.5770, 0.3190)::geography, 'Kampala', 'Nakasero',
    'Nakasero Market, Kampala', '+256414100011', 1, 'free', FALSE, 4.10,
    '{"mon":{"open":"06:00","close":"18:00"},"tue":{"open":"06:00","close":"18:00"},"wed":{"open":"06:00","close":"18:00"},"thu":{"open":"06:00","close":"18:00"},"fri":{"open":"06:00","close":"18:00"},"sat":{"open":"06:00","close":"18:00"},"sun":{"open":"07:00","close":"15:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000012',
    'aa000001-0000-0000-0000-000000000004',
    'Silver Springs Hotel', 'silver-springs-hotel', 'accommodation',
    'Mid-range hotel with conference facilities, restaurant and rooftop bar.',
    ST_Point(32.6174, 0.3158)::geography, 'Kampala', 'Bugolobi',
    '6th Street Industrial Area, Bugolobi, Kampala', '+256414100012', 2, 'growth', TRUE, 4.00,
    '{"mon":{"open":"00:00","close":"23:59"},"tue":{"open":"00:00","close":"23:59"},"wed":{"open":"00:00","close":"23:59"},"thu":{"open":"00:00","close":"23:59"},"fri":{"open":"00:00","close":"23:59"},"sat":{"open":"00:00","close":"23:59"},"sun":{"open":"00:00","close":"23:59"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000013',
    'aa000001-0000-0000-0000-000000000018',
    'Kiwi Bar & Grill', 'kiwi-bar-muyenga', 'food_dining',
    'Lakeside vibes and fresh tilapia from Lake Victoria. Sunset views.',
    ST_Point(32.6031, 0.2682)::geography, 'Kampala', 'Muyenga',
    'Tank Hill Road, Muyenga, Kampala', '+256414100013', 2, 'free', FALSE, 4.30,
    '{"mon":{"open":"11:00","close":"23:00"},"tue":{"open":"11:00","close":"23:00"},"wed":{"open":"11:00","close":"23:00"},"thu":{"open":"11:00","close":"23:00"},"fri":{"open":"11:00","close":"01:00"},"sat":{"open":"11:00","close":"01:00"},"sun":{"open":"11:00","close":"22:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000014',
    'aa000001-0000-0000-0000-000000000005',
    'Pearl Beauty Spa', 'pearl-beauty-spa-kololo', 'beauty_grooming',
    'Premium spa: massage, facials, manicure, pedicure. Book a day of relaxation.',
    ST_Point(32.5825, 0.3280)::geography, 'Kampala', 'Kololo',
    'Kololo, Kampala', '+256414100014', 3, 'growth', FALSE, 4.70,
    '{"mon":{"open":"09:00","close":"20:00"},"tue":{"open":"09:00","close":"20:00"},"wed":{"open":"09:00","close":"20:00"},"thu":{"open":"09:00","close":"20:00"},"fri":{"open":"09:00","close":"20:00"},"sat":{"open":"09:00","close":"19:00"},"sun":{"open":"10:00","close":"17:00"}}'
  ),
  (
    'bb000002-0000-0000-0000-000000000015',
    'aa000001-0000-0000-0000-000000000002',
    'TechHub Kampala', 'techhub-kampala', 'technology',
    'Coworking space, event venue and tech community for Kampala''s builders.',
    ST_Point(32.5761, 0.3202)::geography, 'Kampala', 'Nakasero',
    'Nakasero, Kampala', '+256414100015', 2, 'growth', TRUE, 4.80,
    '{"mon":{"open":"08:00","close":"22:00"},"tue":{"open":"08:00","close":"22:00"},"wed":{"open":"08:00","close":"22:00"},"thu":{"open":"08:00","close":"22:00"},"fri":{"open":"08:00","close":"22:00"},"sat":{"open":"09:00","close":"18:00"}}'
  )
ON CONFLICT (id) DO NOTHING;


-- ── Posts ─────────────────────────────────────────────────────────────────────
-- NOTE: feed query filters created_at > NOW() - 48h, so all posts use recent timestamps.
-- Spread across Kampala. Bweyogerere/Kireka cluster (near test user 0.3375, 32.6598)
-- gets the highest density so they appear in the feed immediately.

INSERT INTO posts (user_id, post_type, content, location, city, neighbourhood, interest_tags, been_here_count, like_count, comment_count, moderation_status, created_at)
VALUES

-- ── CLUSTER 1: Bweyogerere / Kireka / Banda (within 2km of test user) ────────

  ('aa000001-0000-0000-0000-000000000006', 'location_post', 'The rolex here at Kireka stage is unbeatable — 1,500 UGX and your whole morning is sorted. This lady has been rolling since 6am!',                   ST_Point(32.6610, 0.3285)::geography, 'Kampala', 'Kireka',       ARRAY['food','street_food'],   14, 22, 5, 'approved', NOW() - INTERVAL '1 hour'),
  ('aa000001-0000-0000-0000-000000000003', 'location_post', 'Power came back to Kyaliwajjala after 6 hours! UMEME really tested us today 😤',                                                                      ST_Point(32.6540, 0.3625)::geography, 'Kampala', 'Kyaliwajjala', ARRAY['community'],            8,  15, 7, 'approved', NOW() - INTERVAL '2 hours'),
  ('aa000001-0000-0000-0000-000000000008', 'location_post', 'Banda market on a Saturday morning hits different. Best tomatoes in Kampala, 3,000 UGX a kilo. Come early!',                                          ST_Point(32.6325, 0.3475)::geography, 'Kampala', 'Banda',         ARRAY['food','market'],        11, 19, 4, 'approved', NOW() - INTERVAL '3 hours'),
  ('aa000001-0000-0000-0000-000000000017', 'flash',         'BWEYOGERERE FLASH 🔴 Boda accident on the main road near Total petrol station. Avoid that stretch if you can!',                                        ST_Point(32.6718, 0.3435)::geography, 'Kampala', 'Bweyogerere',  ARRAY['safety','transport'],   32, 41, 18,'approved', NOW() - INTERVAL '30 minutes'),
  ('aa000001-0000-0000-0000-000000000006', 'flash',         '⚡ FLASH: Matoke chips at Kireka market only 2k today — vendor doing clearance before closing. Go now!',                                               ST_Point(32.6598, 0.3290)::geography, 'Kampala', 'Kireka',       ARRAY['food','deal'],          28, 36, 12,'approved', NOW() - INTERVAL '45 minutes'),
  ('aa000001-0000-0000-0000-000000000003', 'community_ask', 'Anyone know a good plumber in Kyaliwajjala area? My landlord has abandoned us with a broken pipe 😭 Serious recommendations only please.',             ST_Point(32.6548, 0.3630)::geography, 'Kampala', 'Kyaliwajjala', ARRAY['community','housing'],  5,  8,  15,'approved', NOW() - INTERVAL '4 hours'),
  ('aa000001-0000-0000-0000-000000000008', 'location_post', 'New sports bar opened near Naalya roundabout — big screens, cold beers, and they showed Arsenal last night. Legend!',                                   ST_Point(32.6378, 0.3870)::geography, 'Kampala', 'Naalya',        ARRAY['sports','nightlife'],   9,  17, 6, 'approved', NOW() - INTERVAL '5 hours'),
  ('aa000001-0000-0000-0000-000000000017', 'location_post', 'My salon in Bweyogerere is finally open after renovation! Come through for braids, nails, and relaxation. New machines, clean space 💅',              ST_Point(32.6720, 0.3421)::geography, 'Kampala', 'Bweyogerere',  ARRAY['beauty','business'],    18, 29, 9, 'approved', NOW() - INTERVAL '6 hours'),
  ('aa000001-0000-0000-0000-000000000006', 'cultural_note', 'Tip for newcomers to Kireka: always greet the older person first before starting any business conversation. Respect is currency here 🙏',              ST_Point(32.6605, 0.3282)::geography, 'Kampala', 'Kireka',       ARRAY['culture','etiquette'],  22, 34, 8, 'approved', NOW() - INTERVAL '8 hours'),
  ('aa000001-0000-0000-0000-000000000003', 'location_post', 'Sunset from the hill in Kyaliwajjala tonight is absolutely gorgeous. Kampala you are beautiful 🌅',                                                    ST_Point(32.6532, 0.3618)::geography, 'Kampala', 'Kyaliwajjala', ARRAY['nature','photography'],  31, 48, 11,'approved', NOW() - INTERVAL '10 hours'),
  ('aa000001-0000-0000-0000-000000000008', 'location_post', 'Bweyogerere industrial park is buzzing today. So many businesses here, this area is genuinely becoming an economic hub.',                               ST_Point(32.6690, 0.3445)::geography, 'Kampala', 'Bweyogerere',  ARRAY['business','community'], 7,  14, 4, 'approved', NOW() - INTERVAL '12 hours'),
  ('aa000001-0000-0000-0000-000000000006', 'community_ask', 'Good Sunday church in Kireka with music that actually slaps? I''m looking for a new congregation after moving here.',                                   ST_Point(32.6612, 0.3278)::geography, 'Kampala', 'Kireka',       ARRAY['community','faith'],    4,  7,  19,'approved', NOW() - INTERVAL '14 hours'),
  ('aa000001-0000-0000-0000-000000000017', 'location_post', 'The chicken suquat place near Bweyogerere stage — 3 pieces + chips for 8k. I eat here every week. Best value.',                                       ST_Point(32.6705, 0.3430)::geography, 'Kampala', 'Bweyogerere',  ARRAY['food','value'],         15, 24, 7, 'approved', NOW() - INTERVAL '16 hours'),
  ('aa000001-0000-0000-0000-000000000003', 'flash',         '🔴 KYALIWAJJALA: Water from tap is brown today. NWS must be fixing pipes nearby. Buy jerricans or use bottled water!',                               ST_Point(32.6551, 0.3621)::geography, 'Kampala', 'Kyaliwajjala', ARRAY['community','utilities'], 44, 52, 22,'approved', NOW() - INTERVAL '20 minutes'),
  ('aa000001-0000-0000-0000-000000000008', 'location_post', 'Just spotted fresh katogo being made at a mama''s place near Banda junction. She''s there every morning 6-9am. Pure comfort food.',                   ST_Point(32.6318, 0.3481)::geography, 'Kampala', 'Banda',         ARRAY['food','street_food'],   12, 21, 5, 'approved', NOW() - INTERVAL '7 hours'),
  ('aa000001-0000-0000-0000-000000000006', 'location_post', 'Kireka trading centre is getting a facelift! New paint, paved section near the stage. Progress.',                                                      ST_Point(32.6601, 0.3275)::geography, 'Kampala', 'Kireka',       ARRAY['community','infrastructure'],7, 13, 3, 'approved', NOW() - INTERVAL '22 hours'),
  ('aa000001-0000-0000-0000-000000000003', 'diary',         'Six months in Kampala from Gulu. Here''s what I''ve learned: 1. Boda prices are negotiable. 2. Always check Google Maps before going somewhere new. 3. Eat where the workers eat.',
                                                                                                                                                                                                                    ST_Point(32.6543, 0.3624)::geography, 'Kampala', 'Kyaliwajjala', ARRAY['travel','community','advice'], 26, 43, 14,'approved', NOW() - INTERVAL '11 hours'),
  ('aa000001-0000-0000-0000-000000000017', 'location_post', 'Bweyogerere market has the best smoked fish in Kampala. Ask for the woman near the gate, she knows quality.',                                          ST_Point(32.6710, 0.3440)::geography, 'Kampala', 'Bweyogerere',  ARRAY['food','market'],        10, 18, 4, 'approved', NOW() - INTERVAL '18 hours'),
  ('aa000001-0000-0000-0000-000000000008', 'cultural_note', 'In Naalya area, many residents are from different tribes. This area is one of Kampala''s most genuinely mixed communities. Beautiful diversity.',      ST_Point(32.6382, 0.3875)::geography, 'Kampala', 'Naalya',        ARRAY['culture','community'],  19, 28, 6, 'approved', NOW() - INTERVAL '15 hours'),
  ('aa000001-0000-0000-0000-000000000006', 'flash',         'LIVE NOW 🎵 Kireka stage area — guy with a guitar is putting on a free show. Massive crowd. Come through!',                                             ST_Point(32.6615, 0.3283)::geography, 'Kampala', 'Kireka',       ARRAY['music','entertainment'], 38, 55, 17,'approved', NOW() - INTERVAL '15 minutes'),

-- ── CLUSTER 2: Ntinda / Kiwatule (within 3-4km of test user) ─────────────────

  ('aa000001-0000-0000-0000-000000000002', 'location_post', 'Ntinda shopping centre has a new sushi spot! Only in Kampala would I find this next to a rolex stand. I''m not complaining.',                          ST_Point(32.6155, 0.3548)::geography, 'Kampala', 'Ntinda',        ARRAY['food','culture'],       16, 25, 8, 'approved', NOW() - INTERVAL '2 hours'),
  ('aa000001-0000-0000-0000-000000000004', 'review',        'Matoke Republic in Ntinda — 5 stars, no question. The groundnut stew is exactly like home. Huge portions, friendly staff, fast service. This is the Uganda food experience.',
                                                                                                                                                                                                                    ST_Point(32.6158, 0.3542)::geography, 'Kampala', 'Ntinda',        ARRAY['food','review'],        24, 38, 12,'approved', NOW() - INTERVAL '3 hours'),
  ('aa000001-0000-0000-0000-000000000002', 'location_post', 'FitLife Gym at Ntinda — dropped in for a session. Equipment is solid, trainer actually corrected my form. Worth the 50k monthly.',                     ST_Point(32.6175, 0.3561)::geography, 'Kampala', 'Ntinda',        ARRAY['fitness','health'],     8,  16, 5, 'approved', NOW() - INTERVAL '4 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'flash',         '🔴 NTINDA: Flooding at the main road by Shell petrol station after the rains. Boda bodas only. Cars must use bypass.',                                  ST_Point(32.6162, 0.3555)::geography, 'Kampala', 'Ntinda',        ARRAY['safety','transport'],   51, 63, 24,'approved', NOW() - INTERVAL '40 minutes'),
  ('aa000001-0000-0000-0000-000000000002', 'community_ask', 'Best mechanic in Ntinda for Toyota Spacio? My car is making a strange noise and I don''t trust garages I don''t know.',                                ST_Point(32.6168, 0.3552)::geography, 'Kampala', 'Ntinda',        ARRAY['transport','community'],6,  11, 21,'approved', NOW() - INTERVAL '5 hours'),
  ('aa000001-0000-0000-0000-000000000004', 'location_post', 'Kiwatule has become a proper neighbourhood now. Shopping, restaurants, schools all here. Was bush 10 years ago.',                                       ST_Point(32.6440, 0.3615)::geography, 'Kampala', 'Kiwatule',      ARRAY['community','development'],13, 22, 7,'approved', NOW() - INTERVAL '9 hours'),
  ('aa000001-0000-0000-0000-000000000002', 'cultural_note', 'Ntinda residents: the boda bodas at the Shell stage will overcharge you if you look new. Always negotiate before getting on. Normal fare to town is 4-5k.',
                                                                                                                                                                                                                    ST_Point(32.6158, 0.3545)::geography, 'Kampala', 'Ntinda',        ARRAY['culture','transport','tip'], 35, 52, 16,'approved', NOW() - INTERVAL '13 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'location_post', 'The new park in Kiwatule opened yesterday. Kids are loving it. Finally some green space in this part of Kampala!',                                      ST_Point(32.6445, 0.3620)::geography, 'Kampala', 'Kiwatule',      ARRAY['community','family'],   20, 32, 9, 'approved', NOW() - INTERVAL '20 hours'),

-- ── CLUSTER 3: Central Kampala (Kololo / Nakasero / Bukoto) ──────────────────

  ('aa000001-0000-0000-0000-000000000001', 'location_post', 'Kampala Grill House tonight — the suya was perfectly spiced and the live afrobeats band had us dancing. Best Friday in months.',                       ST_Point(32.5841, 0.3271)::geography, 'Kampala', 'Kololo',        ARRAY['food','music','nightlife'],29, 45, 14,'approved', NOW() - INTERVAL '1 hour'),
  ('aa000001-0000-0000-0000-000000000013', 'location_post', 'Kololo is one of those neighbourhoods that feels like a different city. Quiet roads, embassies, old trees. I love walking here.',                       ST_Point(32.5820, 0.3288)::geography, 'Kampala', 'Kololo',        ARRAY['travel','photography'], 18, 30, 7, 'approved', NOW() - INTERVAL '3 hours'),
  ('aa000001-0000-0000-0000-000000000001', 'review',        'Kampala Grill House ⭐⭐⭐⭐⭐ — I''ve been coming here for 3 years. The open-air setting under the trees, the nyama choma smoke, the cold Nile Special. This is Kampala at its best.',
                                                                                                                                                                                                                    ST_Point(32.5841, 0.3271)::geography, 'Kampala', 'Kololo',        ARRAY['food','review'],        33, 51, 18,'approved', NOW() - INTERVAL '5 hours'),
  ('aa000001-0000-0000-0000-000000000010', 'location_post', 'Nakasero market at 7am — the freshest produce in the city. Avocados the size of your fist. Passion fruits, mangoes, everything.',                      ST_Point(32.5770, 0.3190)::geography, 'Kampala', 'Nakasero',      ARRAY['food','market'],        22, 35, 9, 'approved', NOW() - INTERVAL '4 hours'),
  ('aa000001-0000-0000-0000-000000000012', 'location_post', 'TechHub Kampala is hosting a founder meetup tonight at 6pm. Free for all. Come pitch your idea or just listen and network.',                            ST_Point(32.5761, 0.3202)::geography, 'Kampala', 'Nakasero',      ARRAY['tech','business','networking'],17, 28, 11,'approved', NOW() - INTERVAL '2 hours'),
  ('aa000001-0000-0000-0000-000000000013', 'review',        'The Lawns Hotel — breakfast on the lawn on a Sunday morning is a Kampala institution. Proper eggs benedict, fresh juice, and that garden vibe. Worth every shilling.',
                                                                                                                                                                                                                    ST_Point(32.5801, 0.3298)::geography, 'Kampala', 'Kololo',        ARRAY['food','accommodation','review'],21, 37, 10,'approved', NOW() - INTERVAL '8 hours'),
  ('aa000001-0000-0000-0000-000000000001', 'cultural_note', 'A note for visitors to Kololo: many of the old houses here were built during the colonial era. If you see a building from the 1950s, it has history. The architecture tells stories.',
                                                                                                                                                                                                                    ST_Point(32.5818, 0.3284)::geography, 'Kampala', 'Kololo',        ARRAY['culture','history'],    28, 44, 12,'approved', NOW() - INTERVAL '10 hours'),
  ('aa000001-0000-0000-0000-000000000012', 'location_post', 'Café Pap rolex breakfast — ask for the "special" with extra egg and onion. She won''t list it on the menu but it exists. Thank me later.',              ST_Point(32.5748, 0.3195)::geography, 'Kampala', 'Nakasero',      ARRAY['food','tip'],           27, 42, 11,'approved', NOW() - INTERVAL '6 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'location_post', 'Kabira Country Club pool on a hot afternoon — this is the life. Day pass is 30k. Totally worth it.',                                                   ST_Point(32.5974, 0.3361)::geography, 'Kampala', 'Bukoto',        ARRAY['leisure','fitness'],    14, 23, 6, 'approved', NOW() - INTERVAL '7 hours'),
  ('aa000001-0000-0000-0000-000000000004', 'flash',         '🔴 NAKASERO: Protest march on Kampala Road near the post office. Avoid the area for the next hour. Traffic backed up to Clock Tower.',                 ST_Point(32.5730, 0.3200)::geography, 'Kampala', 'Nakasero',      ARRAY['safety','transport'],   67, 82, 31,'approved', NOW() - INTERVAL '25 minutes'),
  ('aa000001-0000-0000-0000-000000000001', 'community_ask', 'Best hairdresser in Kololo / Nakasero for natural hair? Someone who actually understands 4C hair, not just straightening everything.',                  ST_Point(32.5822, 0.3279)::geography, 'Kampala', 'Kololo',        ARRAY['beauty','community'],   8,  15, 22,'approved', NOW() - INTERVAL '11 hours'),
  ('aa000001-0000-0000-0000-000000000010', 'location_post', 'The Bookpoint in Nakasero — found 3 Ugandan novels I''ve never seen before. One by Moses Isegawa, one by Jennifer Makumbi. This shop is a treasure.',  ST_Point(32.5729, 0.3210)::geography, 'Kampala', 'Nakasero',      ARRAY['culture','books','art'],16, 27, 8, 'approved', NOW() - INTERVAL '14 hours'),
  ('aa000001-0000-0000-0000-000000000013', 'diary',         'Week 2 in Kampala. Impressions so far: food is incredible and cheap. Traffic is chaos. People are warm and genuinely helpful. The city has a pulse I haven''t felt anywhere in East Africa.',
                                                                                                                                                                                                                    ST_Point(32.5815, 0.3291)::geography, 'Kampala', 'Kololo',        ARRAY['travel','culture'],     32, 50, 18,'approved', NOW() - INTERVAL '16 hours'),

-- ── CLUSTER 4: Bugolobi / Mutungo / Luzira ───────────────────────────────────

  ('aa000001-0000-0000-0000-000000000004', 'review',        'Café Javas Bugolobi — consistent as always. The pancakes are a 10/10. Friendly service, good wifi for working. My Saturday morning spot.',              ST_Point(32.6159, 0.3172)::geography, 'Kampala', 'Bugolobi',      ARRAY['food','review'],        19, 31, 8, 'approved', NOW() - INTERVAL '2 hours'),
  ('aa000001-0000-0000-0000-000000000014', 'location_post', 'Lake Victoria viewpoint in Mutungo — sun is setting, boats coming in, fishermen bringing catch. Moments like this remind you why Kampala is special.',  ST_Point(32.6336, 0.3002)::geography, 'Kampala', 'Mutungo',       ARRAY['nature','photography'], 28, 46, 13,'approved', NOW() - INTERVAL '3 hours'),
  ('aa000001-0000-0000-0000-000000000018', 'location_post', 'Luzira market has the freshest tilapia you''ll find in Kampala. Straight from the lake this morning. Buy whole fish and ask them to clean it for you — they will.',
                                                                                                                                                                                                                    ST_Point(32.6601, 0.2916)::geography, 'Kampala', 'Luzira',        ARRAY['food','market'],        14, 23, 5, 'approved', NOW() - INTERVAL '4 hours'),
  ('aa000001-0000-0000-0000-000000000004', 'flash',         '⚡ FLASH: Silver Springs Hotel rooftop bar just announced 50% off cocktails until 8pm tonight. Go go go!',                                              ST_Point(32.6174, 0.3158)::geography, 'Kampala', 'Bugolobi',      ARRAY['food','nightlife','deal'],36, 55, 20,'approved', NOW() - INTERVAL '50 minutes'),
  ('aa000001-0000-0000-0000-000000000014', 'community_ask', 'Can anyone recommend a reliable swimming coach near Mutungo or Luzira? Want to finally learn properly.',                                                 ST_Point(32.6332, 0.3005)::geography, 'Kampala', 'Mutungo',       ARRAY['fitness','community'],  5,  9,  17,'approved', NOW() - INTERVAL '9 hours'),
  ('aa000001-0000-0000-0000-000000000018', 'cultural_note', 'Luzira is one of Kampala''s most underrated areas. Close to the lake, real community feel, cheaper rent than most. The fish-market culture is its own world worth experiencing.',
                                                                                                                                                                                                                    ST_Point(32.6598, 0.2918)::geography, 'Kampala', 'Luzira',        ARRAY['culture','community'],  24, 38, 10,'approved', NOW() - INTERVAL '17 hours'),
  ('aa000001-0000-0000-0000-000000000014', 'location_post', 'Morning run along the lake road in Mutungo — 5am, no traffic, cool air, kingfishers over the water. Best way to start the day in Kampala.',            ST_Point(32.6340, 0.3008)::geography, 'Kampala', 'Mutungo',       ARRAY['fitness','outdoors'],   22, 36, 8, 'approved', NOW() - INTERVAL '5 hours'),

-- ── CLUSTER 5: Kabalagala / Muyenga / Makindye ───────────────────────────────

  ('aa000001-0000-0000-0000-000000000009', 'location_post', 'Liquid Silk on a Friday is a full experience. The crowd, the music, the energy. DJ was killing it last night. Kabalagala never disappoints.',           ST_Point(32.5889, 0.2705)::geography, 'Kampala', 'Kabalagala',    ARRAY['nightlife','music'],    25, 40, 15,'approved', NOW() - INTERVAL '10 hours'),
  ('aa000001-0000-0000-0000-000000000009', 'review',        'Kiwi Bar & Grill in Muyenga — the tilapia is straight from the lake, you can taste the freshness. Sunset view of Lake Victoria. A must-visit for any fish lover in Kampala.',
                                                                                                                                                                                                                    ST_Point(32.6031, 0.2682)::geography, 'Kampala', 'Muyenga',       ARRAY['food','review'],        23, 37, 11,'approved', NOW() - INTERVAL '6 hours'),
  ('aa000001-0000-0000-0000-000000000005', 'location_post', 'Pearl Beauty Spa day done. The hot stone massage erased three weeks of stress. The staff are professional and the space is beautiful. Treating yourself is not a luxury, it''s maintenance.',
                                                                                                                                                                                                                    ST_Point(32.5825, 0.3280)::geography, 'Kampala', 'Kololo',        ARRAY['beauty','wellness'],    17, 28, 7, 'approved', NOW() - INTERVAL '4 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'location_post', 'Makindye community hall just hosted a neighbourhood clean-up. Over 100 residents came out. This is what community looks like!',                          ST_Point(32.5903, 0.2780)::geography, 'Kampala', 'Makindye',      ARRAY['community','environment'],21, 33, 9,'approved', NOW() - INTERVAL '12 hours'),
  ('aa000001-0000-0000-0000-000000000009', 'cultural_note', 'Kabalagala tip: it''s safe but stay aware after midnight. The bars close at different times. Always sort your transport before your last drink.',        ST_Point(32.5891, 0.2700)::geography, 'Kampala', 'Kabalagala',    ARRAY['culture','safety','tip'],30, 47, 14,'approved', NOW() - INTERVAL '20 hours'),
  ('aa000001-0000-0000-0000-000000000005', 'community_ask', 'Anyone know fabric suppliers in Kampala selling Kitenge at wholesale prices? I want to start making Ugandan fashion.',                                   ST_Point(32.5890, 0.2695)::geography, 'Kampala', 'Kabalagala',    ARRAY['fashion','business'],   7,  14, 19,'approved', NOW() - INTERVAL '8 hours'),
  ('aa000001-0000-0000-0000-000000000009', 'flash',         '🎵 LIVE: Jazz night at Muyenga bar starting NOW. No cover charge before 9pm. Bring friends!',                                                           ST_Point(32.6028, 0.2685)::geography, 'Kampala', 'Muyenga',       ARRAY['music','nightlife'],    42, 58, 19,'approved', NOW() - INTERVAL '35 minutes'),

-- ── CLUSTER 6: Kisasi / Bukoto / Mengo / Rubaga ──────────────────────────────

  ('aa000001-0000-0000-0000-000000000011', 'review',        'Nalubale Hair Studio is my new home! Christine does the best knotless braids I''ve had in Kampala. She takes her time, clean technique, salon is spotless. Book ahead — she''s always full.',
                                                                                                                                                                                                                    ST_Point(32.5947, 0.3855)::geography, 'Kampala', 'Kisasi',        ARRAY['beauty','review'],      31, 48, 17,'approved', NOW() - INTERVAL '1 hour'),
  ('aa000001-0000-0000-0000-000000000011', 'location_post', 'Kisasi has this incredible neighbourhood energy on Sunday mornings. Church music from 4 different places, kids everywhere, mama selling mandazi at the junction. Pure Uganda.',
                                                                                                                                                                                                                    ST_Point(32.5950, 0.3858)::geography, 'Kampala', 'Kisasi',        ARRAY['culture','community'],  19, 32, 7, 'approved', NOW() - INTERVAL '6 hours'),
  ('aa000001-0000-0000-0000-000000000012', 'location_post', 'Mengo hill has some incredible colonial-era architecture if you walk around. Buganda Kingdom buildings, old churches, hidden gardens. A walking tour would be amazing here.',
                                                                                                                                                                                                                    ST_Point(32.5617, 0.3074)::geography, 'Kampala', 'Mengo',         ARRAY['culture','history'],    22, 36, 11,'approved', NOW() - INTERVAL '3 hours'),
  ('aa000001-0000-0000-0000-000000000019', 'location_post', 'Rubaga maternity hospital is doing incredible work. I was there for a colleague''s baby today. The nurses are angels — overworked but so dedicated.',   ST_Point(32.5517, 0.2988)::geography, 'Kampala', 'Rubaga',        ARRAY['health','community'],   15, 24, 6, 'approved', NOW() - INTERVAL '5 hours'),
  ('aa000001-0000-0000-0000-000000000012', 'community_ask', 'Best local guide for a tour of Kasubi Tombs and Mengo Palace? Friend visiting from London next month, want to show them real Uganda.',                  ST_Point(32.5620, 0.3068)::geography, 'Kampala', 'Mengo',         ARRAY['culture','tourism'],    9,  17, 23,'approved', NOW() - INTERVAL '10 hours'),
  ('aa000001-0000-0000-0000-000000000019', 'cultural_note', 'Rubaga residents have a strong Buganda Kingdom identity. If you''re new here, learning a few Luganda phrases goes a very long way. "Webale" (thank you) will get you far.',
                                                                                                                                                                                                                    ST_Point(32.5519, 0.2990)::geography, 'Kampala', 'Rubaga',        ARRAY['culture','language'],   34, 52, 15,'approved', NOW() - INTERVAL '14 hours'),
  ('aa000001-0000-0000-0000-000000000011', 'flash',         '⚡ FLASH: Kisasi market has fresh jackfruit today! Huge ones, 10k each. Only 5 left. First come first served.',                                           ST_Point(32.5953, 0.3853)::geography, 'Kampala', 'Kisasi',        ARRAY['food','market','deal'], 29, 41, 11,'approved', NOW() - INTERVAL '20 minutes'),

-- ── CLUSTER 7: More flash posts (urgent/time-sensitive, various locations) ────

  ('aa000001-0000-0000-0000-000000000004', 'flash',         '🔴 KOLOLO: A water pipe burst on Acacia Avenue. Road is half flooded. Engineers on site but avoid until they fix it.',                                   ST_Point(32.5835, 0.3292)::geography, 'Kampala', 'Kololo',        ARRAY['safety','utilities'],   58, 72, 27,'approved', NOW() - INTERVAL '15 minutes'),
  ('aa000001-0000-0000-0000-000000000001', 'flash',         'FREE YOGA at Kololo Independence grounds tomorrow 7am. Bring a mat. Instructor from Nairobi is visiting for one session only!',                          ST_Point(32.5831, 0.3276)::geography, 'Kampala', 'Kololo',        ARRAY['fitness','wellness'],   24, 38, 10,'approved', NOW() - INTERVAL '2 hours'),
  ('aa000001-0000-0000-0000-000000000014', 'flash',         '⚡ Bugolobi area: Power restored after 4-hour outage! Kampala is back online.',                                                                          ST_Point(32.6162, 0.3165)::geography, 'Kampala', 'Bugolobi',      ARRAY['utilities','community'],19, 26, 8, 'approved', NOW() - INTERVAL '3 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'flash',         'MAKINDYE FLASH 🎉 Neighbourhood football tournament final tonight at 5pm. Makindye A vs Makindye B. Come support your team!',                            ST_Point(32.5905, 0.2782)::geography, 'Kampala', 'Makindye',      ARRAY['sports','community'],   33, 48, 14,'approved', NOW() - INTERVAL '1 hour'),
  ('aa000001-0000-0000-0000-000000000010', 'flash',         '🔴 Nakasero area: Police checkpoint near Garden City. If you''re driving, have your documents ready. Queue is moving but slowly.',                        ST_Point(32.5752, 0.3197)::geography, 'Kampala', 'Nakasero',      ARRAY['transport','safety'],   47, 63, 22,'approved', NOW() - INTERVAL '55 minutes'),
  ('aa000001-0000-0000-0000-000000000009', 'flash',         '⚡ KABALAGALA: New club opened last night — "The Underground". 3,000 UGX entry. Music was 🔥. Opens tonight at 8pm.',                                    ST_Point(32.5882, 0.2698)::geography, 'Kampala', 'Kabalagala',    ARRAY['nightlife','entertainment'],40, 58, 22,'approved', NOW() - INTERVAL '8 hours'),

-- ── CLUSTER 8: Reviews (various businesses) ───────────────────────────────────

  ('aa000001-0000-0000-0000-000000000013', 'review',        'Café Pap Nakasero — best rolex in Kampala, full stop. 1,500 UGX for a proper, filling breakfast. She wraps it tight and the egg is always just right. Daily ritual material.',
                                                                                                                                                                                                                    ST_Point(32.5748, 0.3195)::geography, 'Kampala', 'Nakasero',      ARRAY['food','review'],        26, 41, 12,'approved', NOW() - INTERVAL '7 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'review',        'TechHub Kampala — great coworking space. Fast internet, comfortable chairs, good coffee, and you''ll inevitably meet someone interesting. Events calendar is active and worth attending.',
                                                                                                                                                                                                                    ST_Point(32.5761, 0.3202)::geography, 'Kampala', 'Nakasero',      ARRAY['tech','business','review'],20, 32, 9,'approved', NOW() - INTERVAL '12 hours'),
  ('aa000001-0000-0000-0000-000000000005', 'review',        'Pearl Beauty Spa is expensive but worth it for a special occasion. Immaculate space, trained therapists. The deep tissue massage undid months of desk stress.',
                                                                                                                                                                                                                    ST_Point(32.5825, 0.3280)::geography, 'Kampala', 'Kololo',        ARRAY['beauty','wellness','review'],18, 29, 8,'approved', NOW() - INTERVAL '16 hours'),
  ('aa000001-0000-0000-0000-000000000001', 'review',        'Nalubale Hair Studio — Christine is an artist. My locs have never looked this neat. She explains everything she''s doing and the products are all natural. 10/10, already booked for next month.',
                                                                                                                                                                                                                    ST_Point(32.5947, 0.3855)::geography, 'Kampala', 'Kisasi',        ARRAY['beauty','review'],      22, 36, 13,'approved', NOW() - INTERVAL '19 hours'),
  ('aa000001-0000-0000-0000-000000000012', 'review',        'Kabira Country Club — the golf might be for the moneyed crowd but the pool day pass is worth it. Pool is clean, service is attentive, lunch menu is solid. A proper break from the city.',
                                                                                                                                                                                                                    ST_Point(32.5974, 0.3361)::geography, 'Kampala', 'Bukoto',        ARRAY['leisure','review'],     16, 27, 7, 'approved', NOW() - INTERVAL '22 hours'),
  ('aa000001-0000-0000-0000-000000000019', 'review',        'FitLife Gym Ntinda — the personal training sessions are excellent. My trainer pushed me harder than I expected but I can already see results after 3 weeks. Clean changing rooms, reliable AC.',
                                                                                                                                                                                                                    ST_Point(32.6175, 0.3561)::geography, 'Kampala', 'Ntinda',        ARRAY['fitness','review'],     11, 19, 6, 'approved', NOW() - INTERVAL '18 hours'),
  ('aa000001-0000-0000-0000-000000000014', 'review',        'Nakasero Market Fresh — if you want to know what fresh vegetables look like, come here at 7am on a weekday. The farmers bring directly from the fields. Cheaper than supermarkets and ten times better.',
                                                                                                                                                                                                                    ST_Point(32.5770, 0.3190)::geography, 'Kampala', 'Nakasero',      ARRAY['food','market','review'],28, 43, 11,'approved', NOW() - INTERVAL '9 hours'),
  ('aa000001-0000-0000-0000-000000000004', 'review',        'The Bookpoint is a gem. Found signed copies of two Ugandan novels I''d been looking for years. The owner knows every book in the shop and recommends personally. Rare in Kampala.',
                                                                                                                                                                                                                    ST_Point(32.5729, 0.3210)::geography, 'Kampala', 'Nakasero',      ARRAY['culture','books','review'],19, 31, 9,'approved', NOW() - INTERVAL '23 hours'),

-- ── CLUSTER 9: Cultural notes and community posts ─────────────────────────────

  ('aa000001-0000-0000-0000-000000000001', 'cultural_note', 'Ugandan food tip: Rolex (chapati + egg) is the universal breakfast. But every vendor has a different style. Nakasero ones are thin, Kabalagala ones are thicker. Both are valid. Have both.',
                                                                                                                                                                                                                    ST_Point(32.5750, 0.3200)::geography, 'Kampala', 'Nakasero',      ARRAY['food','culture','tip'], 45, 67, 21,'approved', NOW() - INTERVAL '15 hours'),
  ('aa000001-0000-0000-0000-000000000007', 'cultural_note', 'Luganda phrase of the day: "Gyendi?" = "Where are you going?" It''s a greeting, not an interrogation. If someone asks you this in Kampala, they''re just being friendly.',
                                                                                                                                                                                                                    ST_Point(32.5820, 0.3270)::geography, 'Kampala', 'Kololo',        ARRAY['culture','language'],   52, 78, 25,'approved', NOW() - INTERVAL '11 hours'),
  ('aa000001-0000-0000-0000-000000000012', 'cultural_note', 'The 7 hills of Kampala each have a distinct character. Kololo = expats/diplomats, Mengo = Buganda royalty, Rubaga = Catholic, Namirembe = Anglican, Old Kampala = commercial, Makerere = students.',
                                                                                                                                                                                                                    ST_Point(32.5680, 0.3150)::geography, 'Kampala', 'Kampala',       ARRAY['culture','history'],    61, 89, 32,'approved', NOW() - INTERVAL '20 hours'),
  ('aa000001-0000-0000-0000-000000000009', 'cultural_note', 'Cooking tip: Ugandan groundnut stew (ebinyebwa) is the foundation of everything. The secret is roasting the groundnuts yourself and not adding water too early. Slow and low.',
                                                                                                                                                                                                                    ST_Point(32.5900, 0.2700)::geography, 'Kampala', 'Kabalagala',    ARRAY['food','culture','cooking'],38, 57, 18,'approved', NOW() - INTERVAL '13 hours'),
  ('aa000001-0000-0000-0000-000000000019', 'cultural_note', 'Healthcare in Uganda: most pharmacies will give you medication without a prescription for common illnesses. If you have a mild fever or cough, a good pharmacist can help. But see a doctor for anything serious.',
                                                                                                                                                                                                                    ST_Point(32.5520, 0.2990)::geography, 'Kampala', 'Rubaga',        ARRAY['health','culture','tip'],29, 44, 16,'approved', NOW() - INTERVAL '17 hours'),

-- ── CLUSTER 10: Diary posts ───────────────────────────────────────────────────

  ('aa000001-0000-0000-0000-000000000013', 'diary',         'Month 1 in Kampala complete. Things I miss: order, timetables, Kigali''s pavements. Things I don''t miss: the pressure, the cold nights, the formality. Kampala is chaos with warmth and I think I love it.',
                                                                                                                                                                                                                    ST_Point(32.5822, 0.3285)::geography, 'Kampala', 'Kololo',        ARRAY['travel','diary'],       37, 56, 20,'approved', NOW() - INTERVAL '24 hours'),
  ('aa000001-0000-0000-0000-000000000003', 'diary',         'I got my first Kampala boda ride today without getting overcharged. The trick: agree on the fare before getting on, say it confidently, don''t negotiate from a position of desperation. They respect confidence.',
                                                                                                                                                                                                                    ST_Point(32.6540, 0.3622)::geography, 'Kampala', 'Kyaliwajjala', ARRAY['travel','tip'],         23, 38, 12,'approved', NOW() - INTERVAL '21 hours'),
  ('aa000001-0000-0000-0000-000000000018', 'diary',         'Life on Lake Victoria: woke up at 4am to take the boat out with the other fishermen. Back by 10am with enough tilapia to sell and eat. This rhythm is hard but it''s mine.',
                                                                                                                                                                                                                    ST_Point(32.6600, 0.2915)::geography, 'Kampala', 'Luzira',        ARRAY['outdoors','diary','food'],26, 41, 14,'approved', NOW() - INTERVAL '5 hours'),
  ('aa000001-0000-0000-0000-000000000005', 'diary',         'Finally launched my Ugandan fashion line online today. 6 months of sourcing fabrics in Owino market, learning from tailors, understanding what Kampala women want to wear. Terrifying and exciting.',
                                                                                                                                                                                                                    ST_Point(32.5885, 0.2692)::geography, 'Kampala', 'Kabalagala',    ARRAY['fashion','business','diary'],21, 34, 11,'approved', NOW() - INTERVAL '8 hours'),
  ('aa000001-0000-0000-0000-000000000008', 'diary',         'Left Mbarara with nothing but a small bag and a phone in 2021. Today I registered my first company in Kampala. The journey is never straight but it goes forward.',
                                                                                                                                                                                                                    ST_Point(32.6375, 0.3872)::geography, 'Kampala', 'Naalya',        ARRAY['business','diary','community'],41, 63, 22,'approved', NOW() - INTERVAL '12 hours'),
  ('aa000001-0000-0000-0000-000000000019', 'diary',         'Night shift done. 12 hours at Rubaga hospital. Three healthy babies delivered tonight. Whatever hard days I have, this is why I do this work.',         ST_Point(32.5516, 0.2988)::geography, 'Kampala', 'Rubaga',        ARRAY['health','diary'],       48, 72, 19,'approved', NOW() - INTERVAL '6 hours')

ON CONFLICT DO NOTHING;


-- ── Social follows ────────────────────────────────────────────────────────────

INSERT INTO user_follows (follower_id, following_id)
VALUES
  ('aa000001-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000009'),
  ('aa000001-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000010'),
  ('aa000001-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000012'),
  ('aa000001-0000-0000-0000-000000000002', 'aa000001-0000-0000-0000-000000000004'),
  ('aa000001-0000-0000-0000-000000000002', 'aa000001-0000-0000-0000-000000000015'),
  ('aa000001-0000-0000-0000-000000000003', 'aa000001-0000-0000-0000-000000000007'),
  ('aa000001-0000-0000-0000-000000000004', 'aa000001-0000-0000-0000-000000000012'),
  ('aa000001-0000-0000-0000-000000000005', 'aa000001-0000-0000-0000-000000000001'),
  ('aa000001-0000-0000-0000-000000000005', 'aa000001-0000-0000-0000-000000000011'),
  ('aa000001-0000-0000-0000-000000000006', 'aa000001-0000-0000-0000-000000000003'),
  ('aa000001-0000-0000-0000-000000000007', 'aa000001-0000-0000-0000-000000000001'),
  ('aa000001-0000-0000-0000-000000000008', 'aa000001-0000-0000-0000-000000000004'),
  ('aa000001-0000-0000-0000-000000000009', 'aa000001-0000-0000-0000-000000000001'),
  ('aa000001-0000-0000-0000-000000000010', 'aa000001-0000-0000-0000-000000000009'),
  ('aa000001-0000-0000-0000-000000000011', 'aa000001-0000-0000-0000-000000000001'),
  ('aa000001-0000-0000-0000-000000000012', 'aa000001-0000-0000-0000-000000000007'),
  ('aa000001-0000-0000-0000-000000000013', 'aa000001-0000-0000-0000-000000000001'),
  ('aa000001-0000-0000-0000-000000000014', 'aa000001-0000-0000-0000-000000000019'),
  ('aa000001-0000-0000-0000-000000000015', 'aa000001-0000-0000-0000-000000000003'),
  ('aa000001-0000-0000-0000-000000000016', 'aa000001-0000-0000-0000-000000000008')
ON CONFLICT DO NOTHING;
