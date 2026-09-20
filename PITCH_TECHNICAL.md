# WhiteMountain — Technical Pitch

> **Outdoor travel. Never lose anyone.**
> A full-stack travel & emergency-response platform that keeps groups together —
> and keeps working when the network doesn't.

---

## 1. The problem

Outdoor groups scatter. Trails fork, pace diverges, and the one thing every trip
depends on — connectivity — is the first thing to fail in the mountains. Today's
tools assume a signal: they show a dot when the internet works and go blank when
it matters most. The result is guides searching blind, members separated with no
way to signal, and rescue delayed by hours.

WhiteMountain is built around the opposite assumption: **assume the network will
fail, and design the safety net around that.**

## 2. What it does

| # | Capability | Why it matters |
| :-: | :--- | :--- |
| 1 | **Live group telemetry** | Every member on one live map, streamed over WebSockets with spatial history. |
| 2 | **Offline-first mesh** | Devices keep talking directly when there is no cell signal. |
| 3 | **BLE proximity radar** | Find a missing member by signal strength, in the last few metres. |
| 4 | **Multi-channel emergency escalation** | One tap fans out until a human answers. |
| 5 | **AI destination agent** | A scored, day-by-day itinerary from real weather, places and routes. |

## 3. Architecture

```
┌────────────────────────────── Flutter app (Android) ──────────────────────────────┐
│   REST (Dio)               WebSocket (Socket.IO)          MethodChannel / EventChannel │
└───────┬───────────────────────────┬───────────────────────────────┬────────────────┘
        ▼                           ▼                               ▼
┌─────────────────┐      ┌────────────────────┐        ┌───────────────────────────────┐
│ Fastify REST API│      │ Socket.IO gateway  │        │ Native Kotlin services        │
│  JWT + roles    │      │  rooms: group:{id} │        │ LocationTracker · NearbyMesh  │
│                 │      │         user:{id}   │        │ HotspotService               │
└───────┬─────────┘      │  Redis pub/sub     │        └───────────────────────────────┘
        │                └─────────┬──────────┘
        ▼                          ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│ PostGIS (spatial truth) · Redis (live cache + queues + pub/sub) · MinIO (media)     │
│ Emergency engine → FCM → guides | Telegram → rescue channel | Nearby-user fan-out    │
│ BullMQ worker → Gemini destination agent                                             │
└────────────────────────────────────────────────────────────────────────────────────┘
```

One Flutter client, one Fastify backend, one native Android layer. REST for state,
Socket.IO for motion, MethodChannels for the hardware the web can't reach — GPS,
BLE, Wi-Fi hotspot, Nearby Connections.

## 4. The hard parts

### 4.1 Live telemetry that scales past a single server

Position updates are the highest-frequency traffic in the system, so they never
touch the database on the hot path. Each `location:update` writes **Redis GEO**
(`group:{id}:locations`) plus a **user hash**, both with a **1-hour TTL**, and is
relayed to the group room. A buffer flushes to `location_history` every **15 s**,
turning thousands of writes into a handful. The Socket.IO gateway runs a **Redis
adapter** and joins every socket to `group:{id}` and `user:{id}` rooms, so the
realtime layer scales horizontally instead of pinning to one process.

### 4.2 Offline-first mesh

When the internet check fails, the guide starts a **local-only Wi-Fi hotspot**
(Android `WifiNetworkSpecifier` for members to join) and the app advertises over
**Google Nearby Connections** (`P2P_CLUSTER`, service id `com.example.tt.MESH_RELAY`).
Telemetry is persisted to a local **sqflite ledger**; a **Workmanager** task retries
`/telemetry/mesh-sync` every 15 minutes until a link returns. The server treats a
relayed record as a **Good Samaritan upload** — it validates timestamps, persists
`location_history` with a `synced_by` provenance column, and emits
`member:location_recovered`. A missing member's last known positions can therefore
be reconstructed from their peers' devices.

### 4.3 BLE proximity radar

Telemetry tells you roughly where someone is; the radar closes the final metres.
The native tracker continuously **advertises an 8-byte identity token** as BLE
manufacturer data (company id `0xFFFF`). The radar screen scans for the missing
member's token, maps RSSI to human labels (Very close / Nearby / In range), and
refreshes every 10 s. When GPS degrades, the tracker switches to **dead reckoning** —
step detector plus rotation vector, a 0.75 m stride along heading — so the signal
keeps moving even when satellites drop.

### 4.4 Emergency escalation

`POST /emergency/trigger` runs a cascade, not a single notification:

1. **In-app** — `emergency:distress` broadcast to the group room.
2. **Nearby users** — geo radius fan-out (`georadius`, `SOS_RADIUS_KM` = 20) to
   non-members as `emergency:nearby`.
3. **Guides** — FCM multicast to every guide's registered device token.
4. **Rescue channel** — a Telegram HTML card with Google Maps + OpenStreetMap links,
   its `message_id` stored for lifecycle tracking.

