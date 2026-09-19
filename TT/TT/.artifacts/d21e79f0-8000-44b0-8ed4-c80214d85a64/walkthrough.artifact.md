# Walkthrough - Clean Guide Flow & Alert Suppression

I have refactored the Guide experience to ensure a clean start and eliminate erroneous alerts after saving a trail.

## Changes Made

### 1. Choice of Mode
- **Expedition List Update**: For Guides, a new **"Start Fresh Map"** option has been added at the top of the expedition hub.
- **Clear Intent**: Choosing "Start Fresh Map" clears any existing expedition session, allowing you to start recording on a map with no pre-existing routes or "strayed" alerts.

### 2. Intelligent Alert Suppression
- **`MapScreen` Refinement**: The "Off-Path" logic is now strictly tied to whether a route is actually loaded on the map.
- **Post-Save fix**: Previously, the app would fallback to a "Default Kathmandu Route" after you stopped recording, causing a "Strayed" alert. Now, if no expedition is active, the app remains silent after you finish recording.

### 3. Clean Data Loading & Battery Optimization
- **`RouteService` Cleanup**: Removed the automatic loading of mock Kathmandu data. The map now only draws a route if you have explicitly joined an expedition that has a path assigned to it.
- **Automatic Shutdown**: When you click "Save" on a recording, the app now automatically stops the underlying location tracking service. This turns off the GPS hardware and removes the background notification to save battery once your work is done.

## Verification
- **Login as Guide**: Go to expeditions, click "Start Fresh Map". Verified the map is empty.
- **Recording Test**: Started recording, saved the path. Verified that the app **did not** jump to an "Off-Path" alert after saving.
- **Expedition Test**: Selected a real expedition. Verified the route appears and off-path alerts work as intended for that specific path.

> [!NOTE]
> If you want to see the "Off-Path" guidance again, you must go back to the **Expeditions** tab and select a specific group/journey.
