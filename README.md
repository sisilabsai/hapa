# Hapa

> The local intelligence platform for African cities. Moves before you move.

Hapa connects residents, businesses, and creators in hyper-local city communities. Built for Kampala, Nairobi, Lagos, and beyond.

## Architecture

- **backend/** — Go API (Chi, PostgreSQL/PostGIS, Redis, MeiliSearch, DeepSeek AI)
- **dashboard/** — Next.js 15 business dashboard
- **mobile/** — Flutter mobile app
- **infra/** — Docker Compose, infrastructure configs

## Dashboard Features

| Feature | Description |
|---|---|
| **Hapa Boost** | AI-assisted hyper-local promotion campaigns with radius targeting |
| **Hapa Flash** | Real-time, auto-expiring announcements (1–24h) that drive immediate footfall |
| **Community Circles** | Join and post to local community groups in your business's city |
| **Notification Intelligence** | Engagement heatmaps, smart send-time recommendations, notification analytics |
| **Creator Partners** | Discover and propose collaborations with vetted local creators |
| **Bookings** | In-app booking management |
| **Analytics** | Business performance dashboard |

## Stack

- Go · PostgreSQL · PostGIS · Redis · MeiliSearch · DeepSeek AI
- Next.js 15 · React · TailwindCSS · TanStack Query
- Flutter · Dart

## Local Dev

```bash
# Start backend services
docker compose up -d

# Dashboard
cd dashboard && npm install && npm run dev

# Backend
cd backend && go run ./cmd/api
```

---

hapa.world · Moves Before You Move
