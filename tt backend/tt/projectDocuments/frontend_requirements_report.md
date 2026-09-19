# Frontend Project Plan: Requirements Analysis & Status Report

**Document Version:** 1.0.0  
**Date:** September 17, 2026  
**Project Workspace:** `/home/subin/tt`  
**Target Platform:** Mobile Frontend (Flutter + Android Native Kotlin)  
**Backend Reference:** [backend_requirements_report.md](file:///home/subin/tt/projectDocuments/backend_requirements_report.md)  

---

## 1. Executive Summary

This report evaluates the current codebase in `/home/subin/tt` against the **Frontend Project Plan: Travel & Emergency App**.

### Key Findings:
1. **Frontend Project Status:**
   - **Frontend Implementation Status: 0% Complete (REMAINS).**
   - The workspace currently houses the Node.js / TypeScript backend system. No Flutter application, Dart code, Kotlin Android plugins, or mobile manifests exist yet in this repository.
2. **Backend Readiness for Frontend:**
   - **Backend Integration Readiness: 100% Ready.**
   - All REST APIs, Socket.io events, spatial bounding box queries, Redis caching, MinIO presigned URL storage, FCM guide alerts, and Good Samaritan peer-ledger endpoints specified by the frontend plan are already built and tested on the backend.

---

## 2. Client Architecture Component Analysis

```
graph TD
    A[Flutter UI Layer] --> B[Riverpod/BLoC State Management]
    B --> C{Services Layer}
    C --> D[MapLibre GL / Map Engine]
    C --> E[Local Database: Isar/ObjectBox]
    C --> F[MethodChannels: Native Android]
    
    F --> G[Foreground Service Tracker]
    F --> H[Android Nearby Connections / P2P]
    F --> I[Sensor Manager: Gyro/Accel/Mag]
    F --> J[BLE/Wi-Fi Aware RSSI Proximity]
    
    G --> E
    H --> E
    I --> G
```

### Component Status Breakdown

| Node | Architecture Component | Current Status | Backend Counterpart Available? | Description & Gap Details |
| :--- | :--- | :---: | :---: | :--- |
| **A** | **Flutter UI Layer** | **REMAINS** | N/A | No Flutter widgets, screens (onboarding, map, radar, feed), or navigation shell exist. |
| **B** | **Riverpod/BLoC State** | **REMAINS** | N/A | No state management providers, controllers, or reactive streams implemented. |
| **C** | **Services Layer** | **REMAINS** | **DONE** | Need Flutter HTTP client (Dio) and Socket.io client to connect to backend API (`http://localhost:3000`). |
| **D** | **MapLibre GL / Engine** | **REMAINS** | **DONE** | Vector tile source and route GeoJSON endpoints (`/api/plans/map-data`) ready on backend. |
| **E** | **Local Database (Isar)** | **REMAINS** | **DONE** | Local schemas for tracks, bounding boxes, peer telemetry ledgers, and offline queue need to be created. |
| **F** | **MethodChannels (Native)** | **REMAINS** | N/A | Native Kotlin bridges for Location, Sensors, Nearby Connections, and BLE not yet created. |
| **G** | **Foreground Service Tracker** | **REMAINS** | **DONE** | Kotlin sticky notification service running every 5s; backend accepts stream via WebSocket and `/api/telemetry/location`. |
| **H** | **Android Nearby Connections** | **REMAINS** | **DONE** | P2P_CLUSTER advertising/discovery; backend accepts mesh ledger dump via `/api/telemetry/mesh-sync`. |
| **I** | **Sensor Manager (IMU)** | **REMAINS** | N/A | Kotlin Dead Reckoning with Accelerometer, Gyroscope, and Magnetometer needed for GPS loss fallback. |
| **J** | **BLE RSSI Proximity Radar** | **REMAINS** | N/A | Flutter BLE scanning (`flutter_blue_plus`) measuring signal strength for Lost device rescue UI. |

---

## 3. Executable Task Breakdown: Done vs. Remains

### Phase 1: Setup, Map Engine & Onboarding

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Client Status | Backend Status |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **FE-1.1** | **Initialize Flutter Project** | Setup Flutter project, Riverpod for state, and routing (`go_router`). | Flutter, Riverpod, go_router | **REMAINS** | N/A |
| **FE-1.2** | **Implement First-Launch Onboarding** | UI prompting "Where would you like to travel?". Save user selection (Bounding Box coordinates) locally. | UI/UX, Flutter | **REMAINS** | **DONE** (`/api/plans/map-data`) |
| **FE-1.3** | **Integrate MapLibre GL** | Display map using a free vector tile source (e.g., Protomaps PMTiles or OpenStreetMap). | maplibre_gl, Protomaps | **REMAINS** | **DONE** (GeoJSON routes) |
| **FE-1.4** | **Offline Map Downloader** | Create a service to download PMTiles/vector data for the selected bounding box to local storage. Map must render without internet at zero cost. | maplibre_gl, Dio, Protomaps | **REMAINS** | **DONE** (`ST_MakeEnvelope`) |

---

### Phase 2: Core Navigation & Off-Path Alerts

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Client Status | Backend Status |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **FE-2.1** | **Render Travel Plans (Polylines)** | Parse GeoJSON/GPX data from backend and render as polylines on the map. | MapLibre, GeoJSON | **REMAINS** | **DONE** (`/api/plans/:id`) |
| **FE-2.2** | **Native Background Tracker** | Write a Kotlin Foreground Service with a sticky notification. Continually pull GPS location every 5 seconds. Send to Flutter via EventChannel. | Kotlin, Location Services | **REMAINS** | **DONE** (`location:update`) |
| **FE-2.3** | **Off-Path Calculation** | Function calculating shortest distance between current GPS coordinate and the route polyline. If distance > 50m, trigger local push notification/sound. | Turf.dart | **REMAINS** | N/A |
| **FE-2.4** | **Sensor Fusion (Dead Reckoning)** | In Kotlin, when GPS accuracy drops, subscribe to Accelerometer, Gyroscope, and Magnetometer. Apply step counting and heading to estimate movement. Send updated pseudo-coordinates to Flutter. | Kotlin SensorManager | **REMAINS** | N/A |

---

### Phase 3: P2P Mesh Networking & Rescue Mode

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Client Status | Backend Status |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **FE-3.1** | **Native P2P Service setup** | Implement Android Nearby Connections API (Strategy: `P2P_CLUSTER`). Expose `StartAdvertising` and `StartDiscovery` methods via MethodChannel. | Kotlin, Nearby API | **REMAINS** | N/A |
| **FE-3.2** | **Telemetry Ledger Sync** | When devices connect via P2P, exchange recent location ledgers. Save received ledgers to Isar DB. | Isar DB | **REMAINS** | **DONE** (`/api/telemetry/mesh-sync`) |
| **FE-3.3** | **Rescue Mode Broadcast** | Button to trigger Rescue Mode. Maximize nearby connection advertising frequency. Attempt sending an FCM emergency payload if the internet connects. | Kotlin, Flutter | **REMAINS** | **DONE** (`/api/emergency/trigger`) |
| **FE-3.4** | **Proximity Radar (RSSI)** | Using BLE scanning, measure signal strength (RSSI) of the lost device's MAC address. Create a "Hot/Cold" UI reflecting signal strength to guide the rescuer. | flutter_blue_plus | **REMAINS** | N/A |

---

### Phase 4: Social, Media & Deep Linking

| Task ID | Task Description | Acceptance Criteria & Requirements | Technologies | Client Status | Backend Status |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **FE-4.1** | **Deep Link Location Sharing** | Generate and parse `app://location?lat=x&lng=y` links from messaging apps. Render temporary marker on map. | app_links | **REMAINS** | N/A |
| **FE-4.2** | **Record Track & Drop Media Pins** | UI to "Start Recording" a new route. Add camera integration to capture photos/videos tied to specific coordinates. | camera, path_provider | **REMAINS** | **DONE** (`/api/feed/activities`) |
| **FE-4.3** | **Offline Sync Queue** | Save newly created activities/media locally. Background task listens for internet connection to upload to MinIO backend. | workmanager, Dio | **REMAINS** | **DONE** (`/api/storage/presigned-upload`) |

---

## 4. Sequence Diagrams Feasibility

### Sequence 1: Offline Dead Reckoning & Off-Path Alert
- **Native Location Loop:** Implemented in Kotlin via `ForegroundService` + `FusedLocationProviderClient`.
- **Sensors:** Registered via `SensorManager.registerListener()` with `Sensor.TYPE_STEP_DETECTOR` and `Sensor.TYPE_ROTATION_VECTOR`.
- **Off-Path Distance:** Calculated locally in Flutter using `turf.pointToLineDistance()`. If > 50m, trigger sound and warning dialog.

### Sequence 2: P2P Mesh Rescue Sync
- **Lost User A:** Triggers SOS -> Nearby Connections aggressive advertising (`P2P_CLUSTER`).
- **Nearby User B:** Discovers User A -> connects -> transfers encrypted GPS ledger -> saves to local Isar DB.
- **Relay to Cloud:** User B connects to internet -> calls backend `POST /api/telemetry/mesh-sync`. Backend updates Redis, notifies guide via FCM, and triggers emergency alert.

---

## 5. Summary & Implementation Roadmap

| Milestone | Tasks | Done (Client) | Remains (Client) | Backend Support Status |
| :--- | :---: | :---: | :---: | :---: |
| **Phase 1: Setup & Maps** | 4 | 0 | 4 | **Ready (100%)** |
| **Phase 2: Navigation & Tracking** | 4 | 0 | 4 | **Ready (100%)** |
| **Phase 3: P2P Mesh & Rescue** | 4 | 0 | 4 | **Ready (100%)** |
| **Phase 4: Social, Media & Sync** | 3 | 0 | 3 | **Ready (100%)** |
| **TOTAL FRONTEND TASKS** | **15** | **0** | **15** | **Ready (100%)** |

### Step-by-Step Implementation Strategy:
1. **Initialize Flutter Project:** Scaffold mobile app in `/home/subin/tt/client` or root with Riverpod & GoRouter.
2. **Native Android Service:** Implement `ForegroundLocationService.kt` and `NearbyConnectionsPlugin.kt`.
3. **MapLibre Engine:** Embed offline map canvas with PMTiles support.
4. **Offline Database:** Set up Isar DB tables (`TrackPoint`, `PeerLedger`, `OfflineActivity`).
5. **P2P Mesh & Radar UI:** Build the Hot/Cold signal meter using `flutter_blue_plus`.
