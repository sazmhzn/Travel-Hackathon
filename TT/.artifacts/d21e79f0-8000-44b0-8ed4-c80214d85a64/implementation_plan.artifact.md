# Implementation Plan - Navigation UI & SOS Bug Fix

This plan covers adding a global navigation structure to the app and fixing the SOS trigger error identified in the logs.

## 1. SOS Bug Fix
The backend correctly rejected `"group123"` because it expects a valid UUID for the `groupId`.
- **Action:** Update `MapScreen` to fetch the real `active_group_id` from `SharedPreferences` before triggering the SOS.

## 2. App Navigation UI
The user requested "navigation in app". We will implement a `BottomNavigationBar` using `ShellRoute` in `go_router`. This allows the navigation bar to persist across different features.

### Navigation Items:
- **Map:** Real-time tracking and route view.
- **Expeditions:** Group management (Create/Join).
- **Radar:** Proximity BLE scanning.

## Proposed Changes

### Core UI Framework
#### [NEW] `lib/shared/presentation/main_navigation_wrapper.dart`
- A widget that wraps the app's main screens with a `Scaffold` containing a `BottomNavigationBar`.
- Handles switching between Map, Groups, and Radar.

### Routing Updates
#### [MODIFY] `lib/core/router.dart`
- Implement `ShellRoute` to use `MainNavigationWrapper` for `/map`, `/groups`, and `/radar`.
- Keep `/login` and `/register` outside the shell.

### SOS Integration Fix
#### [MODIFY] `lib/features/map/presentation/map_screen.dart`
- In the `rescueBtn` onPressed callback, read the `active_group_id` from `SharedPreferences` instead of using the hardcoded `"group123"`.

## Verification Plan

### Manual Verification
1. Log in and create/join a group.
2. Verify the `BottomNavigationBar` appears.
3. Switch between Map, Expeditions, and Radar using the bar.
4. On the Map, trigger SOS and verify the API request in the logs now uses a valid UUID (e.g., `a8d14611...`) and returns a `201 Created` instead of a `500 Error`.
