# Existing PWA audit

Reviewed against commit `b65f9e1` before native implementation.

## Preserved behavior

- DayFlow v1 export/import fields and validation rules.
- Tasks, priorities, categories, dates, optional times, notes, subtasks, and repeat rules.
- Completing a repeating task creates the next occurrence; reopening removes an untouched generated occurrence.
- Planner, focus sessions, insights, streak history, personal tips, badges, appearance, and onboarding preferences.
- Local-only operation and offline availability.

## Repository findings

- The PWA is implemented as one 1,572-line `index.html` file with no automated tests.
- GitHub has no open issues or pull requests for this repository.
- The service-worker cache remains `dayflow-v1`, so changed shell assets may remain stale unless the cache name is bumped.
- The normal GitHub Pages deployment stores data only in browser `localStorage`. The optional `window.claude` cloud seam does not run in ordinary browsers.
- There are no local notifications or native widget APIs in the PWA.

## Native migration decisions

- The root PWA files and GitHub Pages behavior are not modified.
- The native app lives under `native/` and uses atomic JSON file writes plus a backup copy.
- The v1 schema remains the exchange format. Native-only reminder metadata is an extra task field ignored safely by the PWA validator.
- Reminders use local Android scheduling, with exact timing when the user grants exact-alarm access and an inexact fallback otherwise.
- The widget reads a small summary mirrored by the Flutter app; the full task database stays private to the app.
