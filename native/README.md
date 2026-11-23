# DayFlow native Android MVP

## Included

- Offline, local-first task CRUD with categories, priorities, notes, repeating tasks, and swipe actions.
- Today and weekly planner views.
- 15, 25, and 45 minute focus timer with completed-session history.
- Local Android reminders for timed tasks, rescheduled after reboot.
- A real Android home-screen widget showing the top three open tasks and an Add task shortcut.
- Insights for completions, focus minutes, streaks, and imported badges.
- Import and export of the existing PWA's DayFlow v1 JSON format.
- GitHub Actions verification and APK artifact builds.

## Local setup

Install the current stable Flutter SDK and Java 17, then run:

```sh
flutter create --platforms=android --org com.ibrahimgaya25 --project-name dayflow_native .
flutter pub get
flutter test
flutter run
```

The first command creates any SDK-version-specific wrapper files. Existing DayFlow source and Android widget files are retained.

## Signing and package identity

The provisional application ID is `com.ibrahimgaya25.dayflow`. The GitHub Actions MVP uses debug signing, which is suitable for direct tester installs but not store release.

Before distribution:

1. Confirm the package ID from the existing PWABuilder APK.
2. Keep the same package ID only if the native app is intended to replace that package.
3. Store the PWABuilder keystore and passwords in GitHub Actions secrets—never commit them.
4. Replace the debug release signing configuration with a secret-backed release configuration.

An Android app can update an installed app only when both the application ID and signing certificate match.

## Import from the PWA

Export data from the PWA's Settings, install the native APK, then choose Settings → **Import data**. The import is validated before anything stored on the device is replaced.
