# Backend Project Plan: Requirements Analysis & Status Report

**Document Version:** 1.0.0  
**Date:** September 17, 2026  
**Project Workspace:** `/home/subin/tt` (`travel-emergency-backend`)  
**Backend Stack:** Node.js 20+ (TypeScript), Fastify 5, PostGIS (PostgreSQL 16), Redis 7, Socket.io 4, MinIO S3 SDK, FCM, Telegram Bot API  

---

## 1. Executive Summary

This report evaluates the current codebase in `/home/subin/tt` against the **Backend Project Plan: Travel & Emergency App**.

### Key Findings:
- **Total Backend Tasks Evaluated:** 15 Tasks + 2 Sequence Flows.
- **Completed Tasks (DONE):** **13 Tasks (86.7%)**.
- **Partially Implemented / Requiring Expansion:** **2 Tasks (13.3%)** (`BE-4.2`, `BE-4.3`).
- **Production Infrastructure:** Fully containerized via `docker-compose.yml` with health checks for PostgreSQL/PostGIS, Redis, MinIO, and the Fastify API.

---

## 2. System Architecture Assessment

```
graph TD
    A[Client App] --> B[API Gateway / Load Balancer]
    B --> C[Node.js / Go API Server]
    B --> D[MQTT Broker - Mosquitto]
    
    C --> E[(PostgreSQL + PostGIS)]
    C --> F[MinIO Object Storage]
    
    D --> C
    
    C --> G[Firebase Cloud Messaging]
    C --> H[Telegram Bot API - Rescuers]
```

### Component Status Matrix

| Component | Target Technology | Implemented In Repository | Status | Implementation Details |
| :--- | :--- | :--- | :---: | :--- |
| **A. Client App** | Mobile (Flutter) | Not in this workspace | **External** | Backend exposes documented REST & Socket.io APIs for Flutter integration. |
| **B. API Gateway / Router** | Reverse Proxy / Fastify | Fastify 5 (`src/app.ts`) | **DONE** | Port 3000, CORS enabled (`@fastify/cors`), Swagger UI documentation at `/docs`. |
| **C. API Server** | Node.js / Go | Node.js 20+ TypeScript (`src/index.ts`) | **DONE** | Modular architecture (auth, groups, plans, telemetry, emergency, feed, storage). |
| **D. Telemetry Broker** | Mosquitto / WebSockets | Socket.io 4 + Redis Adapter (`src/sockets/gateway.ts`) | **DONE** | WebSocket bi-directional streaming with Redis Pub/Sub adapter for multi-instance horizontal scaling. |
| **E. Spatial Database** | PostgreSQL 16 + PostGIS 3.4 | PostGIS Docker (`travel_postgis`) | **DONE** | PostGIS extensions enabled; LineString 4326 for routes, Point 4326 for activities and telemetry, GiST indices. |
| **F. Object Storage** | MinIO Object Storage | MinIO Docker (`travel_minio`) | **DONE** | Bucket `travel-media`, AWS S3 SDK with presigned URL upload and download handlers. |
| **G. Push Notifications** | Firebase Cloud Messaging | FCM Dispatcher (`src/modules/emergency/emergency.service.ts`) | **DONE** | Token persistence (`PUT /api/auth/fcm-token`) and guide notification dispatching. |
| **H. Emergency Rescuers** | Telegram Bot API | Telegram Service (`src/modules/emergency/emergency.service.ts`) | **DONE** | Markdown/HTML distress dispatch with direct links to Google Maps and OpenStreetMap pins. |

---

## 3. Executable Task Breakdown: Done vs. Remains

