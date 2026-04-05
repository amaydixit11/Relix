# Relix Flutter Frontend

This is the primary Relix client on the `flutter-rewrite` branch.

## Requirements

- Flutter 3.41+
- A reachable ACORDE daemon
- Platform SDKs for whichever target you run

## Run

From the repo root:

```bash
./start-all.sh
```

Or directly:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Other targets:

```bash
flutter run -d linux
flutter run -d macos
flutter run -d windows
flutter run -d android
flutter run -d ios
```

## ACORDE URL

The app defaults to:

```txt
http://localhost:7331
```

Override it from the Settings screen when testing against another machine or daemon instance.

On first launch the app now shows a setup screen before entering the main vault UI. That flow persists the initial daemon URL in local storage and can be skipped later by changing the URL from Settings.

## Release Checklist

Before shipping, replace the generated example bundle IDs:

- Android: `com.example.relix_flutter`
- Apple targets under `frontend/ios` and `frontend/macos`

## Validation

```bash
flutter analyze
flutter test
```
