# Hapa Mobile

Hapa is a Flutter mobile app for the Hapa location-intelligent life platform. It talks to the local Go API in this repository, uses Riverpod for state, GoRouter for navigation, Dio for HTTP, and location-aware features for feed, map, places, and people experiences.

## What Is In This App

- Flutter app targeting Android and iOS.
- API client configured through compile-time Dart defines.
- Location-aware screens powered by `geolocator`.
- Map UI powered by `flutter_map` and `latlong2`.
- Offline/local storage dependencies ready through Drift, SQLite, shared preferences, and secure storage.
- Auth token persistence through `flutter_secure_storage`.
- Shared domain models for posts and businesses.

## Repository Layout

From the repository root:

```text
.
├── backend/             # Go API, migrations, services, handlers
├── dashboard/           # Next.js business dashboard
├── docker-compose.yml   # Local Postgres/PostGIS, Redis, Meilisearch, API, dashboard, nginx
└── mobile/              # This Flutter app
```

Important mobile paths:

```text
mobile/lib/main.dart                     # App entry point
mobile/lib/core/config/app_config.dart   # Runtime configuration
mobile/lib/core/api/api_client.dart      # Dio API client and token refresh
mobile/lib/core/navigation/              # GoRouter setup and shell scaffold
mobile/lib/core/theme/                   # App theme
mobile/lib/shared/models/                # Shared data models
```

## Prerequisites

Install these before running the project:

- Flutter SDK compatible with Dart `^3.11.3`
- Android Studio and Android SDK for Android emulator/device builds
- Xcode and CocoaPods for iOS builds on macOS
- Docker and Docker Compose for the local backend stack
- Git

Check your Flutter environment:

```bash
cd mobile
flutter doctor
```

Resolve any Android/iOS toolchain issues that `flutter doctor` reports before continuing.

Check Docker Compose:

```bash
docker compose version
```

If that says `docker: unknown command: docker compose`, install the Compose plugin.

