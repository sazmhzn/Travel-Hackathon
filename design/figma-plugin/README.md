# TT App Screens — Figma plugin

Generates hi-fidelity Figma frames for the Flutter app in `TT/lib`, derived from
the actual routes, widgets and copy in the code.

## Run it

1. Open **Figma desktop** (plugins don't run in the browser editor).
2. Right-click the canvas → **Plugins → Development → Import plugin from manifest…**
3. Select `design/figma-plugin/manifest.json`.
4. Run **Plugins → Development → TT App Screens**.
5. Click **Generate screens**.

The plugin creates a new page named `TT App Screens` (or `TT App Screens (2)` if
one already exists) and reports `Created 13 frames` in the UI.

## What it creates

| Frame | Source |
| --- | --- |
| Cover | app name + index |
| Design System | color / type / spacing / radius tokens |
| 1 · Login | `features/auth/presentation/login_screen.dart` |
| 2 · Register | `features/auth/presentation/register_screen.dart` |
| 3 · Onboarding | `features/onboarding/presentation/onboarding_screen.dart` |
| 4 · Expeditions (GUIDE) | `features/groups/presentation/group_list_screen.dart` |
| 5 · Expeditions (MEMBER, empty) | same, empty + Join FAB branch |
| 6 · Map | `features/map/presentation/map_screen.dart` |
| 7 · Proximity Radar | `features/emergency/presentation/radar_screen.dart` |
| 8 · Dialog — Create Group | `group_list_screen.dart` `_showCreateGroupDialog` |
| 9 · Dialog — Join Group | `group_list_screen.dart` `_showJoinGroupDialog` |
| 10 · Dialog — Invite Code | `group_list_screen.dart` `_showInviteCode` |
| 11 · Dialog — SOS Alert | `map_screen.dart` emergency socket handler |

Every screen is a 360 × 800 Android frame with status bar, app bar, content and
the shared bottom navigation (`shared/presentation/main_navigation_wrapper.dart`):
**Map / Expeditions / Radar**.

## Editing

- Layers are named and use auto-layout (`Body`, `App Bar`, `Bottom Navigation`,
  `Card`, `FAB`, …), so they are editable rather than flat images.
- Local styles are registered under `TT/Color/*` and `TT/Text/*`. Change a style
  to restyle every frame.
- Fonts: the plugin loads **Inter** with a **Roboto** fallback. Install Inter to
  get the intended type.
- The map canvas and the bottom-nav/app-bar icons are vector nodes
  (`Map Canvas`, `Icon`), so they scale cleanly.

## Tokens

| Token | Hex |
| --- | --- |
| Deep Pine | `#14532D` |
| Sand | `#F7F4EF` |
| Ink / Muted | `#1F2937` / `#6B7280` |
| Border | `#E5E7EB` |
| Ember (SOS button) | `#F97316` |
| SOS Red | `#DC2626` |
| Tracking Blue | `#2563EB` |
| Warm Amber | `#F59E0B` |
| Safe Green | `#16A34A` |

Radar "Hot / Warm / Cold" states map to SOS Red / Warm Amber / Tracking Blue,
matching the RSSI thresholds in `radar_screen.dart` (`> -60`, `> -80`, else).