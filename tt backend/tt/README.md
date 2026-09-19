# Travel & Emergency App — Backend System

A high-throughput spatial backend tailored for outdoor travel, group coordination, real-time telemetry, and emergency response.

Built with **Node.js 20+ (TypeScript)**, **Fastify**, **PostGIS (PostgreSQL 16)**, **Redis 7**, **Socket.io**, **MinIO**, and free emergency alerts (**Firebase Cloud Messaging** & **Telegram Bot API**).

---

## 🏛️ System Architecture

```
[ Client App / Mobile ]
        │
   (HTTP / WS)
        ▼
[ Fastify REST API & Socket.io Gateway ]
   ├── JWT Auth & Role Authorization (Guide, Member, Admin)
   ├── PostGIS (Linestring Routes, Point Pins, ST_DWithin, ST_MakeEnvelope)
   ├── Redis (Live Telemetry GEO/Hash 1-hour TTL & Pub/Sub Adapter)
   ├── MinIO (Self-hosted S3-compatible media storage with presigned URLs)
   ├── Good Samaritan Mesh Sync (Offline peer location ledger relays)
   └── Free Emergency Engine (FCM Push to Guides + Telegram Bot Channel Alerts)
```

---

## 🚀 Quick Start with Docker

The entire stack (PostGIS, Redis, MinIO, and API) is orchestrated via Docker Compose:

```bash
# 1. Clone or navigate to repository
cd tt

# 2. Configure environment variables
cp .env.example .env

# 3. Spin up all containers
docker compose up --build
```

- **REST API & WebSockets**: `http://localhost:3000`
- **Interactive Swagger Docs**: `http://localhost:3000/docs`
- **Postman Collection**: Import [postman_collection.json](file:///d:/Test%20Project/tt/postman_collection.json) and [postman_environment.json](file:///d:/Test%20Project/tt/postman_environment.json) directly into Postman.
- **MinIO Console**: `http://localhost:9001` (User: `minioadmin` / Pass: `minioadmin123`)
- **PostGIS**: `localhost:5432` (`travel_emergency_db`)
- **Redis**: `localhost:6379`

---

## 💻 Local Development (Without Docker)

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run unit and integration tests
npm test

# Start in development mode with hot reload
npm run dev
```

---

## 📡 API Overview

### 1. Authentication (`/api/auth`)
- `POST /register`: Register user (name, email, password, phone, role: `GUIDE` or `MEMBER`).
- `POST /login`: Log in to receive signed JWT token.
- `GET /me`: Get authenticated user profile (Requires Bearer token).
- `PUT /fcm-token`: Update Firebase device push token.

### 2. Groups (`/api/groups`)
- `POST /`: Create a new travel group (Generates unique 8-character invite code).
- `POST /join`: Join a group via invite code.
- `GET /my-groups`: List all groups the user belongs to.
- `GET /:groupId/members`: List members and guides in a group.

### 3. Travel Plans (`/api/plans`)
- `POST /`: Upload GeoJSON or GPX track; parses into PostGIS LineString 4326 and broadcasts `PlanUpdate` to room.
- `GET /:planId`: Get travel plan with GeoJSON route and bounding box polygon.
- `GET /group/:groupId`: List plans for a specific group.
- `GET /map-data?minLat=&minLng=&maxLat=&maxLng=`: ST_MakeEnvelope bounding box query for routes and activities.

### 4. Real-Time Telemetry & Mesh Relay (`/api/telemetry`)
- `POST /location`: Ingest live GPS coordinates into Redis cache (1-hour TTL).
- `GET /group/:groupId/live`: Retrieve real-time coordinates of all active group members.
- `POST /mesh-sync`: Upload location ledgers collected from peer devices via mesh networks (Bluetooth/LoRa); validates timestamps and recovers lost member location.

### 5. Social Feed & Spatial Discovery (`/api/feed`)
- `GET /?lat=&lng=&radius=50000`: Radius search using PostGIS `ST_DWithin` with privacy filters (`PUBLIC` vs `GROUP_ONLY`).
- `POST /activities`: Publish a waypoint, scenic marker, or activity with coordinates and MinIO media URLs.

### 6. Emergency Alerts (`/api/emergency`)
- `POST /trigger`: Activate Rescue Mode.
  - Sends high-priority push notification to Guides via FCM.
  - Posts interactive distress card with Google Maps / OpenStreetMap pin to Telegram Emergency Channel.
  - Broadcasts `emergency:distress` WebSocket event to the group.

### 7. Media Storage (`/api/storage`)
- `POST /presigned-upload`: Generate pre-signed S3/MinIO upload URL for direct client photos/videos.
- `GET /presigned-download?fileKey=...`: Generate pre-signed download URL for private group media.

---

## ⚡ WebSocket (Socket.io) Real-Time Events

Connect to `ws://localhost:3000` with header `Authorization: Bearer <token>` or query `{ auth: { token } }`:

| Event Emitted by Client | Payload | Description |
| :--- | :--- | :--- |
| `join_group` | `{ groupId }` | Join room `group:{groupId}` |
| `leave_group` | `{ groupId }` | Leave room `group:{groupId}` |
| `location:update` | `{ groupId, lat, lng, altitude, speed, battery, timestamp }` | High-frequency telemetry stream |
| `plan:ack` | `{ planId, groupId }` | Confirm receipt of new travel plan |

| Event Received from Server | Payload | Description |
| :--- | :--- | :--- |
| `member:joined` / `member:left` | `{ userId, timestamp }` | Member attendance status |
| `member:location` | `{ userId, lat, lng, altitude, speed, battery, timestamp }` | Real-time member movement |
| `PlanUpdate` | `{ planId, groupId, title, route, totalDistanceMeters }` | Guide pushed a new route |
| `member:location_recovered` | `{ userId, lat, lng, recordedAt, relayedBy }` | Good Samaritan relay recovered lost hiker |
| `emergency:distress` | `{ alertId, userId, userName, lat, lng, battery, reason }` | High-priority SOS distress signal |
