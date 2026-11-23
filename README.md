# DayFlow

DayFlow is a local-first daily planner. The repository contains the existing installable PWA at the repository root and a native Android Flutter MVP in [`native/`](native/README.md).

The web deployment is intentionally unchanged by the native project. The Flutter workflow only uploads an APK artifact; it does not publish to GitHub Pages.

## Data compatibility

Both clients use the DayFlow v1 JSON export contract (`app: "dayflow"`, `v: 1`). The native app imports existing PWA backups and exports a file the PWA can read. Tasks, categories, focus sessions, personal tips, preferences, streak history, and earned badges are preserved.

## Android builds

Open **Actions → Native Android APK → Run workflow**. After the workflow finishes, download the `dayflow-android-*` artifact from the run summary.

The MVP artifact uses Android's debug signing key so testers can install it. Before Play Store distribution or replacing an existing PWABuilder package, configure the original application ID and signing key as described in [`native/README.md`](native/README.md).