**Ubuntu (Docker installed via Ubuntu's apt mirror — most common)**

```bash
sudo apt update
sudo apt install docker-compose-v2
```

**Ubuntu (Docker installed from Docker's official apt repo)**

```bash
sudo apt update
sudo apt install docker-compose-plugin
```

Not sure which you have? Run `apt-cache show docker.io 2>/dev/null | head -1` — if it prints a result, you have Ubuntu's mirror build and need `docker-compose-v2`.

After installing, confirm:

```bash
docker compose version
```

## Backend Services

The mobile app expects the Hapa API to be available. The easiest development setup is to run the root Docker stack.

Run Docker Compose from the repository root, where `docker-compose.yml` lives:

```bash
cd ..
docker compose up --build
```

This starts:

- PostgreSQL/PostGIS on `localhost:5432`
- Redis on `localhost:6379`
- Meilisearch on `localhost:7700`
- Go API on `localhost:8080`
- Dashboard on `localhost:3000`
- Nginx on `localhost:80`

Confirm the API is healthy:

```bash
curl http://localhost:8080/health
```

Expected response:

```json
{"status":"healthy","service":"hapa-api","version":"1.0.0"}
```

flutter devices   # list connected devices
flutter run -d 162742562C020188 --dart-define=API_BASE_URL=http://192.168.1.67:8080


Useful Docker commands:

```bash
docker compose ps
docker compose logs -f backend
docker compose logs -f postgres redis meilisearch
docker compose down
```

To remove local service data and start fresh:

```bash
docker compose down -v
```

## Mobile Configuration

Configuration is read from compile-time Dart environment values in `lib/core/config/app_config.dart`.

Supported values:

| Define | Default | Notes |
| --- | --- | --- |
| `API_BASE_URL` | `http://10.0.2.2:8080` | Android emulator address for the host machine |
| `MAPBOX_TOKEN` | empty | Optional map token for features that need Mapbox |

### API Base URL By Target

Use the right API URL for where the app is running:

| Target | `API_BASE_URL` |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080` |
| iOS simulator | `http://localhost:8080` |
| Chrome/web development | `http://localhost:8080` |
| Physical device | `http://<your-computer-lan-ip>:8080` |

For a physical device, your phone and computer must be on the same network, and the backend must be reachable from the phone.

Find your local network IP:

```bash
hostname -I
```

On macOS:

```bash
ipconfig getifaddr en0
```

## First Run

Start the backend from the repository root:

```bash
cd ..
docker compose up --build
```

In a second terminal, run the mobile app:

```bash
cd mobile
flutter pub get
flutter run
```

The default `API_BASE_URL` works for Android emulator. For other targets, pass the API URL explicitly.

Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

iOS simulator:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Physical device:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.67:8080
```

With a Mapbox token:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=MAPBOX_TOKEN=your_mapbox_token
```

## Choosing A Device

List available devices:

```bash
flutter devices
```

Run on a specific device:

```bash
flutter run -d <device-id>
```

Common examples:

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

## Development Commands

Install dependencies:

```bash
flutter pub get
```

Analyze code:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Format code:

```bash
dart format lib test
```

Clean generated/build output:

```bash
flutter clean
flutter pub get
```

Run build runner when generated code is added or changed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Watch generated code during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Building

Android debug APK:

```bash
flutter build apk --debug
```

Android release APK:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=MAPBOX_TOKEN=your_mapbox_token
```

Android App Bundle:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=MAPBOX_TOKEN=your_mapbox_token
```

iOS release build:

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=MAPBOX_TOKEN=your_mapbox_token
```

Use production API URLs and real secrets for release builds. Do not commit private tokens or signing credentials.

## Local Backend Environment

The Docker stack provides development defaults:

```text
DATABASE_URL=postgres://hapa:hapa_secret@postgres:5432/hapa?sslmode=disable
REDIS_URL=redis://redis:6379
MEILI_URL=http://meilisearch:7700
MEILI_MASTER_KEY=hapa_meili_master_key
JWT_SECRET=hapa_jwt_secret_change_in_production
PORT=8080
ENV=development
```

Optional root-level environment values used by Docker Compose:

```text
CLAUDE_API_KEY=
MAPBOX_TOKEN=
```

Pass `MAPBOX_TOKEN` to Flutter separately with `--dart-define=MAPBOX_TOKEN=...` because Flutter compile-time defines are not read automatically from Docker Compose.

## Troubleshooting

### App Cannot Reach The API

- Make sure the backend is running: `docker compose ps`.
- Check health: `curl http://localhost:8080/health`.
- Use `http://10.0.2.2:8080` for Android emulator.
- Use `http://localhost:8080` for iOS simulator.
- Use your computer LAN IP for physical devices.
- Confirm your firewall allows connections to port `8080`.

### Database Or Cache Is Unhealthy

Inspect service logs:

```bash
docker compose logs -f postgres redis backend
```

If you need a clean local database:

```bash
docker compose down -v
docker compose up --build
```

### Dependencies Look Broken

Refresh Flutter dependencies:

```bash
cd mobile
flutter clean
flutter pub get
```

### Location Features Do Not Work

- Run on a simulator/emulator with a configured mock location, or use a physical device.
- Grant location permission when prompted.
- Android and iOS permission copy/config may need to be expanded before production release.

### iOS Build Issues

From `mobile/ios`:

```bash
pod install
```

Then return to `mobile` and run:

```bash
flutter run -d ios
```

## Notes For Contributors

- Keep app-wide constants in `lib/core/config/app_config.dart`.
- Keep HTTP concerns in `lib/core/api/api_client.dart`.
- Prefer Riverpod providers for app state and service access.
- Keep shared model changes compatible with backend API payloads.
- Run `flutter analyze` and `flutter test` before opening a pull request.
