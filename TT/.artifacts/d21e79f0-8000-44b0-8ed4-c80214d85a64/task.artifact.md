# Task List - Navigation UI & SOS Bug Fix

- `[x]` **Fix SOS UUID Bug**
    - `[x]` Update `MapScreen.dart` to use `active_group_id` from SharedPreferences for SOS triggers.
- `[x]` **Implement Main Navigation UI**
    - `[x]` Create `MainNavigationWrapper` widget with `BottomNavigationBar`.
    - `[x]` Refactor `router.dart` to use `ShellRoute`.
    - `[x]` Remove individual app bars from Map, Groups, and Radar if they conflict with the shell.
