# Khanak

Brick kiln accounts: workers and their pay, advances, brick counts and stock, kiln unloading, seasons, trucks and sales.

| Folder | What |
|---|---|
| `backend/` | Node.js + Express API on Supabase Postgres. See [backend/README.md](backend/README.md). |
| `app/` | Android app (Flutter, run with `fvm`). Gujarati, Hindi and English. |

## Running the app

The app needs the API running. On a phone on the same Wi-Fi as the computer
running `backend/` (`npm run dev`), pass the computer's address:

```bash
cd app && fvm flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/v1
```

Debug builds may use plain `http`; release builds need the API on `https`.

## Checks

Every pull request and every push to `main` runs [CI](.github/workflows/ci.yml): the backend tests against a fresh Postgres, and `flutter analyze` and `flutter test` for the app.