### Phase 1: Foundation & Spatial Database Setup

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Status | Verification & Code References |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **BE-1.1** | **Initialize Backend Service** | Set up Node.js environment with REST and WebSocket support. | Node.js, Fastify, Socket.io | **DONE** | Implemented in [`src/app.ts`](file:///home/subin/tt/src/app.ts) and [`src/sockets/gateway.ts`](file:///home/subin/tt/src/sockets/gateway.ts). Fastify REST + Socket.io server with JWT authentication. |
| **BE-1.2** | **Configure PostgreSQL + PostGIS** | Deploy database and enable the PostGIS extension for spatial queries. | PostgreSQL, PostGIS, Docker | **DONE** | Implemented in [`docker-compose.yml`](file:///home/subin/tt/docker-compose.yml#L2-L19) (`postgis/postgis:16-3.4`) and [`001_initial_schema.sql`](file:///home/subin/tt/src/database/migrations/001_initial_schema.sql#L1-L4). |
| **BE-1.3** | **Database Schema: Core** | Create tables for Users, Groups, and Activities. | SQL, Kysely, pg | **DONE** | Defined in [`001_initial_schema.sql`](file:///home/subin/tt/src/database/migrations/001_initial_schema.sql#L5-L45): `users`, `groups`, `group_members`, and `activities`. |
| **BE-1.4** | **Database Schema: Spatial** | Create tables for TravelPlans (using LINESTRING), MediaPins (using POINT), and LocationHistory. | PostGIS | **DONE** | Defined in [`001_initial_schema.sql`](file:///home/subin/tt/src/database/migrations/001_initial_schema.sql#L46-L120): `travel_plans` (`route GEOMETRY(LineString, 4326)`), `activities` (`location GEOMETRY(Point, 4326)`), and `location_history` (`location GEOMETRY(Point, 4326)`). All backed by GiST spatial indices. |
| **BE-1.5** | **Configure MinIO Storage** | Set up self-hosted MinIO bucket for storing GPX files and user-uploaded media. Expose presigned URLs for upload/download. | MinIO SDK, S3 Client | **DONE** | MinIO containerized in `docker-compose.yml`, auto-initialized via `minio-init` bucket script. Endpoints `POST /api/storage/presigned-upload` and `GET /api/storage/presigned-download` implemented in [`storage.controller.ts`](file:///home/subin/tt/src/modules/storage/storage.controller.ts). |

---

### Phase 2: Group Management & Telemetry Engine

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Status | Verification & Code References |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **BE-2.1** | **Group & Role API** | Endpoints to create a travel group, generate an invite code, and assign Guide/Traveler roles. | REST API, Fastify | **DONE** | Implemented in [`groups.controller.ts`](file:///home/subin/tt/src/modules/groups/groups.controller.ts) and [`groups.service.ts`](file:///home/subin/tt/src/modules/groups/groups.service.ts): `POST /api/groups` (generates 8-char hex code, assigns GUIDE role), `POST /api/groups/join` (assigns MEMBER role), `GET /api/groups/:groupId/members`. |
| **BE-2.2** | **Plan Synchronization** | Endpoint to upload a planned route (coordinates/GeoJSON/GPX). Backend stores as PostGIS LINESTRING and broadcasts to group members. | PostGIS, GeoJSON, Socket.io | **DONE** | Implemented in [`plans.controller.ts`](file:///home/subin/tt/src/modules/plans/plans.controller.ts#L7-L51) and [`plans.service.ts`](file:///home/subin/tt/src/modules/plans/plans.service.ts#L29-L101). Parses GPX/GeoJSON via [`src/utils/geojson.ts`](file:///home/subin/tt/src/utils/geojson.ts), calculates total distance and elevation gain, stores in PostGIS, and broadcasts `PlanUpdate` to Socket.io group room. |
| **BE-2.3** | **MQTT/WebSocket Setup** | Deploy Eclipse Mosquitto or set up WebSockets for real-time bi-directional telemetry streams. | Mosquitto / Socket.io | **DONE** | Implemented via Socket.io with Redis Pub/Sub adapter in [`src/sockets/gateway.ts`](file:///home/subin/tt/src/sockets/gateway.ts). Handles client room joining (`join_group`), high-frequency telemetry events (`location:update`), and broadcasts. |
| **BE-2.4** | **Live Location Ingestion** | Route to accept high-frequency GPS payloads from active users. Store latest location in memory (Redis) and batch-insert history into PostgreSQL. | Redis, Fastify, PostGIS | **DONE** | Dual ingestion support via WebSocket (`location:update`) and REST (`POST /api/telemetry/location`). Stores in Redis GEO (`geoadd group:{groupId}:locations`) and Hash (`user:{userId}:telemetry`) with 1-hour TTL. Periodically flushes buffered points to `location_history` in batches every 15s in [`telemetry.service.ts`](file:///home/subin/tt/src/modules/telemetry/telemetry.service.ts#L180-L225). |

---

### Phase 3: Emergency Routing & P2P Webhook Sync

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Status | Verification & Code References |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **BE-3.1** | **P2P Ledger Ingestion Endpoint** | Create an endpoint that accepts a batch of "last known locations" synced from an offline device that just found internet. | REST API, PostGIS | **DONE** | Implemented in `POST /api/telemetry/mesh-sync` ([`telemetry.controller.ts:L88-L134`](file:///home/subin/tt/src/modules/telemetry/telemetry.controller.ts#L88-L134)). Validates timestamps, ingests into Redis, records into `location_history` with `synced_by = GoodSamaritan`, and emits `member:location_recovered` to the group. |
| **BE-3.2** | **FCM Alert Integration** | When a "Rescue Mode" payload is received, push a high-priority FCM alert to the group's Guide and nearby users. | Firebase Admin SDK | **DONE** | Implemented in [`emergency.service.ts:L70-L77`](file:///home/subin/tt/src/modules/emergency/emergency.service.ts#L70-L77). Filters group guides, retrieves their registered FCM push tokens, and formats high-priority alert payload with latitude/longitude coordinates. |
| **BE-3.3** | **Telegram Emergency Fallback** | Create a Telegram Bot webhook/dispatch. If a critical rescue payload arrives, send a formatted message with Google Maps/OSM coordinates to a designated Rescue Channel. | Telegram API | **DONE** | Implemented in [`emergency.service.ts:L89-L147`](file:///home/subin/tt/src/modules/emergency/emergency.service.ts#L89-L147). Dispatches an HTML distress card containing member profile, battery status, emergency reason, Google Maps URL, and OpenStreetMap pin URL to `TELEGRAM_EMERGENCY_CHAT_ID`. |

---

### Phase 4: Social Discovery & Feeds

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Status | Verification & Code References |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **BE-4.1** | **Spatial Discovery API** | Accept bounding box/polygon. Return all public travel plans, photos, and activities within that area. | PostGIS ST_Intersects | **DONE** | Implemented in `GET /api/plans/map-data?minLat=&minLng=&maxLat=&maxLng=` ([`plans.controller.ts:L54-L82`](file:///home/subin/tt/src/modules/plans/plans.controller.ts#L54-L82)). Executes PostGIS `ST_Intersects(geom, ST_MakeEnvelope(...))` across `travel_plans` routes and public `activities` markers. |
| **BE-4.2** | **Proximity Search** | Query to find nearby active public groups or guides within a 10km radius using spatial math. | PostGIS ST_DWithin | **PARTIALLY DONE** | `GET /api/feed?lat=&lng=&radius=` ([`feed.service.ts:L93-L182`](file:///home/subin/tt/src/modules/feed/feed.service.ts#L93-L182)) implements `ST_DWithin` on activities and route paths. **Remains:** A dedicated query specifically finding nearby *active groups / online guides* within 10km from Redis GEO or active guides table. |
| **BE-4.3** | **Media Compression Handlers** | Backend validation to ensure media uploaded to MinIO meets size requirements; generate lightweight thumbnails for map pins. | Sharp (Node.js) | **REMAINS** | Presigned S3/MinIO upload/download URLs are active (`/api/storage`), but image resizing via `sharp` and thumbnail generation hooks are not yet implemented. |

---

## 4. Sequence Diagrams Verification

### Sequence 1: Live Telemetry & Spatial Alerting

```
Traveler App -> MQTT/WS -> Backend API -> PostGIS (ST_Distance to Route)
   alt Stray Distance > 50m
      Backend API -> WS -> Guide App (Stray Warning)
   end
Backend API -> Redis (Update Last Known Location)
Backend API -> WS -> Guide App (Update Marker on Map)
```

- **Current Implementation State:** **Partially Implemented.**
  - Live ingestion and storage into Redis GEO & Hash: **DONE** (`TelemetryService.ingestLiveLocation`).
  - Real-time broadcast to group: **DONE** (`member:location` emitted to room `group:{groupId}`).
  - **Remains:** Server-side `ST_Distance(current_loc, route)` check on every location update. (Note: in the Frontend specification `FE-2.3`, this calculation was designated to run client-side via `Turf.dart` to minimize backend CPU overhead; if server-side alerting is desired, a trigger hook in `TelemetryService` comparing against the group's active `travel_plans.route` is needed).

---

### Sequence 2: Mesh-to-Cloud Rescue Sync

```
GoodSamaritan App -> Backend API: POST /api/telemetry/mesh-sync
Backend API -> DB: Save Last Known Location & Timestamp
Backend API -> DB: Lookup Lost User's Group & Guide
Backend API -> FCM / Telegram: Trigger High Priority Rescue Alert
FCM / Telegram -> Guide App: Wakes up App, displays Last Known Location
```

- **Current Implementation State:** **100% DONE.**
  - Good Samaritan device connects to internet and posts offline mesh ledger to `POST /api/telemetry/mesh-sync` or triggers `POST /api/emergency/trigger`.
  - Database persists telemetry in `location_history` with `synced_by`.
  - Group and guide metadata are fetched via `GroupsService.getGroupMembers`.
  - High-priority FCM push notification dispatched to guides.
  - Formatted SOS card posted to Telegram Emergency Channel.
  - WebSocket event `member:location_recovered` and `emergency:distress` broadcast to the group room.

---

## 5. Summary Scorecard

| Milestone / Category | Total Tasks | Completed (DONE) | Partially Done | Remaining | Completion % |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Phase 1: Foundation & Spatial DB** | 5 | 5 | 0 | 0 | **100%** |
| **Phase 2: Group & Telemetry Engine** | 4 | 4 | 0 | 0 | **100%** |
| **Phase 3: Emergency & Mesh Sync** | 3 | 3 | 0 | 0 | **100%** |
| **Phase 4: Social Discovery & Feeds** | 3 | 1 | 1 (`BE-4.2`) | 1 (`BE-4.3`) | **50%** |
| **Sequence Flows (1 & 2)** | 2 | 1 (Seq 2) | 1 (Seq 1) | 0 | **75%** |
| **OVERALL BACKEND PROJECT** | **17** | **14** | **2** | **1** | **88.2%** |

---

## 6. Action Items to Complete the Remaining 11.8%

To bring the backend to 100% completion against the plan:

1. **Task BE-4.3 — Media Processing with Sharp:**
   - Install `sharp` and `@types/sharp`.
   - Add a post-upload webhook or processing route (`POST /api/storage/process-media`) to download uploaded image from MinIO, generate a 250x250 thumbnail, and upload to `travel-media/thumbnails/`.
2. **Task BE-4.2 — Dedicated Nearby Active Groups/Guides Query:**
   - Add `GET /api/groups/nearby?lat=&lng=&radius=10000` using Redis `GEORADIUS` / PostGIS `ST_DWithin` on active guide locations.
3. **Sequence 1 — Optional Server-Side Stray Distance Check:**
   - In `TelemetryService.ingestLiveLocation`, optionally query `ST_Distance(ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, route::geography)` against the group's active plan. If `distance > 50`, emit `guide:off_path_alert` via Socket.io.
