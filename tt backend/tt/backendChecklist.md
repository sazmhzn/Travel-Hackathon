# Backend Feature Checklist — Travel & Emergency App

**Audited:** against `tt backend/tt` source
**Legend:** [x] Complete · [~] Partial · [ ] Missing

## Phase 1 — Foundation & Spatial Database
- [x] BE-1.1 Backend service (Fastify 5 REST + Socket.io WS, JWT, Swagger `/docs`)
- [x] BE-1.2 PostgreSQL 16 + PostGIS 3.4 (Docker, extension enabled)
- [x] BE-1.3 Core schema: users, groups, group_members, activities
- [x] BE-1.4 Spatial schema: travel_plans LineString, points, location_history, GiST indices
- [x] BE-1.5 MinIO bucket + presigned upload/download
- [~] BE-1.5b GPX files not stored in MinIO (parsed from request body only)

## Phase 2 — Group Management & Telemetry
- [x] BE-2.1 Group & role API (create, invite code, join, members)
- [x] BE-2.2 Plan sync (GeoJSON/GPX → LineString, PlanUpdate broadcast)
- [~] BE-2.3 Real-time: Socket.io + Redis adapter (no Eclipse Mosquitto/MQTT)
- [~] BE-2.4 Live ingestion: Redis GEO/hash, 15s flush (sequential inserts, in-memory buffer not durable)

## Phase 3 — Emergency Routing & P2P Sync
- [x] BE-3.1 P2P ledger ingestion `/api/telemetry/mesh-sync`
- [ ] BE-3.2 FCM alerts — STUB ONLY (logs, does not send; firebase-admin absent)
- [x] BE-3.3 Telegram emergency fallback (real fetch; no-op without env)
- [ ] Seq 1 Server-side off-path alert (ST_Distance > 50m)
- [~] Seq 2 Mesh rescue sync — saves + broadcasts, but no guide lookup / FCM / Telegram

## Phase 4 — Social Discovery & Feeds
- [x] BE-4.1 Spatial discovery (ST_Intersects + ST_MakeEnvelope)
- [ ] BE-4.2 Nearby active groups/guides within 10km
- [ ] BE-4.3 Media compression + thumbnails (sharp) + size validation

## Cross-Cutting Gaps
- [ ] Group-membership authorization on group-scoped routes
- [ ] Rate limiting on telemetry/emergency
- [ ] Helmet / security headers; CORS tightened from '*'
- [ ] Secrets removed from committed `.env`
- [ ] Emergency resolve/cancel endpoint
- [ ] Durable telemetry queue (BullMQ/Redis stream) + bulk insert
- [ ] Pagination on feed/plans
- [ ] `requireRole` actually applied (GUIDE-only plan creation)
- [ ] Fix N+1 in `getGroupLiveLocations`

## Improvement Backlog
1. Wire real FCM; mesh-sync triggers group→guide rescue alert
2. Server-side off-path detection via SQL
3. `GET /api/groups/nearby` (Redis GEORADIUS)
4. sharp thumbnail pipeline
5. Membership auth middleware
6. Emergency timeline/resolve
7. Durable queue + multi-row INSERT

## Scorecard
| Phase | Done | Partial | Missing | % |
|---|---|---|---|---|
| Phase 1 | 5 | 1 | 0 | ~92% |
| Phase 2 | 2 | 2 | 0 | ~75% |
| Phase 3 | 2 | 1 | 2 | ~50% |
| Phase 4 | 1 | 0 | 2 | ~33% |
| **Overall** | **10** | **4** | **4** | **~72%** |

> Previous report claimed 88.2%; FCM is a stub, so real completion is lower.
