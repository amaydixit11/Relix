# Developer Quickstart

## Prerequisites

- Flutter 3.41+
- Node.js 18+ for legacy workspace tooling
- A working ACORDE binary

## Start Everything

```bash
./start-all.sh
```

That script:

- tries to rebuild `./acorde` from `../Acorde`
- falls back to the existing local `./acorde` binary if that build fails
- starts ACORDE on port `7331`
- launches the Flutter frontend from [`frontend/`](/home/amaydixit11/Desktop/dev/Relix/frontend)

## Run Flutter Directly

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

The first launch opens a lightweight onboarding screen that stores the initial ACORDE base URL before loading the main shell.

For another target:

```bash
RELIX_FLUTTER_DEVICE=linux ./start-all.sh
```

## Key Paths

- ACORDE log: [`acorde.log`](/home/amaydixit11/Desktop/dev/Relix/acorde.log)
- Flutter frontend: [`frontend/`](/home/amaydixit11/Desktop/dev/Relix/frontend)
- ACORDE contract: [`docs/ACORDE_INTEGRATION.md`](/home/amaydixit11/Desktop/dev/Relix/docs/ACORDE_INTEGRATION.md)

## Physical Devices

When running on a physical phone or tablet, `localhost` on that device is not your development machine. Configure a reachable ACORDE base URL from Settings.
