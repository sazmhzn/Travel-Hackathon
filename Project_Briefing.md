# WhiteMountain — Project Briefing

> Comprehensive feature & sub-feature reference for the **WhiteMountain** travel & emergency platform
> (repository: `Travel-Hackathon`, app codename **`tt`**).

**Document status:** Generated from a full source analysis
**Components covered:** Flutter client (`TT/`), Fastify backend (`tt backend/tt/`), native Android layer, design tooling
**Audience:** Developers, reviewers, and hackathon evaluators

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Backend Features](#3-backend-features)
4. [Flutter App Features](#4-flutter-app-features)
5. [Native Android Layer](#5-native-android-layer)
6. [Feature Status Matrix](#6-feature-status-matrix)
7. [Known Gaps & Stubs](#7-known-gaps--stubs)
8. [Appendix](#8-appendix)

---

## 1. Project Overview

### 1.1 What it is

WhiteMountain is a full-stack **outdoor travel and emergency-response platform**. It lets guides create
expeditions, share planned routes, and track group members in real time; lets travelers record and share
routes and media; and provides a layered **rescue system** that works even when the internet fails.

The distinguishing feature set:

- **Live group telemetry** over WebSockets with PostGIS-backed history.
- **Offline-first mesh networking** between nearby devices (Android Nearby Connections + local Wi-Fi hotspot).
- **BLE proximity radar** to physically locate a missing group member by signal strength.
- **Multi-channel emergency escalation** (in-app broadcast → nearby-user fan-out → FCM push to guides → Telegram rescue channel).
- **AI destination agent** that collects weather/places/routes data and synthesizes a scored, day-by-day itinerary via Google Gemini.

### 1.2 Repository layout

```
WhiteMountain/
├── TT/                        # Flutter mobile app (Android)
│   ├── lib/
│   │   ├── core/              # API client, sockets, router, theme, local DB, identity, background sync
│   │   ├── features/          # auth, onboarding, map, groups, emergency, mesh, routes, social, profile
│   │   └── shared/            # navigation shell
│   ├── android/app/src/main/kotlin/com/example/tt/   # native Kotlin services
│   └── test/                  # widget/regression tests
├── tt backend/tt/             # Node.js + TypeScript backend
│   ├── src/
│   │   ├── modules/           # auth, groups, plans, routes, telemetry, emergency, feed, storage, destination-agent
│   │   ├── sockets/           # Socket.IO gateway
│   │   ├── database/          # pool, migrator, migrations/*.sql
│   │   ├── config/            # env, database, redis, minio, firebase
│   │   └── utils/             # geojson, logger
│   ├── tests/                 # Vitest + supertest suites
│   ├── projectDocuments/      # requirements & status reports
│   └── docker-compose.yml     # PostGIS, Redis, MinIO, API
└── design/figma-plugin/       # Figma helper plugin (dev tooling)
```

### 1.3 Tech stack

| Layer | Technology |
| :--- | :--- |
| Mobile app | Flutter (Dart SDK ^3.12.2), Android (Kotlin, `compileSdk 36`) |
| App state/routing | Riverpod, go_router |
| Map & geo | MapLibre GL, `turf` (Dart), MapLibre openfreemap Liberty style |
| Local storage | `sqflite` (2 DBs), `shared_preferences` |
| Realtime client | `socket_io_client`, `app_links`, `flutter_blue_plus`, `flutter_local_notifications`, `workmanager` |
| Backend runtime | Node.js 20+ (TypeScript, ESM), Fastify 5 |
| Spatial DB | PostgreSQL 16 + PostGIS 3.4 |
| Cache / pub-sub / queue | Redis 7, BullMQ, Socket.IO Redis adapter |
| Object storage | MinIO (S3-compatible, presigned URLs) |
| AI | Google Gemini 2.0 Flash |
| External APIs | Google Places v1, Google Routes v2, Open-Meteo (weather + elevation) |
| Emergency delivery | Firebase Cloud Messaging, Telegram Bot API |
| Auth | JWT (`@fastify/jwt`), bcrypt |
| Validation / docs | Zod, `@fastify/swagger` + Swagger UI at `/docs` |
| Testing | Vitest + supertest (backend), flutter_test (app) |

---

## 2. System Architecture

### 2.1 High-level diagram

```
[ Flutter App (Android) ]
   │  HTTP REST (Dio)              │  WebSocket (Socket.IO)         │ MethodChannel / EventChannel
   ▼                               ▼                                ▼
[ Fastify REST API ] ─────── [ Socket.IO Gateway ]          [ Native Kotlin Services ]
   │                               │                    LocationTracker · NearbyMesh · Hotspot
   ├── JWT auth + role auth        ├── Redis Pub/Sub adapter (scale-out)
   ├── PostGIS: LineString/Point    ├── Rooms: group:{id}, user:{id}
   │   ST_DWithin, ST_MakeEnvelope  └── Live telemetry relay
   ├── Redis: GEO + hash, 1h TTL
   ├── MinIO: presigned S3
   ├── BullMQ: destination generation queue
   └── Emergency engine
         ├── FCM → Guides
         ├── Telegram → Rescue channel
         └── Nearby-user fan-out
```

### 2.2 Backend request lifecycle

1. `index.ts` → connect Redis → check/connect PostgreSQL → run migrations → ensure MinIO bucket.
2. If `DESTINATION_AGENT_ENABLED`, start the BullMQ destination worker.
3. `buildApp()` registers plugins/modules; Socket.IO attaches to the raw HTTP server.
4. Graceful shutdown on SIGINT/SIGTERM stops the worker then closes Fastify.

### 2.3 Resilience design

Nearly every database and Redis call has an **in-memory fallback** (`inMemoryUsers`, `inMemoryGroups`,
`inMemoryPlans`, `inMemoryActivities`, `inMemoryRoutes`, plus `InMemoryRedisMock` implementing `set/get/hset/
hgetall/expire/geoadd/geopos/georadius/del/ping` with haversine math). The server boots and the test suite
passes without Postgres, Redis, or MinIO running.

### 2.4 Authentication model

- **REST:** global `authenticate` preHandler hook on groups, telemetry, emergency, storage; per-route on auth
  `me`/`fcm-token`, plans create, feed create, destinations, routes record. `requireRole(['GUIDE','ADMIN'])` is
  used only for `POST /api/routes/record`.
- **Roles:** `GUIDE`, `MEMBER`, `ADMIN`.
- **JWT:** 7-day tokens signed with `JWT_SECRET`.
- **Socket.IO:** separate handshake verification against the same secret (`handshake.auth.token` or `Authorization` header).

---

## 3. Backend Features

Stack root: `tt backend/tt/src`. Base path: `/api`. Swagger UI: `http://localhost:3000/docs`.

### 3.1 Authentication & Identity — `/api/auth`

| Sub-feature | Endpoint | Auth | Detail |
| :--- | :--- | :--- | :--- |
| User registration | `POST /register` | Public | name, email, password (≥6), phone; role `GUIDE`/`MEMBER` (default MEMBER); optional `deviceId`, `bluetoothName`; bcrypt hash; returns user + JWT |
| Login | `POST /login` | Public | Email/password; binds device identity on login; returns 7-day JWT |
| Profile | `GET /me` | Bearer | Authenticated user profile |
| Push token registration | `PUT /fcm-token` | Bearer | Stores `users.fcm_token` for emergency push |
| Role guard | — | — | `requireRole(allowed[])` → 403 when role not permitted |
| Device identity | — | — | `users.device_id` / `users.bluetooth_name` used by mesh + radar |

### 3.2 Expeditions / Groups — `/api/groups`

All routes require a Bearer token. Guide-only actions are enforced in service logic.

| Sub-feature | Endpoint | Detail |
| :--- | :--- | :--- |
| Create expedition | `POST /` | name (≥3), description; creator auto-added as `GUIDE`; unique 8-char invite code |
| Join by code | `POST /join` | Uppercased invite code; rejects `COMPLETED`; idempotent; emits `group:member_joined` |
| My expeditions | `GET /my-groups` | Groups for the user; **guides with zero groups get 3 seeded demo expeditions + roster** |
| Browse | `GET /browse` | PENDING + COMPLETED only (never ONGOING); invite code masked for non-members |
| Expedition details | `GET /:groupId` | Group + memberCount/guideCount/onlineCount/missingCount; enriched members with live telemetry and `isMissing` |
| Set status | `PATCH /:groupId/status` | `PENDING`/`ONGOING`/`COMPLETED`; enforces one ONGOING per guide (409); reactivation clears members (except owner) and hotspot |
| Edit expedition | `PATCH /:groupId` | Update name/description |
| Hotspot credentials | `PATCH /:groupId/hotspot` | Store guide's local Wi-Fi `ssid` + `password` for offline sharing |
| Member list | `GET /:groupId/members` | Members with name/email/phone/fcm_token/device_id/bluetooth_name |
| Remove member | `DELETE /:groupId/members/:userId` | Guide-only; guides cannot be removed; emits removal events |

### 3.3 Travel Plans — `/api/plans`

| Sub-feature | Endpoint | Auth | Detail |
| :--- | :--- | :--- | :--- |
| Upload plan | `POST /` | Bearer | GeoJSON **or** GPX payload; parsed to LineString 4326; computes distance, elevation gain, bbox polygon; broadcasts `PlanUpdate` |
| Map data (bbox) | `GET /map-data` | Public | `ST_Intersects` with `ST_MakeEnvelope` over routes + public activities |
| Get plan | `GET /:planId` | Public | Plan with GeoJSON route + bounding box |
| Group plans | `GET /group/:groupId` | Public | Plans for a group, newest first |

### 3.4 Recorded Routes — `/api/routes`

| Sub-feature | Endpoint | Auth | Detail |
| :--- | :--- | :--- | :--- |
| Record route | `POST /record` | Guide/Admin | GeoJSON LineString; PostGIS `ST_GeomFromGeoJSON` → `ST_Simplify` → `ST_Envelope` → geographic length; optional `group_id`; broadcasts `route:recorded` |
| Group routes | `GET /group/:groupId` | Public | Routes recorded for an expedition |
| Get route | `GET /:id` | Public | Route path GeoJSON + bounding box |

### 3.5 Real-Time Telemetry — `/api/telemetry`

| Sub-feature | Endpoint | Detail |
| :--- | :--- | :--- |
| Ingest location | `POST /location` | Also via Socket.IO; writes Redis GEO (`group:{id}:locations`), hash (`user:{id}:telemetry`), global index; 1h TTL; buffers for batch DB write |
| Live group view | `GET /group/:groupId/live` | Reads cached geo/hash data enriched with member name/role/phone |
| Mesh ledger upload | `POST /mesh-sync` | Good Samaritan relay: validates timestamps, persists `location_history` with `synced_by`, emits `member:location_recovered` |
| Batch persistence | — | In-memory buffer flushed to `location_history` every 15 s |
| Radius lookup | — | `georadius ... WITHDIST ASC` for nearby-user fan-out |

### 3.6 Social Feed & Spatial Discovery — `/api/feed`

| Sub-feature | Endpoint | Auth | Detail |
| :--- | :--- | :--- | :--- |
| Radius feed | `GET /` | Optional | `ST_DWithin` around lat/lng (default 50 km); privacy filter `PUBLIC` vs `GROUP_ONLY` (user's groups); returns activities (LIMIT 50) + routes (LIMIT 20) |
| Drop activity pin | `POST /activities` | Bearer | Waypoint/scenic marker with coordinates, visibility, and MinIO media URLs |

### 3.7 Emergency & Rescue — `/api/emergency`

| Sub-feature | Endpoint | Detail |
| :--- | :--- | :--- |
| Trigger rescue mode | `POST /trigger` | Creates `emergency_triggers` (ACTIVE); broadcasts `emergency:distress` to group; fans out `emergency:nearby` to non-member users within `SOS_RADIUS_KM`; posts Telegram HTML card with Google Maps + OSM links; multicasts FCM to guides |
| Resolve alert | `POST /resolve` | Member-only; ACTIVE → RESOLVED with `resolved_at`; broadcasts `emergency:resolved` |
| Alert persistence | — | Status lifecycle `ACTIVE`/`RESOLVED`/`CANCELLED`, `telegram_message_id` stored |

### 3.8 Media Storage — `/api/storage`

| Sub-feature | Endpoint | Detail |
| :--- | :--- | :--- |
| Presigned upload | `POST /presigned-upload` | fileName + contentType → `{uploadUrl, fileKey, publicUrl}`, 1h expiry |
| Presigned download | `GET /presigned-download` | `fileKey` → `{downloadUrl}`, 1h expiry |
| Bucket bootstrap | — | `ensureBucketExists()` creates public `travel-media` on startup |

### 3.9 Destination Agent (AI Itinerary) — `/api/destinations`

An asynchronous, queued, cache-aware AI pipeline that produces a scored, day-by-day travel itinerary.

#### 3.9.1 Endpoints

| Sub-feature | Endpoint | Detail |
| :--- | :--- | :--- |
| Generate itinerary | `POST /generate` | destination, startDate, endDate, preferences (interests, budget, transport, travelStyle); deduped by SHA-256 request hash; enqueues BullMQ job → 202 `{generationId, status: QUEUED}` |
| Job status | `GET /generation/:jobId` | status, timestamps, error, destinationId |
| Fetch itinerary | `GET /itinerary/:generationId` | Completed generation + items |
| History | `GET /my-generations` | User's past generations (limit 1–100, default 20) |
| Search destinations | `GET /search` | `ILIKE` on name/normalized_name |
| Get destination | `GET /:destinationId` | Destination record by UUID |

#### 3.9.2 Pipeline (orchestrator)

1. Find-or-create destination (unique `normalized_name`).
2. Resolve stored lat/lng (**no geocoding in V1**; coordinate-dependent providers skipped if null).
3. Compute request hash; return cached result if present.
4. **Parallel data collection** (`Promise.allSettled`, failures become warnings, never throw):
   weather (Open-Meteo), places (Google Places, 10 km radius by interest), events, tourism, safety, transport.
5. Normalize weather + places; cache both.
6. Fetch place details for each result.
7. Compute pairwise drive routes among the top 10 places (Google Routes, cached).
8. Fetch elevation for the top place (Open-Meteo, 30-day cache).
9. **Score** candidates and filter by budget preference.
10. **Generate** itinerary with Gemini 2.0 Flash (JSON response mode) using all collected context.
11. Validate: unknown `placeId` references, start times before opening hours.
12. Persist generation + flattened items; record data-provenance snapshots (weather/places/events/safety/transport/tourism).
13. Return `{generationId, itinerary, destinationId, warnings}`; cache full result 3600 s.

#### 3.9.3 Sub-components

| Sub-feature | Component | Detail |
| :--- | :--- | :--- |
| Orchestration | `destination.orchestrator.ts` | Parallel gather → normalize → route/elevation → score → AI → validate → persist |
| Service | `destination.service.ts` | Job dedupe by `request_hash`, enqueue, status/history queries |
| Repository | `destination.repository.ts` | Destinations, places, snapshots, jobs, generations, items |
| AI client | `ai/gemini.service.ts` | Gemini 2.0 Flash, schema validation via Zod, descriptive failures |
| Prompt | `ai/itinerary.prompt.ts` | 12 strict rules: use only supplied data, null for missing, reference `placeId`, respect style/budget/weather/hours, prioritize scored candidates |
| Schema | `schemas/destination.schema.ts` | Zod models for places, weather, routes, elevation, events, safety, tourism, transport, preferences, itinerary |
| Scoring | `scoring/destination-scoring.service.ts` | Weighted model: interestMatch 0.30, routeFit 0.15, weatherFit 0.15, openingHoursFit 0.10, popularity 0.10; normalized 0–1; budget price-level filter |
| Cache | `cache/destination-cache.service.ts` | Redis or in-process; TTLs by data type (weather 30m, places 12h, routes 2h, elevation 30d, safety 15m) |
| Queue/Worker | `workers/destination-generation.worker.ts` | BullMQ concurrency 2, rate limit 10/min; emits `generation:completed` / `generation:failed` to the user room |
| Weather provider | `open-meteo.provider.ts` | Daily temp/precip/wind, WMO code mapping, sun times |
| Elevation provider | `google-elevation.provider.ts` | Open-Meteo elevation API |
| Places provider | `google-places.provider.ts` | `places:searchNearby` + details (hours, website, phone); price-level mapping |
| Routes provider | `google-routes.provider.ts` | `computeRoutes` for drive/walk/bicycle/two-wheeler |
| Stub providers | tourism / safety / transport / events | Return empty defaults (`manual` provider) — extension points |
| Normalization | `normalization/*.ts` | Canonical category, weather-condition, event-category, transport-type mapping |

### 3.10 Socket.IO Real-Time Gateway (`src/sockets/gateway.ts`)

Rooms: `group:{groupId}` and `user:{userId}` (auto-joined). JWT verified at handshake; Redis adapter for multi-instance scale.

**Client → Server**

| Event | Payload | Effect |
| :--- | :--- | :--- |
| `join_group` | `{groupId}` | Join room; emit `member:joined` to others |
| `leave_group` | `{groupId}` | Leave room; emit `member:left` |
| `location:update` | `{groupId, lat, lng, altitude?, speed?, battery?, timestamp?}` | Ingest + broadcast `member:location` |
| `plan:ack` | `{planId, groupId}` | Receipt acknowledgement (logged) |

**Server → Client**

| Event | Payload |
| :--- | :--- |
| `member:joined` / `member:left` | `{userId, timestamp}` |
| `member:location` | `{userId, lat, lng, altitude?, speed?, battery?, timestamp}` |
| `group:member_joined` / `group:member_removed` | `{groupId, userId}` |
| `group:updated` | `{groupId}` |
| `group:removed` (user room) | `{groupId}` |
| `PlanUpdate` | `{planId, groupId, title, route, totalDistanceMeters}` |
| `member:location_recovered` | `{userId, lat, lng, altitude, battery, recordedAt, relayedBy}` |
| `emergency:distress` | `{alertId, userId, userName, userPhone, lat, lng, battery, reason, timestamp}` |
| `emergency:nearby` | `{alertId, groupId, userId, userName, lat, lng, distanceKm, radiusKm, reason, timestamp}` |
| `emergency:resolved` | `{groupId, userId, alertIds, timestamp}` |
| `route:recorded` | `{groupId, routeId}` |
| `generation:completed` / `generation:failed` (user room) | `{jobId, generationId, destination, warnings}` / `{jobId, error}` |

### 3.11 Database Schema (PostGIS, migrations 001–008)

Extensions: `uuid-ossp`, `postgis`. Migrations auto-run on startup in per-file transactions.

| Table | Purpose | Key spatial columns |
| :--- | :--- | :--- |
| `users` | Accounts, roles, FCM token, device identity | — |
| `groups` | Expeditions, invite code, status, hotspot credentials | — |
| `group_members` | Membership + role, unique (group,user) | — |
| `travel_plans` | Planned routes + bbox | `route LineString 4326`, `bounding_box Polygon` (GiST) |
| `activities` | Social feed pins, media, visibility | `location Point 4326` (GiST) |
| `location_history` | Telemetry archive + mesh relay records | `location Point 4326` (GiST) |
| `emergency_triggers` | SOS alerts lifecycle | `location Point 4326` |
| `routes` | Recorded guide routes | `path LineString 4326`, `bounding_box Polygon` |
| `destinations` | AI agent destinations | — |
| `places` | Normalized provider places | `location Point 4326` |
| `destination_data_snapshots` | Provider provenance records | — |
| `transport_operators` / `transport_options` | Transport data | — |
| `destination_events` | Event data | `location Point 4326` |
| `itinerary_generations` / `itinerary_items` | AI output + flattened days | — |
| `destination_generation_jobs` | Queue job state | — |
| `schema_migrations` | Migration tracking | — |

### 3.12 Config, integrations & infra

- **Env (`config/env.ts`, Zod-validated):** `PORT`, `HOST`, `NODE_ENV`, `JWT_SECRET` (required, ≥16),
  DB (`DATABASE_URL`/`DB_*`, `DB_SSL`), Redis (`REDIS_*`), MinIO (`MINIO_*`), `TELEGRAM_BOT_TOKEN`,
  `TELEGRAM_EMERGENCY_CHAT_ID`, `FIREBASE_SERVICE_ACCOUNT_KEY`, `MISSING_THRESHOLD_SECONDS` (5),
  `SOS_RADIUS_KM` (20), `DESTINATION_AGENT_ENABLED`, `GOOGLE_GEMINI_API_KEY`,
  `GOOGLE_PLACES_API_KEY`, `GOOGLE_ROUTES_API_KEY`.
- **Docker Compose:** `travel_postgis` (postgis:16-3.4), `travel_redis` (AOF), `travel_minio` (+ `minio-init`
  bucket bootstrap), `travel_api` (port 3000). MinIO console on 9001.
- **Utils:** `geojson.ts` (GPX/GeoJSON parse → distance/elevation/bbox, WKT builders), `logger.ts` (Pino +
  pino-pretty; silent in tests).
- **Tests (Vitest + supertest):** geojson, auth, e2e, groups (largest), plans, telemetry, feed, emergency,
  routes. No coverage yet for storage, destination-agent, or the socket gateway.

---

## 4. Flutter App Features

Stack root: `TT/lib`. Entry point `main.dart` → initializes notifications, Workmanager periodic sync,
then `ProviderScope → MaterialApp.router`.

### 4.1 App Shell, Routing & Theme

| Sub-feature | Detail |
| :--- | :--- |
| Router | `go_router`, shell navigator; `initialLocation: /login` |
| Auth guard | Redirect based on `jwt_token` presence (`/login`↔`/groups`) |
| Routes | `/login`, `/register`, `/onboarding`, `/profile`, `/expedition/:groupId`, `/groups`, `/map?expeditionId=`, `/radar` |
| Tab shell | `MainNavigationWrapper` with 3 tabs: **Map**, **Expeditions**, **Radar** |
| Theme | Material 3, seed deep teal `#0F766E`, accent orange `#EA580C`, success/danger tokens; 52px min button height (regression-fixed) |
| Notifications init | Off-path channel `off_path_channel` |
| Background sync init | Workmanager periodic task `com.example.tt.mesh_sync` every 15 min (network connected) |

### 4.2 Core Services (`lib/core`)

| Service | Sub-features |
| :--- | :--- |
| `api_client.dart` | Dio client; base URL `API_BASE_URL` dart-define (default `http://10.207.148.57:3000/api`); 10s timeouts; auto-attaches `Authorization: Bearer <jwt_token>`; 401 handler is a stub |
| `socket_service.dart` | Socket.IO client; hard-coded `ws://10.207.148.57:3000`; token via auth/header/query; streams: peer location, plan updates, emergency, nearby emergency, group events; emits `location:update`, `plan:ack`, join/leave group; auto-rejoin pending group |
| `app_theme.dart` | Design tokens and component themes |
| `device_identity.dart` | MethodChannel `com.example.tt/device_identity` → deviceId + Bluetooth name; persisted + fallback generated; `searchIdentifier` for radar/mesh |
| `database_provider.dart` | sqflite `tt_local.db` v2: `draft_routes`, `route_points` |
| `background_sync.dart` | Workmanager callback → `SyncManager.syncMeshTelemetry()` |

### 4.3 Auth (`features/auth`)

| Sub-feature | Detail |
| :--- | :--- |
| `AuthService` | login (stores token + profile), register (role), getProfile, logout, isAuthenticated |
| Login screen | Email/password, visibility toggle, loading, role-based redirect, error snackbar |
| Register screen | Name/email/password/phone + role dropdown (MEMBER joins by code / GUIDE creates expeditions) |

### 4.4 Onboarding (`features/onboarding`)

| Sub-feature | Detail |
| :--- | :--- |
| `OnboardingController` | Persists `destination_name`, bounding box (`min_lat/lng`, `max_lat/lng`), `onboarding_complete` |
| Onboarding screen | "Choose your region" with hard-coded regions (Kathmandu Valley, Pokhara, Everest); persists bounds → `/map`; download is UI-only |

### 4.5 Map (`features/map`)

The largest feature. `MapScreen` (`/map`) plus supporting services.

| Sub-feature | Service | Detail |
| :--- | :--- | :--- |
| Native location tracking | `location_tracking_service.dart` | MethodChannel `…/location_control`, EventChannel `…/location_updates`; starts socket; emits `location:update` using `active_group_id` |
| Offline map download | `offline_map_service.dart` | Presigned download of `.pmtiles` into `<docs>/map_data`; existence check; **not yet wired into render style** |
| Route rendering | `route_service.dart` | Fetches group route GeoJSON and plan GeoJSON; `extractPoints` helper; contains dead mock code |
| Off-path alerts | `off_path_calculator.dart` | `turf.pointToLineDistance` (50 m threshold), `nearestPointOnLine`, local notification |
| Hotspot control | `hotspot_service.dart` | MethodChannel `…/hotspot_control`: hasInternet, start/stop/connect/disconnect hotspot |
| Live map | `map_screen.dart` | MapLibre openfreemap style; route/recording/return-path layers |
| Live location | `map_screen.dart` | Centers on first fix; user marker colours (on-path blue, off-path red, recording green) |
| Off-path UI | `map_screen.dart` | Return-path line to nearest point when off-route (not while recording) |
| Roster & missing detection | `map_screen.dart` | Caches roster/status/threshold; 1s heartbeat watcher marks missing peers; red banner with distance |
| Peer markers | `map_screen.dart` | Guide blue, member pink, missing red (native circles) |
| Socket handling | `map_screen.dart` | Peer locations, `PlanUpdate` (orange route), SOS dialogs, group events/ejection |
| Offline mesh | `map_screen.dart` | Advertise/discover, targeted missing-member discovery, telemetry listener, hotspot credential auto-join |
| Connectivity | `map_screen.dart` | Internet check; guide starts local hotspot and broadcasts credentials over mesh |
| Deep links | `map_screen.dart` | `app://location?lat&lng` → magenta marker + camera animation |
| Offline map button | `map_screen.dart` | Downloads region pmtiles; shows offline pin |
| Route recording | `map_screen.dart` + `route_recording_service` | Guide-only FAB; start/stop; save dialog → GeoJSON upload |
| Rescue trigger | `map_screen.dart` + `emergency_service` | Orange FAB → `POST /emergency/trigger` (currently uses region center coords) |
| Track toggle | `map_screen.dart` | Requests permissions; starts/stops native tracking |

### 4.6 Expeditions / Groups (`features/groups`)

| Sub-feature | Service/Screen | Detail |
| :--- | :--- | :--- |
| Group API | `group_service.dart` | my-groups, browse, create, join, routes, details, status, hotspot, update, remove member; 409 → `ongoingExists` |
| List screen | `GroupListScreen` | Search, sort (newest/oldest/alphabetical), pinned Ongoing, guide FAB (create) / member FAB (join), status change, invite-code dialog, pull-to-refresh |
| Details screen | `GroupDetailsScreen` | Header + status pill + invite copy, "Use for navigation", stats (members/online/missing), guide controls, routes section, missing section, member list (role/battery), remove member |
| Widgets | `group_widgets.dart` | `StatusPill`, `StatTile`, `SectionHeader`, snack helper |
| Realtime | — | `groupEventStream` refetch + eject-on-removal |

### 4.7 Emergency Radar (`features/emergency`)

| Sub-feature | Detail |
| :--- | :--- |
| Rescue trigger | `emergency_service.triggerRescueMode(...)` → `POST /emergency/trigger` |
| Radar screen | `/radar`; BLE scan for missing members (company id `0xFFFF`, RSSI threshold −90, 10s refresh) |
| Target resolution | GUIDE watches active expedition missing members; MEMBER watches all groups |
| Identity matching | 8-byte token mirrors native advertise token (Android ID hex → bytes) |
| UI | Scope header, signal labels (Very close/Nearby/In range + dBm), scan toggle; permissions bluetoothScan/connect + location |

### 4.8 Mesh (`features/mesh`)

| Sub-feature | Detail |
| :--- | :--- |
| Mesh service | `mesh_network_service.dart`; MethodChannel `…/mesh_control`, EventChannel `…/mesh_updates`; advertise/discover/stop/broadcast |
| Payload routing | `hotspot_credentials` → hotspot stream; telemetry → peer stream + persist record |
| Telemetry model | `OfflineTelemetryRecord` |
| Sync manager | `sync_manager.dart`; sqflite `tt_telemetry.db` table `offline_telemetry_records`; `syncMeshTelemetry()` posts to `/telemetry/mesh-sync` and marks synced |
| Background sync | Workmanager 15-min periodic task |

### 4.9 Routes (`features/routes`)

| Sub-feature | Detail |
| :--- | :--- |
| Recording service | `route_recording_service.dart`; start (DraftRoute + first point), subscribe to location stream, stop (mark completed + sync) |
| Sync | Builds GeoJSON LineString → `POST /routes/record` → mark synced |
| Models | `DraftRoute`, `RoutePoint` |

### 4.10 Social (`features/social`)

| Sub-feature | Detail |
| :--- | :--- |
| Deep-link service | `deep_link_service.dart`; `app_links` initial + warm links; broadcast `uriStream` |
| Consumption | `MapScreen._setupDeepLinks()` (scheme `app`, host `location`) — **manifest intent-filter missing** |

### 4.11 Profile (`features/profile`)

| Sub-feature | Detail |
| :--- | :--- |
| Profile screen | `/profile`; loads/refreshes profile, header (initials, name, email, phone, role pill) |
| Navigation rows | Expeditions, Travel Map, Offline Maps, Proximity Radar |
| Account | Logout with confirmation → `/login` |

### 4.12 Client dependency mapping

| Package | Powers |
| :--- | :--- |
| `flutter_riverpod` | State/providers everywhere |
| `go_router` | Routing + shell |
| `maplibre_gl` | Map rendering/layers/markers |
| `sqflite` | Local route + telemetry DBs |
| `path_provider` | Offline tile directory |
| `dio` | HTTP + file downloads |
| `shared_preferences` | Token, identity, active group, cached roster/bounds |
| `turf` | Off-path distance, nearest point, peer distance |
| `flutter_local_notifications` | Off-path alerts |
| `permission_handler` | Runtime permissions |
| `flutter_blue_plus` | BLE radar scanning |
| `app_links` | Deep links |
| `socket_io_client` | Realtime events |
| `workmanager` | Periodic mesh telemetry sync |
| `camera` | Declared but unused |
| `location` | Declared but unused (native channel used instead) |

---

## 5. Native Android Layer

Root: `TT/android/app/src/main/kotlin/com/example/tt`. Package `com.example.tt`; label `tt`; `usesCleartextTraffic=true`.

### 5.1 Channels registered (`MainActivity.kt`)

| Channel | Type | Direction | Methods/Events |
| :--- | :--- | :--- | :--- |
| `com.example.tt/location_control` | MethodChannel | Dart→native | startTracking, stopTracking, isTracking |
| `com.example.tt/location_updates` | EventChannel | native→Dart | `{latitude, longitude, accuracy}` |
| `com.example.tt/mesh_control` | MethodChannel | Dart→native | startAdvertising, startDiscovery, stopMesh, broadcastPayload |
| `com.example.tt/mesh_updates` | EventChannel | native→Dart | Received JSON payload |
| `com.example.tt/hotspot_control` | MethodChannel | Dart→native | hasInternet, startHotspot, stopHotspot, connectToHotspot, disconnect |
| `com.example.tt/device_identity` | MethodChannel | Dart→native | getIdentity → `{deviceId, bluetoothName}` |

### 5.2 Services

| Service | Sub-features |
| :--- | :--- |
| `LocationTrackerService.kt` | Foreground service (`foregroundServiceType=location`, sticky notification, channel `LocationTrackerChannel`); GPS every 5s/0m; forwards to Flutter via static listener; sensor fusion (`TYPE_STEP_DETECTOR` + `TYPE_ROTATION_VECTOR`); **dead reckoning** when accuracy > 20m (0.75m stride along azimuth, accuracy degrades 1m/step); **BLE advertising** of identity as manufacturer data (company id `0xFFFF`, 8-byte token from Android ID) |
| `NearbyMeshService.kt` | Google Nearby Connections, strategy `P2P_CLUSTER`, service id `com.example.tt.MESH_RELAY`; advertising name = userId; auto-accept discovery; optional targeted discovery by identifier; `broadcastPayload` over connected endpoint |
| `HotspotService.kt` | Local-only Wi-Fi hotspot (API 26+, guide) returning `{ssid,password}`; member join via `WifiNetworkSpecifier` (API 29+); `hasInternet()` validated-network check; disconnect unbinds process network |
| `MainActivity.kt` | Registers channels/services; starts/stops foreground service; stops hotspot + network on destroy |

### 5.3 Manifest & build

- **Permissions:** INTERNET, FINE/COARSE/BACKGROUND_LOCATION, FOREGROUND_SERVICE(+LOCATION),
  POST_NOTIFICATIONS, ACTIVITY_RECOGNITION, BLUETOOTH_ADVERTISE/CONNECT/SCAN, ACCESS/CHANGE_WIFI_STATE,
  NEARBY_WIFI_DEVICES, ACCESS/CHANGE_NETWORK_STATE.
- **Declared service:** `.LocationTrackerService`.
- **Build:** compileSdk 36, Java/Kotlin 17, core library desugaring 2.1.4, `play-services-nearby:19.0.0`.

---

## 6. Feature Status Matrix

Status reflects the actual source analysis. Requirement IDs come from the backend/frontend requirement reports.

### 6.1 Backend requirements

| ID | Feature | Status |
| :--- | :--- | :--- |
| BE-1.1 | Backend service init (REST + WS) | Done |
| BE-1.2 | PostgreSQL + PostGIS | Done |
| BE-1.3 | Core schema (users/groups/activities) | Done |
| BE-1.4 | Spatial schema (plans/pins/history) | Done |
| BE-1.5 | MinIO storage + presigned URLs | Done |
| BE-2.1 | Group & role API | Done |
| BE-2.2 | Plan synchronization | Done |
| BE-2.3 | WebSocket telemetry setup | Done |
| BE-2.4 | Live location ingestion | Done |
| BE-3.1 | P2P ledger ingestion | Done |
| BE-3.2 | FCM alert integration | Done |
| BE-3.3 | Telegram emergency fallback | Done |
| BE-4.1 | Spatial discovery API | Done |
| BE-4.2 | Dedicated nearby active groups/guides | Partial (radius feed exists; no dedicated active-groups query) |
| BE-4.3 | Media compression / thumbnails | Gap (`sharp` not implemented) |
| Seq-1 | Server-side stray-distance alert | Gap (moved to client-side Turf) |
| Seq-2 | Mesh-to-cloud rescue sync | Done |
| **Beyond plan** | Destination Agent (AI itinerary, queue, scoring, caching) | Implemented (providers partly stub) |

### 6.2 Frontend requirements

| ID | Feature | Status |
| :--- | :--- | :--- |
| FE-1.1 | Flutter project init (Riverpod, go_router) | Done |
| FE-1.2 | First-launch onboarding (region bounds) | Done (download UI-only) |
| FE-1.3 | MapLibre GL integration | Done (remote style) |
| FE-1.4 | Offline map downloader | Partial (downloads; not rendered offline) |
| FE-2.1 | Render travel plans (polylines) | Done |
| FE-2.2 | Native background tracker | Done (Kotlin foreground service + dead reckoning) |
| FE-2.3 | Off-path calculation | Done (turf, 50m, local notification) |
| FE-2.4 | Sensor fusion (dead reckoning) | Done |
| FE-3.1 | Native P2P service | Done (Nearby Connections P2P_CLUSTER) |
| FE-3.2 | Telemetry ledger sync | Done |
| FE-3.3 | Rescue mode broadcast | Done |
| FE-3.4 | Proximity radar (RSSI) | Done (BLE, company id `0xFFFF`) |
| FE-4.1 | Deep link location sharing | Partial (coded; manifest intent-filter missing) |
| FE-4.2 | Record track & drop media pins | Partial (recording done; camera/media capture unused) |
| FE-4.3 | Offline sync queue | Done (sqflite + Workmanager) |

### 6.3 Additional implemented features (not in original plans)

- Expedition lifecycle (PENDING/ONGOING/COMPLETED) with one-ongoing-per-guide constraint and reactivation.
- Browse/join expeditions, invite-code masking, member removal, fallback demo expeditions.
- Local-only Wi-Fi hotspot credential sharing over mesh.
- Missing-member detection with configurable threshold + dual mechanism (heartbeat + BLE radar).
- Nearby-user SOS fan-out (`emergency:nearby`).
- Hosted/queued AI destination & itinerary generation with scoring, caching, and provenance.

---

## 7. Known Gaps & Stubs

| Area | Gap |
| :--- | :--- |
| Offline maps | `.pmtiles` are downloaded but never injected into the MapLibre style; map still uses remote `openfreemapLiberty`. Onboarding "download" only persists bounds. |
| Deep links | `app://location` handled in Dart, but `AndroidManifest.xml` has no intent-filter → non-functional end-to-end. |
| Auth resilience | `ApiClient` 401 handler is a stub (no refresh/redirect). |
| Config | Socket URL and API base URL hard-coded to LAN IP `10.207.148.57`. |
| Rescue accuracy | Rescue FAB sends region-center coords (`_initialTarget`), not the current GPS fix. |
| Telemetry fidelity | Socket location updates send mocked altitude/speed/battery (`0, 0, 100`). |
| Destination agent | No geocoding step (coords must be pre-seeded); tourism/safety/transport/events providers are stubs; some schema shapes diverge from provider payloads. |
| Backend processing | No image resizing/thumbnailing (`sharp` absent); no dedicated nearby-active-groups query; no server-side stray-distance check. |
| Security | `docker-compose.yml` and committed `.env` contain JWT secret and Google API keys; several read endpoints are public. |
| Dependencies | `camera` and `location` packages declared but unused. |
| Dead code | Mock route helpers in `route_service.dart`; native "boost" comment in `emergency_service.dart`. |
| Testing | No tests for storage, destination-agent, socket gateway, native bridges, off-path math, mesh, or socket streaming. |

---

## 8. Appendix

### 8.1 Backend environment variables

`PORT`, `HOST`, `NODE_ENV`, `JWT_SECRET`, `DATABASE_URL`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`,
`DB_NAME`, `DB_SSL`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `MINIO_ENDPOINT`, `MINIO_PORT`,
`MINIO_USE_SSL`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`, `MINIO_REGION`, `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_EMERGENCY_CHAT_ID`, `FIREBASE_SERVICE_ACCOUNT_KEY`, `MISSING_THRESHOLD_SECONDS`, `SOS_RADIUS_KM`,
`DESTINATION_AGENT_ENABLED`, `GOOGLE_GEMINI_API_KEY`, `GOOGLE_PLACES_API_KEY`, `GOOGLE_ROUTES_API_KEY`.

### 8.2 Run & verify

```powershell
# Backend (Docker, no hot reload — rebuild after changes)
docker compose up -d --build api
curl.exe -s http://localhost:3000/health

# Flutter app
flutter analyze lib
# API base URL override:
flutter run --dart-define=API_BASE_URL=http://<host>:3000/api
```

### 8.3 Key endpoints quick reference

| Method | Path | Purpose |
| :--- | :--- | :--- |
| POST | `/api/auth/register` · `/login` | Account |
| GET | `/api/auth/me` | Profile |
| POST/GET/PATCH/DELETE | `/api/groups/*` | Expeditions |
| POST/GET | `/api/plans/*` | Planned routes |
| POST/GET | `/api/routes/*` | Recorded routes |
| POST/GET | `/api/telemetry/*` | Live + mesh telemetry |
| POST/GET | `/api/emergency/*` | SOS |
| GET/POST | `/api/feed/*` | Social / pins |
| POST/GET | `/api/storage/*` | Presigned media |
| POST/GET | `/api/destinations/*` | AI itineraries |
| GET | `/docs` | Swagger UI |
| GET | `/health` | Health check |

---

*End of briefing.*
