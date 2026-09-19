# Implementation Plan - Guide Route Management & Library

This plan details how to display and manage saved routes (recorded paths) and link them to expeditions.

## Current State
- Routes are recorded and posted to `/api/routes/record`.
- Expeditions (Groups) are fetched via `/api/groups/my-groups`.
- The map only shows the "Active Plan" for a group via `/api/plans/group/{groupId}`.
- There is currently no UI to view "Saved Routes" that aren't yet assigned to a group.

## Proposed Changes

### 1. Route Discovery (`route_service.dart`)
- **[NEW] `fetchMyRoutes()`**: Implement a call to `GET /api/routes` to fetch all trails recorded by the guide.
- **[NEW] `assignRouteToGroup(routeId, groupId)`**: Implement a call to `POST /api/plans` to create a "Travel Plan" for a group using a saved route's GeoJSON.

### 2. Route Library UI
- **[NEW] `lib/features/routes/presentation/route_library_screen.dart`**:
    - A searchable list of all recorded trails.
    - Each trail shows its name, distance, and date.
    - Tapping a trail shows a "Preview" on a small map.
    - Option to "Assign to Expedition" which opens a group picker.

### 3. Navigation Update (`main_navigation_wrapper.dart` & `router.dart`)
- Add a **"Library"** tab to the `BottomNavigationBar` for Guides.
- Register `/routes` in the router.

### 4. Expedition Detail Enhancement (`group_list_screen.dart`)
- When a Guide taps an expedition, show a summary: "No route assigned" or "Route: Everest Path".
- Add a button "Assign Route" if none exists, leading to the Library.

## Open Questions
- Does the backend support `GET /api/routes` to list all? (Assuming yes, following REST patterns).
- Should recorded routes be automatically assigned to the "Active Group" if one exists?

## Verification Plan
1. Record a new trail and save it.
2. Go to the "Library" tab. Verify the new trail appears in the list (Dynamic API call).
3. Select an Expedition that has no route.
4. Use the "Assign" feature to link your recorded trail to that expedition.
5. Go to the Map for that expedition and verify the route now renders (via `/api/plans/group/{id}`).