Alerts have a real state machine (`ACTIVE → RESOLVED/CANCELLED`) and a member-only
`/resolve`, so the channel isn't just a pager — it's a two-way incident record.

### 4.5 AI destination agent

The differentiator judges can see end-to-end. `POST /destinations/generate`
SHA-256–dedupes the request, returns `202` immediately, and enqueues a **BullMQ**
job (concurrency 2, rate-limited 10/min). The orchestrator then:

- gathers weather, places, events, safety, tourism and transport in **parallel**
  (`Promise.allSettled` — a failing provider becomes a warning, never a crash);
- normalizes and caches each source with type-specific TTLs;
- computes pairwise drive routes among the top 10 places and elevation for the top;
- **scores** candidates with a weighted model (interest match 0.30, route fit 0.15,
  weather fit 0.15, opening-hours fit 0.10, popularity 0.10) and filters by budget;
- generates the itinerary with **Gemini 2.0 Flash** in JSON mode under 12 strict
  prompt rules — use only supplied data, `null` for missing, reference `placeId`;
- validates the output, persists the itinerary plus **data-provenance snapshots**,
  and pushes `generation:completed` to the user's room.

Result: a scored, day-by-day plan grounded in verifiable data — not a hallucinated
list of landmarks.

## 5. Spatial data design

PostGIS is the source of truth, not a bolt-on. Planned and recorded routes are
`LineString 4326` with stored bounding-box polygons; activities, telemetry and SOS
alerts are `Point 4326`, all **GiST-indexed**. Discovery uses `ST_DWithin` (radius
feeds) and `ST_MakeEnvelope` (map-viewport queries); recorded tracks are simplified
with `ST_Simplify` before storage — compact geometry, honest distance.

## 6. Resilience as a design principle

Nearly every database and Redis call has an **in-memory fallback**
(`inMemoryUsers/Groups/Plans/Routes` plus an `InMemoryRedisMock` implementing
GEO operations with haversine math). The API boots and the test suite passes with
**no Postgres, Redis or MinIO running**. In a hackathon — and in a mountain hut —
that means "demo fails gracefully" is the default, not a hope.

## 7. Tech stack

| Layer | Technology |
| :--- | :--- |
| Mobile | Flutter (Dart) · Riverpod · go_router · MapLibre GL |
| Native | Kotlin · foreground location service · Nearby Connections · BLE · Wi-Fi hotspot |
| Backend | Node.js 20 (TypeScript, ESM) · Fastify 5 · Zod · Socket.IO |
| Data | PostgreSQL 16 + PostGIS 3.4 · Redis 7 · MinIO (presigned S3) |
| AI / external | Google Gemini 2.0 Flash · Places v1 · Routes v2 · Open-Meteo |
| Delivery | FCM · Telegram Bot API · JWT · Docker Compose |
| Quality | Vitest + supertest (backend) · flutter_test (app) |

## 8. Demo script

The 41-second intro reel mirrors the pitch one scene at a time:

| Scene | On screen | Under the hood |
| :--- | :--- | :--- |
| 1 | Brand + tagline | — |
| 2 | Every member on one live map | Socket.IO + Redis GEO + PostGIS history |
| 3 | No signal, no problem | Nearby Connections + local hotspot + mesh ledger |
| 4 | Find them by signal strength | BLE advertising + RSSI radar + dead reckoning |
| 5 | Four channels of escalation | Group → nearby → FCM → Telegram |
| 6 | A plan for tomorrow | BullMQ + parallel gather + Gemini scoring |
| 7 | Closing stack badges | Flutter · Fastify · PostGIS · Redis · MinIO · Gemini |

## 9. Status & roadmap

**Shipped:** auth & roles, expeditions lifecycle (PENDING/ONGOING/COMPLETED),
live telemetry and history, offline mesh + ledger sync, BLE radar, native dead
reckoning, multi-channel emergency escalation, spatial discovery feed, presigned
media, and the queued AI destination agent.

**In progress / known gaps (honest list):**

- Offline map tiles download but aren't yet injected into the MapLibre style.
- Deep-link handler exists in Dart; the Android intent-filter is still missing.
- Tourism / safety / transport / events providers are stubs (`manual` defaults).
- No server-side image thumbnailing yet; some LAN endpoints are hard-coded for demo.

**Next:** wire offline tiles into the style, complete the intent-filter, replace
stub providers with live sources, and add gateway/destination-agent test coverage.

## 10. Why it wins

- **It solves the failure case, not the happy path.** Mesh, radar and escalation
  target exactly the moment every other app goes silent.
- **It's real, not mocked.** PostGIS spatial queries, a horizontal realtime layer,
  a queued AI pipeline with caching and provenance, and native hardware channels —
  all running in one Docker Compose stack.
- **It degrades gracefully.** In-memory fallbacks mean the system is demonstrable
  anywhere, under any conditions.
- **It tells one story.** One tap from a live map to a rescue channel, with an AI
  plan for the day after — a coherent product, not a feature list.
