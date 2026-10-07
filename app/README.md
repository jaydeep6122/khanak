# Khanak app

The Android app for Khanak, in Flutter. It speaks Gujarati, Hindi and English and talks only to the API in [`../backend`](../backend/README.md).

## Running it

Flutter is run through [fvm](https://fvm.app). CI uses Flutter 3.47.6 ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)).

```bash
fvm flutter pub get
fvm flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/v1
```

`API_BASE_URL` is the backend's address. Without it the app uses the live API (`AppConstants.apiBaseUrl` in `lib/global/constants.dart`). A phone reaches a backend on your computer when both are on the same Wi-Fi; use the computer's address, not `localhost`. Debug builds may use plain `http`; release builds need `https`.

## Checks

```bash
fvm flutter analyze
fvm flutter test
```

Both run on every pull request. After changing the logo, `fvm flutter test tool/brand_assets_test.dart` repaints the launcher icons, splash images and the Play Store icon (`store/`).

## Where things are

| Folder | What |
|---|---|
| `lib/api/` | One class per area of the API (`auth`, `factory`, `worker`, `entry`, `trade`, `report`, `app`). Requests and nothing else. |
| `lib/core/` | `Core` and its modules: the app's state, loading and saving through `lib/api`, and the error to show when something fails. Screens read it with Provider. |
| `lib/screens/` | One folder per part of the app: `home`, `workers`, `entries`, `trade` (sales, expenses, customers and suppliers), `cash`, `more`, `settings`, `auth`. |
| `lib/components/` | Shared widgets: fields, buttons, grouped lists, sheets and dialogs. |
| `lib/types/` | Data from the API, parsed from JSON. |
| `lib/helpers/` | Formatting, validation, WhatsApp, support and legal links, error handling. |
| `lib/storage/` | Hive boxes (cached user and factory, settings) and secure storage (tokens). |
| `assets/translations/` | `en.json`, `gu.json` and `hi.json`. |

## Translations

Every text on screen is a key in `assets/translations/`, used as `'key'.tr()`. Add each new key to all three files; they are kept in alphabetical order. Gujarati comes first, since the first kilns using Khanak are in Gujarat.

## Help, terms and privacy

More → Help opens a WhatsApp chat with the number the server sends (`SUPPORT_WHATSAPP` on the backend, so it can change without an update), and the terms and privacy pages the backend serves at `/legal/terms` and `/legal/privacy`. More → Profile lets someone change their details and password, or delete their account; `/legal/delete-account` explains the same for the Play Store listing.

## Release builds

```bash
fvm flutter build appbundle --release
```

Set `version` in `pubspec.yaml` first; the number after `+` is the build the backend's `MIN_APP_BUILD_ANDROID` compares against to require an update.

Release builds are still signed with the debug key (`android/app/build.gradle.kts`). Add a release keystore before uploading to the Play Store.
