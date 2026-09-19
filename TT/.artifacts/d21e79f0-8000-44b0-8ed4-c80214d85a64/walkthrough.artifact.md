# Walkthrough - Navigation UI & SOS Bug Fix

I have successfully added a persistent navigation system to the app and fixed the SOS trigger error.

## Changes Made

### 1. SOS Bug Fix
- **`MapScreen.dart`**: Fixed the `EmergencyTriggerFailed` error. The app now fetches the actual `active_group_id` from `SharedPreferences` instead of using a hardcoded string. This ensures the backend receives a valid UUID.

### 2. Main Navigation UI
- **`MainNavigationWrapper`**: Created a new shared widget that provides a `BottomNavigationBar`. This bar allows users to switch between the **Map**, **Expeditions**, and **Radar**.
- **Shell Routing**: Updated `router.dart` to use a `ShellRoute`. This ensures the navigation bar stays visible at the bottom of the screen while navigating between core features.
- **Navigator Keys**: Implemented root and shell navigator keys to ensure consistent navigation behavior across the app.

## Verification
- Verified that the `BottomNavigationBar` correctly updates its index and switches between screens.
- Verified that the SOS trigger now sends the correct UUID to the backend.
- The app successfully builds and runs.
